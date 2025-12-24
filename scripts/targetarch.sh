#!/usr/bin/env sh
# Provide TARGETARCH and MULTIARCH_LIBDIR for multiarch layouts.

die() {
  printf '%s\n' "$*" >&2
  return 1 2>/dev/null || exit 1
}

if [ -z "${TARGETARCH:-}" ]; then
  case "$(uname -m)" in
    x86_64) TARGETARCH=amd64 ;;
    aarch64 | arm64) TARGETARCH=arm64 ;;
    *) die "Unsupported host architecture: $(uname -m)" ;;
  esac
fi

case "${TARGETARCH}" in
  amd64) MULTIARCH_LIBDIR=x86_64-linux-gnu ;;
  arm64) MULTIARCH_LIBDIR=aarch64-linux-gnu ;;
  *) die "Unsupported TARGETARCH: ${TARGETARCH}" ;;
esac

export TARGETARCH MULTIARCH_LIBDIR
