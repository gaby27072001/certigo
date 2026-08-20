using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class PersonLinkedIdentityContractTests
{
    private const string TenantA = "11111111-1111-4111-8111-aaaaaaaaaaaa";
    private const string TenantB = "22222222-2222-4222-8222-bbbbbbbbbbbb";
    private const string ExternalObjectA = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
    private const string ExternalObjectB = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
    private const string ExternalObjectC = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";

    private static readonly DateTimeOffset Now =
        new(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Versioned_link_contracts_are_machine_readable_and_link_runtime_disabled()
    {
        using var api = LoadContract("openapi.json");
        api.RootElement.GetProperty("info").GetProperty("version").GetString()
            .Should().Be("1.0.0");
        api.RootElement.GetProperty("x-certigo-status").GetString()
            .Should().Be("contract-only");
        var reconciledMain = api.RootElement.GetProperty("x-certigo-reconciled-main");
        reconciledMain.GetProperty("commit").GetString()
            .Should().Be("034c1dd41e8ce7da0a84f8a6e70d821829a54e61");
        reconciledMain.GetProperty("mergedPullRequests").EnumerateArray()
            .Select(pullRequest => pullRequest.GetInt32())
            .Should().Equal(289, 296, 297, 301, 302, 303, 305, 308, 300);
        reconciledMain.GetProperty("productionIdentityRuntimeChanged").GetBoolean()
            .Should().BeTrue();
        api.RootElement.GetProperty("x-certigo-feature-mode").GetProperty("default").GetString()
            .Should().Be("off");

        var paths = api.RootElement.GetProperty("paths");
        paths.TryGetProperty("/me/linked-identities", out _).Should().BeTrue();
        paths.TryGetProperty("/me/identity-link-intents", out _).Should().BeTrue();
        paths.TryGetProperty("/me/identity-link-intents/{intentId}/complete", out _)
            .Should().BeTrue();
        paths.TryGetProperty("/account/deletion", out _).Should().BeTrue();
        paths.TryGetProperty("/me/active-track", out _).Should().BeTrue();
        paths.TryGetProperty("/catalog/tracks", out _).Should().BeTrue();

        var createResponses = paths
            .GetProperty("/me/identity-link-intents")
            .GetProperty("post")
            .GetProperty("responses");
        createResponses.GetProperty("404").GetProperty("$ref").GetString()
            .Should().Be("#/components/responses/IdentitySurfaceDisabled");
        createResponses.TryGetProperty("500", out _).Should().BeFalse();

        var completeResponses = paths
            .GetProperty("/me/identity-link-intents/{intentId}/complete")
            .GetProperty("post")
            .GetProperty("responses");
        completeResponses.GetProperty("404").GetProperty("$ref").GetString()
            .Should().Be("#/components/responses/IntentNotFound");
        completeResponses.GetProperty("500").GetProperty("$ref").GetString()
            .Should().Be("#/components/responses/InternalIntegrityFailure");

        var revokeResponses = paths
            .GetProperty("/me/linked-identities/{linkedIdentityId}")
            .GetProperty("delete")
            .GetProperty("responses");
        revokeResponses.GetProperty("404").GetProperty("$ref").GetString()
            .Should().Be("#/components/responses/LinkedIdentityNotFound");

        var deletionPath = paths.GetProperty("/account/deletion");
        deletionPath.GetProperty("get").GetProperty("x-certigo-baseline").GetString()
            .Should().Be("merged");
        var deletionPost = deletionPath.GetProperty("post");
        deletionPost.GetProperty("x-certigo-owner").GetString().Should().Be("personId");
        deletionPost
            .GetProperty("x-certigo-prerequisite").GetInt32().Should().Be(296);
        deletionPost.GetProperty("x-certigo-client-idempotency-key").GetBoolean()
            .Should().BeFalse();
        deletionPost.GetProperty("responses").TryGetProperty("202", out _).Should().BeTrue();
        deletionPost.GetProperty("parameters")
            .EnumerateArray()
            .Select(parameter => parameter.GetProperty("$ref").GetString())
            .Should().Equal("#/components/parameters/AccountDeletionReauthentication");

        var activeTrack = paths.GetProperty("/me/active-track").GetProperty("post");
        activeTrack
            .GetProperty("x-certigo-owner").GetString().Should().Be("personId");
        activeTrack
            .GetProperty("x-certigo-prerequisite").GetInt32().Should().Be(297);
        activeTrack.GetProperty("responses").TryGetProperty("404", out _).Should().BeTrue();
        activeTrack.GetProperty("responses").TryGetProperty("423", out _).Should().BeTrue();

        paths.GetProperty("/catalog/tracks").GetProperty("get")
            .GetProperty("x-certigo-onboarding-eligibility").GetString()
            .Should().Contain("active-retiring")
            .And.Contain("learningAvailable == true")
            .And.Contain("contentStatus == available");

        var prerequisites = api.RootElement.GetProperty("x-certigo-prerequisites")
            .EnumerateArray()
            .ToDictionary(
                prerequisite => prerequisite.GetProperty("pullRequest").GetInt32(),
                prerequisite => prerequisite.GetProperty("baselineState").GetString());
        prerequisites.Should().ContainKeys(289, 296, 297);
        prerequisites.Values.Should().OnlyContain(state => state == "merged");

        var featureMode = api.RootElement.GetProperty("x-certigo-feature-mode");
        featureMode.GetProperty("offHttpStatus").GetInt32().Should().Be(404);
        featureMode.GetProperty("disabledMutationHttpStatus").GetInt32().Should().Be(503);
        featureMode.GetProperty("implementedValues").EnumerateArray()
            .Select(value => value.GetString()).Should().Equal("off", "shadow");

        var components = api.RootElement.GetProperty("components");
        components.GetProperty("schemas").GetProperty("CreateIdentityLinkIntentRequest")
            .GetProperty("oneOf").GetArrayLength().Should().Be(2);
        var componentResponses = components.GetProperty("responses");
        foreach (var responseName in new[]
                 {
                     "IdentitySurfaceDisabled",
                     "RecentAuthenticationRequired",
                     "AccountDeletionDisabled",
                     "TrackNotFound",
                     "CatalogUnavailable",
                 })
        {
            componentResponses.TryGetProperty(responseName, out _).Should().BeTrue();
        }

        var apiMigration = api.RootElement.GetProperty("x-certigo-migration");
        apiMigration.GetProperty("requiredEquality").GetString()
            .Should().Be("personId == profile.id == legacy userId");
        apiMigration.GetProperty("rewritesOwnerDocuments").GetBoolean().Should().BeFalse();
        apiMigration.GetProperty("changesPartitionKeys").GetBoolean().Should().BeFalse();

        var forbiddenAuditFields = api.RootElement
            .GetProperty("x-certigo-audit")
            .GetProperty("forbiddenFields")
            .EnumerateArray()
            .Select(value => value.GetString())
            .ToArray();
        forbiddenAuditFields.Should().Contain(
            ["personId", "userId", "email", "subject", "token", "password"]);

        using var cosmos = LoadContract("cosmos.schema.json");
        cosmos.RootElement.GetProperty("version").GetString().Should().Be("1.0.0");
        cosmos.RootElement.GetProperty("x-certigo-reconciled-main").GetProperty("commit")
            .GetString().Should().Be("034c1dd41e8ce7da0a84f8a6e70d821829a54e61");
        cosmos.RootElement.GetProperty("x-certigo-reconciled-main")
            .GetProperty("productionIdentityRuntimeChanged").GetBoolean().Should().BeTrue();
        cosmos.RootElement.GetProperty("x-certigo-runtime")
            .GetProperty("implementedValues").EnumerateArray()
            .Select(value => value.GetString()).Should().Equal("off", "shadow");
        cosmos.RootElement.GetProperty("x-certigo-runtime")
            .GetProperty("legacyUserIdRemainsAuthoritative").GetBoolean().Should().BeTrue();
        cosmos.RootElement.GetProperty("x-certigo-runtime")
            .GetProperty("linkEndpointsImplemented").GetBoolean().Should().BeFalse();
        var storage = cosmos.RootElement.GetProperty("x-certigo-cosmos");
        storage.GetProperty("container").GetString().Should().Be("users");
        storage.GetProperty("partitionKey").GetString().Should().Be("/id");
        storage.GetProperty("topologyChangeRequired").GetBoolean().Should().BeFalse();
        storage.GetProperty("partitionKeyChangeRequired").GetBoolean().Should().BeFalse();
        storage.GetProperty("uniqueKeyPolicyRequired").GetBoolean().Should().BeFalse();
        storage.GetProperty("intentIdStrategy").GetString().Should().Contain("personId");
        storage.GetProperty("operationIdStrategy").GetString().Should().Contain("personId");

        var indexingPolicy = storage.GetProperty("currentIndexingPolicy");
        indexingPolicy.GetProperty("indexingMode").GetString().Should().Be("consistent");
        indexingPolicy.GetProperty("automatic").GetBoolean().Should().BeTrue();
        indexingPolicy.GetProperty("includedPaths").EnumerateArray()
            .Select(path => path.GetString()).Should().Equal("/*");
        indexingPolicy.GetProperty("excludedPaths").EnumerateArray()
            .Select(path => path.GetString()).Should().Equal("/\"_etag\"/?");

        var cosmosMigration = cosmos.RootElement.GetProperty("x-certigo-migration");
        cosmosMigration.GetProperty("requiredEquality").GetString()
            .Should().Be("personId == profile.id == legacy userId");
        cosmosMigration.GetProperty("rewritesOwnerDocuments").GetBoolean().Should().BeFalse();
        cosmosMigration.GetProperty("partitionKeyChanges").GetBoolean().Should().BeFalse();
        cosmosMigration.GetProperty("existingOwnerContainers").EnumerateArray()
            .Select(container => container.GetString())
            .Should().Equal(
                "users",
                "progress",
                "attempts",
                "events",
                "economy",
                "friends",
                "leaderboard");

        var integrations = cosmos.RootElement.GetProperty("x-certigo-integrations");
        integrations.GetProperty("accountDeletion").GetProperty("baselineState").GetString()
            .Should().Be("merged");
        integrations.GetProperty("activeTrack").GetProperty("baselineState").GetString()
            .Should().Be("merged");
        integrations.GetProperty("onboardingCatalog").GetProperty("baselineState").GetString()
            .Should().Be("merged");

        var locatorProperties = cosmos.RootElement
            .GetProperty("$defs")
            .GetProperty("identityLocator")
            .GetProperty("properties");
        locatorProperties.TryGetProperty("provider", out _).Should().BeTrue();
        locatorProperties.TryGetProperty("tenant", out _).Should().BeTrue();
        locatorProperties.TryGetProperty("subject", out _).Should().BeTrue();
        locatorProperties.TryGetProperty("type", out _).Should().BeTrue();
        locatorProperties.TryGetProperty("email", out _).Should().BeFalse();
        cosmos.RootElement.GetProperty("$defs").GetProperty("identityLocator")
            .GetProperty("oneOf").GetArrayLength().Should().Be(2);
    }

    [Fact]
    public void Contracts_match_merged_deletion_onboarding_catalog_and_cosmos_baselines()
    {
        var containers = LoadRepositoryFile(
            "backend",
            "src",
            "Certigo.Infrastructure",
            "Cosmos",
            "CosmosContainers.cs");
        containers.Should().Contain("new(Users, \"/id\")");
        containers.Should().Contain("new(Progress, \"/userId\")");
        containers.Should().Contain("new(Attempts, \"/userId\", DefaultTimeToLive: -1)");

        var cosmosBicep = LoadRepositoryFile("infra", "modules", "cosmos.bicep");
        cosmosBicep.Should().Contain("{ name: 'users', pk: '/id' }");
        cosmosBicep.Should().Contain("path: '/*'");
        cosmosBicep.Should().Contain("path: '/\"_etag\"/?'");

        var deletionFunctions = LoadRepositoryFile(
            "backend",
            "src",
            "Certigo.Api",
            "Functions",
            "AccountDeletionFunctions.cs");
        deletionFunctions.Should().Contain("\"get\", Route = \"account/deletion\"");
        deletionFunctions.Should().Contain("\"post\", Route = \"account/deletion\"");
        deletionFunctions.Should().Contain("HttpStatusCode.Accepted");

        var activeTrackFunctions = LoadRepositoryFile(
            "backend",
            "src",
            "Certigo.Api",
            "Functions",
            "UserFunctions.cs");
        activeTrackFunctions.Should().Contain("Route = \"me/active-track\"");
        activeTrackFunctions.Should().Contain("body.ExpectedTrackId");

        var onboarding = LoadRepositoryFile(
            "apps",
            "mobile",
            "lib",
            "features",
            "onboarding",
            "presentation",
            "certification_screen.dart");
        onboarding.Should().Contain("track.hasLearningContent && track.isActive");
        onboarding.Should().Contain("activeTrackProvider.notifier");

        var activeTrackStore = LoadRepositoryFile(
            "apps",
            "mobile",
            "lib",
            "app",
            "active_track_store.dart");
        activeTrackStore.Should().Contain("required this.ownerId");
        activeTrackStore.Should().Contain("'ownerId': ownerId");

        var program = LoadRepositoryFile(
            "backend",
            "src",
            "Certigo.Api",
            "Program.cs");
        program.Should().Contain("PERSON_LINKED_IDENTITY_V1");
        program.Should().Contain("PersonLinkedIdentityOptions.Parse");
        program.Should().NotContain("IdentityLinkFunctions");
        program.Should().NotContain("IIdentityLinkService");

        foreach (var environment in new[] { "dev", "staging", "prod" })
        {
            LoadRepositoryFile(
                    "infra",
                    "params",
                    $"{environment}.bicepparam")
                .Should().Contain("param personLinkedIdentityV1 = 'off'");
        }

        var functionApp = LoadRepositoryFile(
            "infra",
            "modules",
            "functionApp.bicep");
        functionApp.Should().Contain("PERSON_LINKED_IDENTITY_V1: personLinkedIdentityV1");
    }

    [Fact]
    public void Local_backfill_preserves_person_id_and_every_existing_owner_partition()
    {
        var ownerDocuments = new[]
        {
            new OwnerDocument("users", "legacy-user", "legacy-user"),
            new OwnerDocument("progress", "legacy-user", "legacy-user"),
            new OwnerDocument("attempts", "legacy-user", "legacy-user"),
            new OwnerDocument("events", "legacy-user", "legacy-user"),
            new OwnerDocument("economy", "legacy-user", "legacy-user"),
            new OwnerDocument("friends", "legacy-user", "legacy-user"),
            new OwnerDocument("leaderboard", "2026-w34:bronze", "legacy-user"),
        };
        var store = new FakeIdentityStore(["legacy-user"], ownerDocuments);
        var before = store.OwnerDocuments.ToArray();

        var outcome = store.BackfillLocal(new LegacyCredential(
            "credential::canonical::learner@example.com",
            "legacy-user",
            "learner@example.com",
            IsVerified: true));

        outcome.Status.Should().Be(MigrationStatus.Created);
        outcome.Identity.PersonId.Should().Be("legacy-user");
        outcome.Identity.Locator.Subject.Should().NotContain("learner");
        outcome.Identity.Locator.Subject.Should().NotContain("@");
        outcome.Identity.Locator.Subject.Should().HaveLength(32);
        store.CredentialIdentitySubject(
            "credential::canonical::learner@example.com").Should()
            .Be(outcome.Identity.Locator.Subject);
        store.PersonIds.Should().Equal("legacy-user");
        store.OwnerDocuments.Should().BeEquivalentTo(before, options => options.WithStrictOrdering());
    }

    [Fact]
    public void Local_backfill_is_idempotent_and_collision_never_reassigns_the_identity()
    {
        var credential = new LegacyCredential(
            "credential::canonical::same@example.com",
            "person-a",
            "same@example.com",
            IsVerified: true);
        var store = new FakeIdentityStore(["person-a", "person-b"], []);

        var first = store.BackfillLocal(credential);
        var replay = store.BackfillLocal(credential);

        first.Status.Should().Be(MigrationStatus.Created);
        replay.Status.Should().Be(MigrationStatus.AlreadyPresent);
        replay.Identity.Should().Be(first.Identity);
        store.BindingCount.Should().Be(1);

        var conflictingCredential = credential with { PersonId = "person-b" };
        var act = () => store.BackfillLocal(conflictingCredential);

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("identity_already_linked");
        store.Resolve(first.Identity.Locator).Should().Be("person-a");
    }

    [Fact]
    public void Forced_identity_hash_collision_fails_closed()
    {
        const string forcedId = "linked-identity::v1::"
            + "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        var store = new FakeIdentityStore(
            ["person-a", "person-b"],
            [],
            identityIdFactory: _ => forcedId);
        store.Bind(
            new IdentityLocator(
                "certigo-local",
                "certigo",
                Hash("subject-a-opaque"),
                "localPassword"),
            "person-a",
            Now);

        var act = () => store.Bind(
            new IdentityLocator(
                "entra-external-id",
                TenantA,
                ExternalObjectB,
                "entraExternalId"),
            "person-b",
            Now);

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("identity_hash_collision");
        store.BindingCount.Should().Be(1);
    }

    [Fact]
    public void External_backfill_requires_validated_tid_and_oid_and_never_uses_email()
    {
        var store = new FakeIdentityStore([ExternalObjectA], []);
        var observation = new ExternalObservation(
            LegacyPersonId: ExternalObjectA,
            Tenant: TenantA,
            ObjectId: ExternalObjectA,
            Email: "shared@example.com",
            SignatureAndClaimsValidated: false);

        var invalid = () => store.BackfillExternal(observation);
        invalid.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("invalid_reauthentication");
        store.BindingCount.Should().Be(0);

        var valid = store.BackfillExternal(observation with
        {
            SignatureAndClaimsValidated = true,
        });

        valid.Identity.PersonId.Should().Be(ExternalObjectA);
        valid.Identity.Locator.Subject.Should().Be(ExternalObjectA);
        valid.Identity.Locator.Tenant.Should().Be(TenantA);
        store.BindingCount.Should().Be(1);
    }

    [Fact]
    public void Locator_canonicalization_rejects_ambiguous_values_instead_of_correcting_them()
    {
        var store = new FakeIdentityStore(["person-a"], []);

        var paddedProvider = () => store.Bind(
            new IdentityLocator(
                "certigo-local ",
                "certigo",
                Hash("local-subject"),
                "localPassword"),
            "person-a",
            Now);
        paddedProvider.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("invalid_identity_locator");

        var uppercaseTenant = () => store.Bind(
            new IdentityLocator(
                "entra-external-id",
                TenantA.ToUpperInvariant(),
                ExternalObjectA,
                "entraExternalId"),
            "person-a",
            Now);
        uppercaseTenant.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("invalid_identity_locator");

        var mismatchedProviderAndType = () => store.Bind(
            new IdentityLocator(
                "certigo-local",
                "certigo",
                Hash("another-local-subject"),
                "entraExternalId"),
            "person-a",
            Now);
        mismatchedProviderAndType.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("invalid_identity_locator");

        store.BindingCount.Should().Be(0);
    }

    [Fact]
    public void Linking_requires_recent_reauthentication_of_both_identities()
    {
        var fixture = LinkFixture.Create();
        var staleSource = fixture.SourceProof with { AuthenticatedAt = Now.AddMinutes(-6) };

        var begin = () => fixture.Coordinator.Begin(
            fixture.SourcePersonId,
            fixture.SourceIdentity.Id,
            staleSource,
            "entra-external-id",
            "entraExternalId",
            "begin-key");

        begin.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("invalid_reauthentication");

        var intent = fixture.Begin();
        var staleTarget = fixture.TargetProof(intent) with { AuthenticatedAt = Now.AddMinutes(-6) };
        var complete = () => fixture.Coordinator.Complete(intent.Id, "complete-key", staleTarget);

        complete.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("invalid_reauthentication");
    }

    [Fact]
    public void Shared_email_without_a_valid_target_proof_cannot_take_over_an_account()
    {
        var fixture = LinkFixture.Create();
        var intent = fixture.Begin();
        var forged = fixture.TargetProof(intent) with
        {
            SignatureAndClaimsValidated = false,
            Email = fixture.SourceProof.Email,
        };

        var act = () => fixture.Coordinator.Complete(intent.Id, "complete-key", forged);

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("invalid_reauthentication");
        fixture.Store.Resolve(forged.Locator).Should().BeNull();
        fixture.Store.Resolve(fixture.SourceIdentity.Locator).Should().Be(fixture.SourcePersonId);
    }

    [Fact]
    public void Exact_completion_replay_is_idempotent_but_a_different_replay_is_rejected()
    {
        var fixture = LinkFixture.Create();
        var intent = fixture.Begin();
        var targetProof = fixture.TargetProof(intent);

        var first = fixture.Coordinator.Complete(intent.Id, "complete-key", targetProof);
        var exactReplay = fixture.Coordinator.Complete(intent.Id, "complete-key", targetProof);

        exactReplay.Should().Be(first);
        fixture.Store.BindingCount.Should().Be(2);

        var conflictingReplay = () => fixture.Coordinator.Complete(
            intent.Id,
            "other-complete-key",
            targetProof with
            {
                Locator = targetProof.Locator with { Subject = ExternalObjectC },
            });

        conflictingReplay.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("replay_detected");
    }

    [Fact]
    public void Same_scoped_idempotency_key_with_different_payload_is_rejected()
    {
        var fixture = LinkFixture.Create();
        fixture.Begin();

        var act = () => fixture.Coordinator.Begin(
            fixture.SourcePersonId,
            fixture.SourceIdentity.Id,
            fixture.SourceProof,
            "certigo-local",
            "localPassword",
            "begin-key");

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("idempotency_conflict");
    }

    [Fact]
    public void Idempotency_key_is_scoped_independently_to_each_person()
    {
        var store = new FakeIdentityStore(["person-a", "person-b"], []);
        var sourceA = store.Bind(
            new IdentityLocator(
                "certigo-local",
                "certigo",
                Hash("source-a"),
                "localPassword"),
            "person-a",
            Now).Identity;
        var sourceB = store.Bind(
            new IdentityLocator(
                "certigo-local",
                "certigo",
                Hash("source-b"),
                "localPassword"),
            "person-b",
            Now).Identity;
        var coordinator = new FakeLinkCoordinator(
            store,
            Now,
            TenantA,
            "api://certigo-mobile");

        var intentA = coordinator.Begin(
            "person-a",
            sourceA.Id,
            ValidProof(sourceA.Locator, "source-a"),
            "entra-external-id",
            "entraExternalId",
            "same-client-key");
        var intentB = coordinator.Begin(
            "person-b",
            sourceB.Id,
            ValidProof(sourceB.Locator, "source-b"),
            "entra-external-id",
            "entraExternalId",
            "same-client-key");

        intentA.Id.Should().NotBe(intentB.Id);
        intentA.PersonId.Should().Be("person-a");
        intentB.PersonId.Should().Be("person-b");
    }

    [Fact]
    public void Target_proof_for_another_audience_is_rejected_as_confused_deputy()
    {
        var fixture = LinkFixture.Create();
        var intent = fixture.Begin();
        var proof = fixture.TargetProof(intent) with { Audience = "api://another-service" };

        var act = () => fixture.Coordinator.Complete(intent.Id, "complete-key", proof);

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("confused_deputy");
        fixture.Store.Resolve(proof.Locator).Should().BeNull();
    }

    [Fact]
    public void Source_proof_for_another_audience_is_rejected_as_confused_deputy()
    {
        var fixture = LinkFixture.Create();
        var sourceProof = fixture.SourceProof with { Audience = "api://another-service" };

        var act = () => fixture.Coordinator.Begin(
            fixture.SourcePersonId,
            fixture.SourceIdentity.Id,
            sourceProof,
            "entra-external-id",
            "entraExternalId",
            "begin-key");

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("confused_deputy");
        fixture.Store.BindingCount.Should().Be(1);
    }

    [Fact]
    public void Same_subject_from_another_tenant_cannot_satisfy_the_intent()
    {
        var fixture = LinkFixture.Create();
        var intent = fixture.Begin();
        var proof = fixture.TargetProof(intent) with
        {
            Locator = fixture.TargetProof(intent).Locator with { Tenant = TenantB },
        };

        var act = () => fixture.Coordinator.Complete(intent.Id, "complete-key", proof);

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("cross_tenant");
        fixture.Store.Resolve(proof.Locator).Should().BeNull();
    }

    [Fact]
    public void Local_target_with_shared_email_links_only_its_opaque_subject()
    {
        var store = new FakeIdentityStore(["source-person"], []);
        var source = store.Bind(
            new IdentityLocator(
                "entra-external-id",
                TenantA,
                ExternalObjectA,
                "entraExternalId"),
            "source-person",
            Now).Identity;
        var coordinator = new FakeLinkCoordinator(
            store,
            Now,
            "certigo",
            "api://certigo-mobile");
        var sourceProof = ValidProof(source.Locator, "source-reauth") with
        {
            Email = "shared@example.com",
        };
        var intent = coordinator.Begin(
            "source-person",
            source.Id,
            sourceProof,
            "certigo-local",
            "localPassword",
            "local-target-begin");
        var localLocator = new IdentityLocator(
            "certigo-local",
            "certigo",
            Hash("opaque-local-target"),
            "localPassword");
        var targetProof = ValidProof(localLocator, intent.Nonce) with
        {
            Email = "shared@example.com",
        };

        var result = coordinator.Complete(intent.Id, "local-target-complete", targetProof);

        result.PersonId.Should().Be("source-person");
        store.Resolve(localLocator).Should().Be("source-person");
        localLocator.Subject.Should().NotContain("@");
        localLocator.Subject.Should().NotContain("shared");
    }

    [Fact]
    public void Same_identity_cannot_be_linked_to_itself()
    {
        var fixture = LinkFixture.Create();
        var coordinator = new FakeLinkCoordinator(
            fixture.Store,
            Now,
            "certigo",
            "api://certigo-mobile");
        var intent = coordinator.Begin(
            fixture.SourcePersonId,
            fixture.SourceIdentity.Id,
            fixture.SourceProof,
            "certigo-local",
            "localPassword",
            "same-identity-begin");
        var targetProof = ValidProof(fixture.SourceIdentity.Locator, intent.Nonce);

        var act = () => coordinator.Complete(
            intent.Id,
            "same-identity-complete",
            targetProof);

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("same_identity");
        fixture.Store.BindingCount.Should().Be(1);
    }

    [Fact]
    public void Identity_already_linked_to_another_person_is_never_merged()
    {
        var fixture = LinkFixture.Create();
        var intent = fixture.Begin();
        var targetProof = fixture.TargetProof(intent);
        fixture.Store.AddPerson("victim-person");
        fixture.Store.Bind(targetProof.Locator, "victim-person", Now);

        var act = () => fixture.Coordinator.Complete(intent.Id, "complete-key", targetProof);

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("identity_already_linked");
        fixture.Store.Resolve(targetProof.Locator).Should().Be("victim-person");
        fixture.Store.Resolve(fixture.SourceIdentity.Locator).Should().Be(fixture.SourcePersonId);
    }

    [Fact]
    public void Account_deletion_lock_blocks_begin_and_complete_before_any_new_binding()
    {
        var blockedBegin = LinkFixture.Create();
        blockedBegin.Store.BeginDeletion(blockedBegin.SourcePersonId);

        var begin = () => blockedBegin.Begin();
        begin.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("account_deletion_in_progress");
        blockedBegin.Store.BindingCount.Should().Be(1);

        var blockedComplete = LinkFixture.Create();
        var intent = blockedComplete.Begin();
        blockedComplete.Store.BeginDeletion(blockedComplete.SourcePersonId);

        var complete = () => blockedComplete.Coordinator.Complete(
            intent.Id,
            "complete-key",
            blockedComplete.TargetProof(intent));
        complete.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("account_deletion_in_progress");
        blockedComplete.Store.BindingCount.Should().Be(1);
    }

    [Fact]
    public void Wrong_nonce_cannot_be_used_to_complete_an_intent()
    {
        var fixture = LinkFixture.Create();
        var intent = fixture.Begin();
        var proof = fixture.TargetProof(intent) with { Nonce = "nonce-from-another-intent" };

        var act = () => fixture.Coordinator.Complete(intent.Id, "complete-key", proof);

        act.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("replay_detected");
        fixture.Store.Resolve(proof.Locator).Should().BeNull();
    }

    [Fact]
    public void Last_identity_cannot_be_revoked_and_a_revoked_identity_remains_a_tombstone()
    {
        var fixture = LinkFixture.Create();

        var lastIdentity = () => fixture.Coordinator.Revoke(
            fixture.SourcePersonId,
            fixture.SourceIdentity.Id,
            "revoke-source",
            fixture.SourceProof);
        lastIdentity.Should().Throw<ContractViolationException>()
            .Which.Code.Should().Be("last_identity");

        var second = fixture.Store.Bind(
            new IdentityLocator(
                "entra-external-id",
                TenantA,
                ExternalObjectC,
                "entraExternalId"),
            fixture.SourcePersonId,
            Now).Identity;
        var revoked = fixture.Coordinator.Revoke(
            fixture.SourcePersonId,
            fixture.SourceIdentity.Id,
            "revoke-source",
            fixture.SourceProof);
        var exactReplay = fixture.Coordinator.Revoke(
            fixture.SourcePersonId,
            fixture.SourceIdentity.Id,
            "revoke-source",
            ValidProof(second.Locator, "revoke-replay"));

        revoked.RevokedAt.Should().Be(Now);
        revoked.Generation.Should().Be(2);
        exactReplay.Should().Be(revoked);
        fixture.Store.Find(fixture.SourceIdentity.Id).Should().Be(revoked);
        fixture.Store.Resolve(fixture.SourceIdentity.Locator).Should().BeNull();
        fixture.Store.Resolve(second.Locator).Should().Be(fixture.SourcePersonId);
        fixture.Store.BindingCount.Should().Be(2);
    }

    private static JsonDocument LoadContract(string fileName) =>
        JsonDocument.Parse(LoadRepositoryFile(
            "docs",
            "contracts",
            "person-linked-identity",
            "v1",
            fileName));

    private static string LoadRepositoryFile(params string[] pathSegments)
    {
        var relativePath = Path.Combine(pathSegments);
        var directory = AppContext.BaseDirectory;
        while (directory is not null)
        {
            var candidate = Path.Combine(directory, relativePath);
            if (File.Exists(candidate))
            {
                return File.ReadAllText(candidate);
            }

            directory = Directory.GetParent(directory)?.FullName;
        }

        throw new InvalidOperationException(
            $"{relativePath} not found walking up from {AppContext.BaseDirectory}");
    }

    private sealed record OwnerDocument(string Container, string PartitionKey, string OwnerId);

    private sealed record LegacyCredential(
        string Id,
        string PersonId,
        string Email,
        bool IsVerified,
        string? IdentitySubject = null);

    private sealed record ExternalObservation(
        string LegacyPersonId,
        string Tenant,
        string ObjectId,
        string Email,
        bool SignatureAndClaimsValidated);

    private enum MigrationStatus
    {
        Created,
        AlreadyPresent,
    }

    private sealed record MigrationOutcome(MigrationStatus Status, LinkedIdentity Identity);

    private sealed record IdentityLocator(
        string Provider,
        string Tenant,
        string Subject,
        string Type)
    {
        public IdentityLocator Canonical()
        {
            if (!IsCanonicalText(Provider)
                || !IsCanonicalText(Tenant)
                || !IsCanonicalText(Subject)
                || !IsCanonicalText(Type))
            {
                throw new ContractViolationException("invalid_identity_locator");
            }

            var isLocal = Provider == "certigo-local"
                && Tenant == "certigo"
                && Type == "localPassword"
                && IsLowerHex(Subject, 32);
            var isEntra = Provider == "entra-external-id"
                && Type == "entraExternalId"
                && IsCanonicalGuid(Tenant)
                && IsCanonicalGuid(Subject);
            if (!isLocal && !isEntra)
            {
                throw new ContractViolationException("invalid_identity_locator");
            }

            return this;
        }

        public string StableId()
        {
            var canonical = Canonical();
            var material = string.Join(
                "\0",
                "certigo-linked-identity:v1",
                canonical.Provider,
                canonical.Tenant,
                canonical.Subject,
                canonical.Type);
            return $"linked-identity::v1::{Hash(material)}";
        }

        private static bool IsCanonicalText(string value) =>
            !string.IsNullOrWhiteSpace(value)
            && value == value.Trim()
            && !value.Any(char.IsControl);

        private static bool IsLowerHex(string value, int minimumLength) =>
            value.Length >= minimumLength
            && value.All(character =>
                character is >= '0' and <= '9'
                || character is >= 'a' and <= 'f');

        private static bool IsCanonicalGuid(string value) =>
            Guid.TryParseExact(value, "D", out var parsed)
            && parsed.ToString("D") == value;
    }

    private sealed record LinkedIdentity(
        string Id,
        string PersonId,
        IdentityLocator Locator,
        DateTimeOffset VerifiedAt,
        DateTimeOffset? RevokedAt = null,
        int Generation = 1)
    {
        public bool IsActive => RevokedAt is null;
    }

    private sealed class FakeIdentityStore
    {
        private readonly HashSet<string> _personIds;
        private readonly Dictionary<string, LinkedIdentity> _bindings = new(StringComparer.Ordinal);
        private readonly Dictionary<string, LegacyCredential> _credentials = new(StringComparer.Ordinal);
        private readonly HashSet<string> _deletingPersonIds = new(StringComparer.Ordinal);
        private readonly Func<IdentityLocator, string> _identityIdFactory;

        public FakeIdentityStore(
            IEnumerable<string> personIds,
            IEnumerable<OwnerDocument> ownerDocuments,
            Func<IdentityLocator, string>? identityIdFactory = null)
        {
            _personIds = new HashSet<string>(personIds, StringComparer.Ordinal);
            OwnerDocuments = ownerDocuments.ToArray();
            _identityIdFactory = identityIdFactory ?? (locator => locator.StableId());
        }

        public IReadOnlyList<string> PersonIds =>
            _personIds.OrderBy(id => id, StringComparer.Ordinal).ToArray();

        public IReadOnlyList<OwnerDocument> OwnerDocuments { get; }

        public int BindingCount => _bindings.Count;

        public void AddPerson(string personId) => _personIds.Add(personId);

        public void BeginDeletion(string personId)
        {
            EnsurePerson(personId);
            _deletingPersonIds.Add(personId);
        }

        public bool IsDeletionInProgress(string personId) => _deletingPersonIds.Contains(personId);

        public MigrationOutcome BackfillLocal(LegacyCredential credential)
        {
            EnsurePerson(credential.PersonId);
            if (!credential.IsVerified)
            {
                throw new ContractViolationException("invalid_reauthentication");
            }

            if (_credentials.TryGetValue(credential.Id, out var stored))
            {
                if (!string.Equals(stored.PersonId, credential.PersonId, StringComparison.Ordinal))
                {
                    var existingLocator = new IdentityLocator(
                        "certigo-local",
                        "certigo",
                        stored.IdentitySubject
                            ?? throw new InvalidOperationException(
                                "Stored credential subject is missing."),
                        "localPassword");
                    return Bind(existingLocator, credential.PersonId, Now);
                }
            }
            else
            {
                stored = credential;
            }

            if (string.IsNullOrWhiteSpace(stored.IdentitySubject))
            {
                stored = stored with
                {
                    IdentitySubject = Convert.ToHexString(RandomNumberGenerator.GetBytes(16))
                        .ToLowerInvariant(),
                };
                _credentials[stored.Id] = stored;
            }

            var identitySubject = stored.IdentitySubject
                ?? throw new InvalidOperationException(
                    "Stored credential subject is missing after migration.");
            return Bind(
                new IdentityLocator(
                    "certigo-local",
                    "certigo",
                    identitySubject,
                    "localPassword"),
                credential.PersonId,
                Now);
        }

        public MigrationOutcome BackfillExternal(ExternalObservation observation)
        {
            EnsurePerson(observation.LegacyPersonId);
            if (!observation.SignatureAndClaimsValidated
                || string.IsNullOrWhiteSpace(observation.Tenant)
                || string.IsNullOrWhiteSpace(observation.ObjectId))
            {
                throw new ContractViolationException("invalid_reauthentication");
            }

            return Bind(
                new IdentityLocator(
                    "entra-external-id",
                    observation.Tenant,
                    observation.ObjectId,
                    "entraExternalId"),
                observation.LegacyPersonId,
                Now);
        }

        public MigrationOutcome Bind(
            IdentityLocator locator,
            string personId,
            DateTimeOffset verifiedAt)
        {
            EnsurePerson(personId);
            var canonical = locator.Canonical();
            var id = IdentityId(canonical);
            if (_bindings.TryGetValue(id, out var existing))
            {
                if (existing.Locator != canonical)
                {
                    throw new ContractViolationException("identity_hash_collision");
                }

                if (!string.Equals(existing.PersonId, personId, StringComparison.Ordinal))
                {
                    throw new ContractViolationException("identity_already_linked");
                }

                return new MigrationOutcome(MigrationStatus.AlreadyPresent, existing);
            }

            var identity = new LinkedIdentity(id, personId, canonical, verifiedAt);
            _bindings.Add(id, identity);
            return new MigrationOutcome(MigrationStatus.Created, identity);
        }

        public string IdentityId(IdentityLocator locator) =>
            _identityIdFactory(locator.Canonical());

        public string? Resolve(IdentityLocator locator)
        {
            var identity = _bindings.GetValueOrDefault(IdentityId(locator));
            return identity?.IsActive == true ? identity.PersonId : null;
        }

        public LinkedIdentity? Find(string identityId) =>
            _bindings.GetValueOrDefault(identityId);

        public LinkedIdentity Revoke(
            string identityId,
            string personId,
            DateTimeOffset revokedAt)
        {
            var identity = Find(identityId)
                ?? throw new ContractViolationException("identity_not_found");
            if (!string.Equals(identity.PersonId, personId, StringComparison.Ordinal))
            {
                throw new ContractViolationException("identity_not_found");
            }

            if (!identity.IsActive)
            {
                return identity;
            }

            if (_bindings.Values.Count(candidate =>
                    candidate.IsActive
                    && string.Equals(candidate.PersonId, personId, StringComparison.Ordinal)) <= 1)
            {
                throw new ContractViolationException("last_identity");
            }

            var revoked = identity with
            {
                RevokedAt = revokedAt,
                Generation = identity.Generation + 1,
            };
            _bindings[identityId] = revoked;
            return revoked;
        }

        public string? CredentialIdentitySubject(string credentialId) =>
            _credentials.GetValueOrDefault(credentialId)?.IdentitySubject;

        private void EnsurePerson(string personId)
        {
            if (!_personIds.Contains(personId))
            {
                throw new InvalidOperationException($"Person '{personId}' was not seeded.");
            }
        }
    }

    private sealed record ReauthenticationProof(
        IdentityLocator Locator,
        string Audience,
        string Nonce,
        DateTimeOffset AuthenticatedAt,
        bool SignatureAndClaimsValidated,
        string? Email = null);

    private sealed record LinkIntent(
        string Id,
        string PersonId,
        string SourceIdentityId,
        string TargetProvider,
        string TargetTenant,
        string TargetType,
        string Nonce,
        DateTimeOffset ExpiresAt)
    {
        public LinkResult? Result { get; set; }
        public string? CompletionKey { get; set; }
        public string? CompletionIdentityId { get; set; }
    }

    private sealed record LinkResult(string OperationId, string PersonId, string LinkedIdentityId);

    private sealed class FakeLinkCoordinator(
        FakeIdentityStore store,
        DateTimeOffset now,
        string trustedTenant,
        string targetAudience)
    {
        private static readonly TimeSpan ReauthenticationWindow = TimeSpan.FromMinutes(5);
        private readonly Dictionary<string, LinkIntent> _intents = new(StringComparer.Ordinal);
        private readonly Dictionary<string, LinkIntent> _beginByKey = new(StringComparer.Ordinal);
        private readonly Dictionary<string, (string IdentityId, LinkedIdentity Result)> _revokeByKey =
            new(StringComparer.Ordinal);

        public LinkIntent Begin(
            string personId,
            string sourceIdentityId,
            ReauthenticationProof sourceProof,
            string targetProvider,
            string targetType,
            string idempotencyKey)
        {
            EnsureLinkingAllowed(personId);
            ValidateFresh(sourceProof);
            if (!string.Equals(sourceProof.Audience, targetAudience, StringComparison.Ordinal))
            {
                throw new ContractViolationException("confused_deputy");
            }

            var sourceIdentity = store.Find(sourceIdentityId)
                ?? throw new ContractViolationException("invalid_reauthentication");
            if (!string.Equals(sourceIdentity.PersonId, personId, StringComparison.Ordinal)
                || sourceIdentity.Locator != sourceProof.Locator.Canonical())
            {
                throw new ContractViolationException("invalid_reauthentication");
            }

            var scopedIdempotencyKey = $"{personId}\0{idempotencyKey}";
            if (_beginByKey.TryGetValue(scopedIdempotencyKey, out var replay))
            {
                if (replay.PersonId == personId
                    && replay.SourceIdentityId == sourceIdentityId
                    && replay.TargetProvider == targetProvider
                    && replay.TargetType == targetType)
                {
                    return replay;
                }

                throw new ContractViolationException("idempotency_conflict");
            }

            var intent = new LinkIntent(
                $"identity-link-intent::v1::{Hash($"intent\0{personId}\0{idempotencyKey}")}",
                personId,
                sourceIdentityId,
                targetProvider,
                trustedTenant,
                targetType,
                $"nonce-{Hash($"nonce\0{personId}\0{idempotencyKey}")}",
                now.AddMinutes(5));
            _intents.Add(intent.Id, intent);
            _beginByKey.Add(scopedIdempotencyKey, intent);
            return intent;
        }

        public LinkResult Complete(
            string intentId,
            string idempotencyKey,
            ReauthenticationProof targetProof)
        {
            var intent = _intents.GetValueOrDefault(intentId)
                ?? throw new ContractViolationException("intent_not_found");
            EnsureLinkingAllowed(intent.PersonId);
            var targetIdentityId = store.IdentityId(targetProof.Locator);

            if (intent.Result is not null)
            {
                if (string.Equals(intent.CompletionKey, idempotencyKey, StringComparison.Ordinal)
                    && string.Equals(
                        intent.CompletionIdentityId,
                        targetIdentityId,
                        StringComparison.Ordinal))
                {
                    return intent.Result;
                }

                throw new ContractViolationException("replay_detected");
            }

            if (intent.ExpiresAt <= now
                || !string.Equals(intent.Nonce, targetProof.Nonce, StringComparison.Ordinal))
            {
                throw new ContractViolationException("replay_detected");
            }

            ValidateFresh(targetProof);
            if (!string.Equals(targetProof.Audience, targetAudience, StringComparison.Ordinal))
            {
                throw new ContractViolationException("confused_deputy");
            }

            var canonical = targetProof.Locator.Canonical();
            if (!string.Equals(canonical.Provider, intent.TargetProvider, StringComparison.Ordinal)
                || !string.Equals(canonical.Type, intent.TargetType, StringComparison.Ordinal))
            {
                throw new ContractViolationException("invalid_reauthentication");
            }

            if (!string.Equals(canonical.Tenant, intent.TargetTenant, StringComparison.Ordinal))
            {
                throw new ContractViolationException("cross_tenant");
            }

            var sourceIdentity = store.Find(intent.SourceIdentityId)
                ?? throw new ContractViolationException("invalid_reauthentication");
            if (sourceIdentity.Locator == canonical)
            {
                throw new ContractViolationException("same_identity");
            }

            var binding = store.Bind(canonical, intent.PersonId, now).Identity;
            var result = new LinkResult(
                $"identity-link-operation::v1::{Hash(
                    $"operation\0{intent.PersonId}\0{idempotencyKey}")}",
                intent.PersonId,
                binding.Id);
            intent.Result = result;
            intent.CompletionKey = idempotencyKey;
            intent.CompletionIdentityId = binding.Id;
            return result;
        }

        public LinkedIdentity Revoke(
            string personId,
            string identityId,
            string idempotencyKey,
            ReauthenticationProof proof)
        {
            EnsureLinkingAllowed(personId);
            ValidateFresh(proof);
            if (!string.Equals(proof.Audience, targetAudience, StringComparison.Ordinal)
                || !string.Equals(store.Resolve(proof.Locator), personId, StringComparison.Ordinal))
            {
                throw new ContractViolationException("invalid_reauthentication");
            }

            var scopedKey = $"{personId}\0{idempotencyKey}";
            if (_revokeByKey.TryGetValue(scopedKey, out var replay))
            {
                if (string.Equals(replay.IdentityId, identityId, StringComparison.Ordinal))
                {
                    return replay.Result;
                }

                throw new ContractViolationException("idempotency_conflict");
            }

            var result = store.Revoke(identityId, personId, now);
            _revokeByKey.Add(scopedKey, (identityId, result));
            return result;
        }

        private void EnsureLinkingAllowed(string personId)
        {
            if (store.IsDeletionInProgress(personId))
            {
                throw new ContractViolationException("account_deletion_in_progress");
            }
        }

        private void ValidateFresh(ReauthenticationProof proof)
        {
            if (!proof.SignatureAndClaimsValidated
                || proof.AuthenticatedAt < now - ReauthenticationWindow
                || proof.AuthenticatedAt > now.AddMinutes(2))
            {
                throw new ContractViolationException("invalid_reauthentication");
            }
        }
    }

    private sealed record LinkFixture(
        FakeIdentityStore Store,
        FakeLinkCoordinator Coordinator,
        string SourcePersonId,
        LinkedIdentity SourceIdentity,
        ReauthenticationProof SourceProof)
    {
        public static LinkFixture Create()
        {
            var store = new FakeIdentityStore(["source-person"], []);
            var sourceLocator = new IdentityLocator(
                "certigo-local",
                "certigo",
                Hash("source-local-subject"),
                "localPassword");
            var sourceIdentity = store.Bind(sourceLocator, "source-person", Now).Identity;
            var coordinator = new FakeLinkCoordinator(
                store,
                Now,
                TenantA,
                "api://certigo-mobile");
            var sourceProof = new ReauthenticationProof(
                sourceLocator,
                "api://certigo-mobile",
                "source-reauth",
                Now,
                SignatureAndClaimsValidated: true,
                Email: "shared@example.com");
            return new LinkFixture(
                store,
                coordinator,
                "source-person",
                sourceIdentity,
                sourceProof);
        }

        public LinkIntent Begin() => Coordinator.Begin(
            SourcePersonId,
            SourceIdentity.Id,
            SourceProof,
            "entra-external-id",
            "entraExternalId",
            "begin-key");

        public ReauthenticationProof TargetProof(LinkIntent intent) => new(
            new IdentityLocator(
                "entra-external-id",
                TenantA,
                ExternalObjectB,
                "entraExternalId"),
            "api://certigo-mobile",
            intent.Nonce,
            Now,
            SignatureAndClaimsValidated: true,
            Email: "shared@example.com");
    }

    private sealed class ContractViolationException(string code) : Exception(code)
    {
        public string Code { get; } = code;
    }

    private static string Hash(string value) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)))
            .ToLowerInvariant();

    private static ReauthenticationProof ValidProof(
        IdentityLocator locator,
        string nonce) => new(
            locator,
            "api://certigo-mobile",
            nonce,
            Now,
            SignatureAndClaimsValidated: true);
}
