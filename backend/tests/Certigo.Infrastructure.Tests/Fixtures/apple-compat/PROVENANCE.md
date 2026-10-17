# Public content test-vector provenance

`v1/` is an exact, unmodified copy of
`gaby27072001/certigo-content/test/fixtures/apple-compat/v1/` at commit
`6922952936678c1bc37d8bb0db9e50afbef38a90`
([source](https://github.com/gaby27072001/certigo-content/tree/6922952936678c1bc37d8bb0db9e50afbef38a90/test/fixtures/apple-compat/v1)).

The five files were downloaded individually and their unfiltered Git blob
identities checked against that commit:

| File | Git blob |
| --- | --- |
| `README.md` | `d51e2950f7b091124fbe0ff048cfb9fc8e943f83` |
| `expected-outcomes.json` | `35b7bb770436292e68bc313ba17f9ba500b75965` |
| `supported/question-v3.json` | `50aea70f9097ecf8ca09326d26726c4fd0021538` |
| `supported/question-v4-mcq.json` | `459d59639ad86349c73c39a9c6edd9b3bc3a56a8` |
| `capability-probes/question-v4-spot-the-issue.json` | `74304129e7da084805a7a18e753a750c009311e6` |

`AppleContentCompatibilityTests` exercises the real embedded backend question
schema, including the two malformed mutations, and compares C# sorted-key
UTF-8 serialization with the producer's body and LF-terminated file vectors.
The real `ContentContractVerifier.VerifyReleaseAsync` entry point also reads each
public vector inside an in-memory synthetic manifest whose file size and digest
come from the producer. It verifies the descriptor/manifest identities and public
file bytes/schema/identity, then the test source deliberately throws at the first
private-manifest request. Body-only and CRLF-terminated payloads fail before that
boundary. No private resources are supplied or read.

The Apple capability profile is a client constraint, not a backend rejection rule:
the `spotTheIssue` probe remains schema-valid.

These are test resources only. The public-only boundary check is not successful
verification of a complete release or its private graph. This copy does not update
the content revision pin, verify a full candidate release, establish Swift parity,
or prove a deployed or activated release. No answer-key resources are copied.
