#!/bin/sh
set -eu

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

version=${CERTIGO_DISTRIBUTION_VERSION-}
build=${CERTIGO_DISTRIBUTION_BUILD-}
case "$version$build" in
    *'
'*) fail 'Distribution version parameters must be single-line values.' ;;
esac
printf '%s\n' "$version" | LC_ALL=C grep -Eq '^(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})\.(0|[1-9][0-9]{0,3})$' \
    || fail 'Set CERTIGO_DISTRIBUTION_VERSION to an explicit numeric major.minor.patch version confirmed in App Store Connect.'
printf '%s\n' "$build" | LC_ALL=C grep -Eq '^[1-9][0-9]{0,3}$' \
    || fail 'Set CERTIGO_DISTRIBUTION_BUILD to an explicit positive integer (1-9999) confirmed unused and increasing in App Store Connect.'

[ "${MARKETING_VERSION-}" = "$version" ] \
    || fail 'MARKETING_VERSION must resolve to CERTIGO_DISTRIBUTION_VERSION; do not override it separately.'
[ "${CURRENT_PROJECT_VERSION-}" = "$build" ] \
    || fail 'CURRENT_PROJECT_VERSION must resolve to CERTIGO_DISTRIBUTION_BUILD; do not override it separately.'

printf 'Distribution version parameters validated locally; App Store Connect availability is not verified.\n'
