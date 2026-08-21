using System.Security.Cryptography;
using System.Text;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.PortableAchievements;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class PortableAchievementServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 21, 9, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Disabled_feature_fails_before_store_or_signing_adapter_is_used()
    {
        var service = new PortableAchievementService(
            PortableAchievementOptions.Disabled,
            new FakeUserContext("person-1", "Private Name"),
            new FakeClock(Now),
            new ThrowingStore(),
            new ThrowingCryptography(),
            new SequentialNonceSource(),
            new ThrowingSubjectIdProvider(),
            new ThrowingCompletionEvidenceResolver(),
            new ThrowingActorContext());

        var act = () => service.IssueAsync(Request());

        await act.Should().ThrowAsync<PortableAchievementsDisabledException>();
    }

    [Fact]
    public async Task Issue_creates_minimal_signed_person_owned_proof_pinned_to_public_release()
    {
        var fixture = new Fixture();

        var result = await fixture.Service.IssueAsync(Request());

        result.IdempotentReplay.Should().BeFalse();
        result.Proof.SubjectType.Should().Be(PortableAchievementContracts.SubjectType);
        result.Proof.SubjectId.Should().Be("portable-person-1");
        result.Proof.ReleaseId.Should().Be("sha256:release-1");
        result.Proof.PublicManifestId.Should().Be("sha256:public-1");
        result.Proof.CompletionEvidenceDigest.Should().StartWith("sha256:");
        result.Proof.CompletionEvidenceDigest.Should().NotContain("completion-private-1");
        result.Proof.Signature.Should().NotBeNullOrWhiteSpace();
        result.Proof.GetType().GetProperties().Select(property => property.Name)
            .Should().NotContain(["DisplayName", "Email", "Score", "Employer", "PrivateManifestId"]);
    }

    [Fact]
    public async Task Unsuccessful_or_foreign_completion_evidence_is_never_signed()
    {
        var fixture = new Fixture(new FixedCompletionEvidenceResolver(
            new PortableCompletionEvidence(
                "completion-private-1",
                "another-person",
                PortableAchievementKind.Certification,
                "certification-1",
                "sha256:release-1",
                "sha256:public-1",
                Now.AddHours(-1),
                Successful: false)));

        var act = () => fixture.Service.IssueAsync(Request());

        await act.Should().ThrowAsync<RequestValidationException>()
            .WithMessage("*authenticated person*");
    }

    [Fact]
    public async Task Same_idempotency_key_returns_original_proof_without_resigning()
    {
        var fixture = new Fixture();
        var first = await fixture.Service.IssueAsync(Request());

        var replay = await fixture.Service.IssueAsync(Request());

        replay.IdempotentReplay.Should().BeTrue();
        replay.Proof.Should().Be(first.Proof);
    }

    [Fact]
    public async Task Completion_evidence_cannot_be_replayed_under_another_request_id()
    {
        var fixture = new Fixture();
        await fixture.Service.IssueAsync(Request());

        var act = () => fixture.Service.IssueAsync(
            Request() with { ClientRequestId = "request-2" });

        await act.Should().ThrowAsync<PortableAchievementConflictException>()
            .WithMessage("*completion evidence*");
    }

    [Fact]
    public async Task Historical_key_version_remains_verifiable_after_rotation()
    {
        var fixture = new Fixture();
        var issued = await fixture.Service.IssueAsync(Request());
        fixture.Cryptography.RotatePlatformKey();

        var verification = await fixture.Service.VerifyAsync(
            new VerifyPortableAchievementRequest(issued.Proof));

        verification.Valid.Should().BeTrue();
        issued.Proof.SigningKey.Version.Should().Be(1);
        (await fixture.Service.IssueAsync(
            Request() with
            {
                ClientRequestId = "request-2",
                CompletionEvidenceId = "completion-private-2",
            })).Proof.SigningKey.Version.Should().Be(2);
    }

    [Fact]
    public async Task Tampered_release_pin_fails_signature_verification()
    {
        var fixture = new Fixture();
        var issued = await fixture.Service.IssueAsync(Request());

        var verification = await fixture.Service.VerifyAsync(
            new VerifyPortableAchievementRequest(
                issued.Proof with { ReleaseId = "sha256:other-release" }));

        verification.Valid.Should().BeFalse();
        verification.FailureCode.Should().Be("unknownProof");
        fixture.Cryptography.VerifyCalls.Should().Be(0);
    }

    [Fact]
    public async Task Null_proof_is_reported_as_invalid_contract()
    {
        var fixture = new Fixture();

        var verification = await fixture.Service.VerifyAsync(
            new VerifyPortableAchievementRequest(null));

        verification.Valid.Should().BeFalse();
        verification.FailureCode.Should().Be("invalidContract");
    }

    [Fact]
    public async Task Organization_can_attest_but_cannot_revoke_person_owned_achievement()
    {
        var fixture = new Fixture();
        var issued = await fixture.Service.IssueAsync(Request());
        var attested = await fixture.Administration.AttestAsync(
            new AttestPortableAchievementCommand(
                issued.Proof.ProofId,
                "attestation-1"));

        fixture.ActorContext.ActorType = PortableActorType.Organization;
        var act = () => fixture.Administration.RevokeAsync(
            new RevokePortableAchievementCommand(
                issued.Proof.ProofId,
                PortableRevocationReason.Fraud,
                "fraud review"));

        attested.Proof.SubjectId.Should().Be("portable-person-1");
        attested.Attestations.Should().ContainSingle();
        await act.Should().ThrowAsync<PortableAchievementConflictException>();
    }

    [Fact]
    public async Task Platform_correction_revocation_is_retained_with_audit_and_invalidates_proof()
    {
        var fixture = new Fixture();
        var issued = await fixture.Service.IssueAsync(Request());
        fixture.ActorContext.ActorType = PortableActorType.Platform;

        var revoked = await fixture.Administration.RevokeAsync(
            new RevokePortableAchievementCommand(
                issued.Proof.ProofId,
                PortableRevocationReason.Correction,
                "source completion corrected"));
        var verification = await fixture.Service.VerifyAsync(
            new VerifyPortableAchievementRequest(issued.Proof));

        revoked.Proof.SubjectId.Should().Be("portable-person-1");
        revoked.Revocation.Should().NotBeNull();
        revoked.Audit.Should().Contain(entry => entry.EventType == "revoked");
        verification.Valid.Should().BeFalse();
        verification.Revoked.Should().BeTrue();
    }

    private static IssuePortableAchievementRequest Request() =>
        new("request-1", "completion-private-1");

    private sealed class Fixture
    {
        private readonly InMemoryPortableAchievementStore _store = new();

        public Fixture(IPortableCompletionEvidenceResolver? evidenceResolver = null)
        {
            Cryptography = new TestPortableProofCryptography();
            ActorContext = new TestActorContext();
            Service = new PortableAchievementService(
                new PortableAchievementOptions(true, "certigo"),
                new FakeUserContext("person-1", "Private Name"),
                new FakeClock(Now),
                _store,
                Cryptography,
                new SequentialNonceSource(),
                new TestSubjectIdProvider(),
                evidenceResolver ?? new TestCompletionEvidenceResolver(),
                ActorContext);
            Administration = Service;
        }

        public PortableAchievementService Service { get; }
        public IPortableAchievementAdministrationService Administration { get; }
        public TestPortableProofCryptography Cryptography { get; }
        public TestActorContext ActorContext { get; }
    }

    private sealed class SequentialNonceSource : IPortableNonceSource
    {
        private int _value;
        public string Create() => $"nonce-{Interlocked.Increment(ref _value)}";
    }

    private sealed class TestSubjectIdProvider : IPortableSubjectIdProvider
    {
        public Task<string> ResolveAsync(
            string internalUserId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult($"portable-{internalUserId}");
    }

    private sealed class TestCompletionEvidenceResolver : IPortableCompletionEvidenceResolver
    {
        public Task<PortableCompletionEvidence?> ResolveAsync(
            string internalUserId,
            string completionEvidenceId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<PortableCompletionEvidence?>(
                new(
                    completionEvidenceId,
                    internalUserId,
                    PortableAchievementKind.Skill,
                    "skill-public-1",
                    "sha256:release-1",
                    "sha256:public-1",
                    Now.AddHours(-1),
                    Successful: true));
    }

    private sealed class FixedCompletionEvidenceResolver(PortableCompletionEvidence evidence)
        : IPortableCompletionEvidenceResolver
    {
        public Task<PortableCompletionEvidence?> ResolveAsync(
            string internalUserId,
            string completionEvidenceId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<PortableCompletionEvidence?>(evidence);
    }

    internal sealed class TestActorContext : IPortableActorContext
    {
        public PortableActorType ActorType { get; set; } = PortableActorType.Organization;

        public Task<PortableActorIdentity> RequireAsync(
            PortableActorType expectedType,
            CancellationToken cancellationToken = default)
        {
            if (ActorType != expectedType)
            {
                throw new PortableAchievementConflictException(
                    $"Actor is not authorized as {expectedType}.");
            }

            var actorId = expectedType == PortableActorType.Platform
                ? "platform-reviewer-1"
                : "organization-1";
            return Task.FromResult(new PortableActorIdentity(actorId, expectedType));
        }
    }

    private sealed class InMemoryPortableAchievementStore : IPortableAchievementStore
    {
        private readonly Dictionary<string, PortableAchievementRecord> _proofs = new();
        private readonly Dictionary<string, string> _requests = new();
        private readonly Dictionary<string, string> _evidence = new();

        public Task<PortableAchievementCreateResult> CreateAsync(
            string ownerId,
            string clientRequestId,
            string completionEvidenceId,
            PortableAchievementRecord record,
            CancellationToken cancellationToken = default)
        {
            var requestKey = $"{ownerId}|{clientRequestId}";
            if (_requests.TryGetValue(requestKey, out var requestProofId))
            {
                return Task.FromResult(new PortableAchievementCreateResult(
                    PortableAchievementCreateStatus.IdempotentReplay,
                    _proofs[requestProofId]));
            }

            var evidenceKey = $"{ownerId}|{completionEvidenceId}|{record.Proof.Kind}|"
                + record.Proof.AchievementId;
            if (_evidence.TryGetValue(evidenceKey, out var evidenceProofId))
            {
                return Task.FromResult(new PortableAchievementCreateResult(
                    PortableAchievementCreateStatus.EvidenceReplay,
                    _proofs[evidenceProofId]));
            }

            _proofs.Add(record.Proof.ProofId, record);
            _requests.Add(requestKey, record.Proof.ProofId);
            _evidence.Add(evidenceKey, record.Proof.ProofId);
            return Task.FromResult(new PortableAchievementCreateResult(
                PortableAchievementCreateStatus.Created,
                record));
        }

        public Task<PortableAchievementRecord?> GetAsync(
            string proofId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(_proofs.GetValueOrDefault(proofId));

        public Task<PortableAchievementRecord> AddAttestationAsync(
            string proofId,
            PortableOrganizationAttestation attestation,
            PortableAchievementAuditEntry audit,
            CancellationToken cancellationToken = default)
        {
            var current = _proofs[proofId];
            var updated = current with
            {
                Attestations = [.. current.Attestations, attestation],
                Audit = [.. current.Audit, audit],
            };
            _proofs[proofId] = updated;
            return Task.FromResult(updated);
        }

        public Task<PortableAchievementRecord> RevokeAsync(
            string proofId,
            PortableRevocation revocation,
            PortableAchievementAuditEntry audit,
            CancellationToken cancellationToken = default)
        {
            var current = _proofs[proofId];
            var updated = current with
            {
                Revocation = revocation,
                Audit = [.. current.Audit, audit],
            };
            _proofs[proofId] = updated;
            return Task.FromResult(updated);
        }
    }

    private sealed class TestPortableProofCryptography : IPortableProofCryptography
    {
        private readonly Dictionary<(string KeyId, int Version), byte[]> _keys = new()
        {
            [("platform", 1)] = Encoding.UTF8.GetBytes("test-key-version-one-32-bytes!!"),
            [("platform", 2)] = Encoding.UTF8.GetBytes("test-key-version-two-32-bytes!!"),
            [("organization-1", 1)] = Encoding.UTF8.GetBytes("test-organization-key-32-bytes!!"),
        };
        private int _platformVersion = 1;

        public int VerifyCalls { get; private set; }

        public void RotatePlatformKey() => _platformVersion = 2;

        public Task<PortableSigningKeyReference> GetCurrentKeyAsync(
            PortableActorType actorType,
            string actorId,
            CancellationToken cancellationToken = default)
        {
            var reference = actorType == PortableActorType.Platform
                ? new PortableSigningKeyReference("platform", _platformVersion, "HS256-test-only")
                : new PortableSigningKeyReference(actorId, 1, "HS256-test-only");
            return Task.FromResult(reference);
        }

        public Task<string> SignAsync(
            PortableSigningKeyReference key,
            ReadOnlyMemory<byte> payload,
            CancellationToken cancellationToken = default)
        {
            using var hmac = new HMACSHA256(_keys[(key.KeyId, key.Version)]);
            return Task.FromResult(Convert.ToBase64String(hmac.ComputeHash(payload.ToArray())));
        }

        public async Task<bool> VerifyAsync(
            PortableSigningKeyReference key,
            ReadOnlyMemory<byte> payload,
            string signature,
            CancellationToken cancellationToken = default)
        {
            VerifyCalls++;
            if (!_keys.ContainsKey((key.KeyId, key.Version)))
            {
                return false;
            }

            var expected = Convert.FromBase64String(await SignAsync(key, payload, cancellationToken));
            byte[] actual;
            try
            {
                actual = Convert.FromBase64String(signature);
            }
            catch (FormatException)
            {
                return false;
            }

            return CryptographicOperations.FixedTimeEquals(expected, actual);
        }
    }

    private sealed class ThrowingStore : IPortableAchievementStore
    {
        private static Exception Unexpected() => new InvalidOperationException("store used");

        public Task<PortableAchievementCreateResult> CreateAsync(
            string ownerId,
            string clientRequestId,
            string completionEvidenceId,
            PortableAchievementRecord record,
            CancellationToken cancellationToken = default) => throw Unexpected();

        public Task<PortableAchievementRecord?> GetAsync(
            string proofId,
            CancellationToken cancellationToken = default) => throw Unexpected();

        public Task<PortableAchievementRecord> AddAttestationAsync(
            string proofId,
            PortableOrganizationAttestation attestation,
            PortableAchievementAuditEntry audit,
            CancellationToken cancellationToken = default) => throw Unexpected();

        public Task<PortableAchievementRecord> RevokeAsync(
            string proofId,
            PortableRevocation revocation,
            PortableAchievementAuditEntry audit,
            CancellationToken cancellationToken = default) => throw Unexpected();
    }

    private sealed class ThrowingCryptography : IPortableProofCryptography
    {
        private static Exception Unexpected() => new InvalidOperationException("cryptography used");

        public Task<PortableSigningKeyReference> GetCurrentKeyAsync(
            PortableActorType actorType,
            string actorId,
            CancellationToken cancellationToken = default) => throw Unexpected();

        public Task<string> SignAsync(
            PortableSigningKeyReference key,
            ReadOnlyMemory<byte> payload,
            CancellationToken cancellationToken = default) => throw Unexpected();

        public Task<bool> VerifyAsync(
            PortableSigningKeyReference key,
            ReadOnlyMemory<byte> payload,
            string signature,
            CancellationToken cancellationToken = default) => throw Unexpected();
    }

    private sealed class ThrowingSubjectIdProvider : IPortableSubjectIdProvider
    {
        public Task<string> ResolveAsync(
            string internalUserId,
            CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("subject id provider used");
    }

    private sealed class ThrowingCompletionEvidenceResolver : IPortableCompletionEvidenceResolver
    {
        public Task<PortableCompletionEvidence?> ResolveAsync(
            string internalUserId,
            string completionEvidenceId,
            CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("completion evidence resolver used");
    }

    private sealed class ThrowingActorContext : IPortableActorContext
    {
        public Task<PortableActorIdentity> RequireAsync(
            PortableActorType expectedType,
            CancellationToken cancellationToken = default) =>
            throw new InvalidOperationException("actor context used");
    }
}
