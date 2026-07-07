/// Version of the Cortex adaptive-learning algorithm.
///
/// This is the single source of truth for the algorithm contract that the Dart
/// client and the .NET backend MUST implement identically. It is pinned in the
/// shared golden vectors (`test/golden/cortex_golden_vectors.json`) and asserted
/// by both the Dart golden tests and the backend `CortexParityTests`, so bumping
/// it here forces a matching bump of `CortexAlgo.Version` on the backend and a
/// refresh of the golden expectations. Any behavioural change to scheduling,
/// mastery, weakness, readiness or recommendations math is a version change.
const String cortexAlgoVersion = '1.0.0';
