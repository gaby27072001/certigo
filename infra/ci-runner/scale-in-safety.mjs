function parseOptionalTimestamp(value, name) {
  if (value === null || value === undefined) {
    return null;
  }
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) {
    throw new Error(`${name} must be an ISO-8601 timestamp`);
  }
  return timestamp;
}

export function advanceScaleInSafety({
  idle,
  now = Date.now(),
  quietPeriodSeconds,
  rearmSatisfied = false,
  requiredGuards,
  state = {},
}) {
  if (!Number.isFinite(now)) {
    throw new Error('now must be a finite epoch timestamp');
  }
  if (!Number.isInteger(quietPeriodSeconds) || quietPeriodSeconds <= 0) {
    throw new Error('quietPeriodSeconds must be a positive integer');
  }
  if (!Number.isInteger(requiredGuards) || requiredGuards < 2) {
    throw new Error('requiredGuards must be at least 2');
  }

  const previousQuietSince = parseOptionalTimestamp(
    state.quietSince,
    'scaleInSafety.quietSince',
  );
  const previousLastGuardAt = parseOptionalTimestamp(
    state.lastGuardAt,
    'scaleInSafety.lastGuardAt',
  );
  const previousGuardCount = state.guardCount ?? 0;
  if (
    !Number.isInteger(previousGuardCount) ||
    previousGuardCount < 0 ||
    previousGuardCount > requiredGuards
  ) {
    throw new Error(
      `scaleInSafety.guardCount must be between 0 and ${requiredGuards}`,
    );
  }
  if (previousQuietSince !== null && previousQuietSince > now) {
    throw new Error('scaleInSafety.quietSince must not be in the future');
  }
  if (previousGuardCount === 0 && previousLastGuardAt !== null) {
    throw new Error(
      'scaleInSafety.lastGuardAt requires at least one completed guard',
    );
  }
  if (previousGuardCount > 0) {
    if (previousQuietSince === null || previousLastGuardAt === null) {
      throw new Error(
        'scaleInSafety guards require quietSince and lastGuardAt',
      );
    }
    if (
      previousLastGuardAt <
        previousQuietSince + quietPeriodSeconds * 1000 ||
      previousLastGuardAt > now
    ) {
      throw new Error(
        'scaleInSafety.lastGuardAt must follow the quiet period and not be in the future',
      );
    }
  }

  const rearmArmed = state.rearmArmed === true && !rearmSatisfied;
  if (!idle) {
    return {
      guardCount: 0,
      quietComplete: false,
      quietElapsedSeconds: 0,
      quietReset: previousQuietSince !== null,
      ready: false,
      rearmRequired: rearmArmed,
      nextState: {
        guardCount: 0,
        lastGuardAt: null,
        quietSince: null,
        rearmArmed,
      },
    };
  }

  const quietSince = previousQuietSince ?? now;
  const quietElapsedSeconds = Math.max(
    0,
    Math.floor((now - quietSince) / 1000),
  );
  const quietComplete = quietElapsedSeconds >= quietPeriodSeconds;
  let guardCount = previousGuardCount;
  let lastGuardAt = previousLastGuardAt;
  if (
    quietComplete &&
    (lastGuardAt === null || now > lastGuardAt)
  ) {
    guardCount = Math.min(requiredGuards, guardCount + 1);
    lastGuardAt = now;
  }

  return {
    guardCount,
    quietComplete,
    quietElapsedSeconds,
    quietReset: false,
    ready: quietComplete && guardCount >= requiredGuards,
    rearmRequired: false,
    nextState: {
      guardCount,
      lastGuardAt:
        lastGuardAt === null ? null : new Date(lastGuardAt).toISOString(),
      quietSince: new Date(quietSince).toISOString(),
      rearmArmed,
    },
  };
}

export function armScaleInReactivation(state) {
  return {
    guardCount: 0,
    lastGuardAt: null,
    quietSince: null,
    rearmArmed: true,
  };
}
