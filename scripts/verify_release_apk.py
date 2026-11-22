#!/usr/bin/env python3
"""Fail-closed comparison of APK signer certificate SHA-256 digests.

Android build-tools apksigner versions may report "Signer #1" or
"Signer (minSdkVersion=..., maxSdkVersion=...)". A fixed "#1" sed
expression can falsely reject a correctly signed APK.
"""
import argparse
import re
import subprocess
from pathlib import Path

CERT_SHA256_LINE = re.compile(
    r"(?im)^\\s*Signer\\s+(?:#\\d+|\\([^\\r\\n)]*\\))"
    r"\\s+certificate\\s+SHA-256\\s+digest\\s*:\\s*([0-9a-fA-F:]+)\\s*$"
)
HEX64 = re.compile(r"[0-9a-f]{64}\\Z")


def normalize(text: str) -> str:
    return re.sub(r"[:\\s]", "", text).lower()


def verify_report(report: str, expected: str) -> set[str]:
    normalized_expected = normalize(expected)
    if not HEX64.fullmatch(normalized_expected):
        raise ValueError("EXPECTED_FINGERPRINT_INVALID: expected 64 hex digits")
    digests = [normalize(m.group(1)) for m in CERT_SHA256_LINE.finditer(report)]
    if not digests:
        raise ValueError(
            "APK_CERT_SHA256_NOT_FOUND: apksigner output did not contain an "
            "understood certificate digest (check build-tools output variant)"
        )
    if any(not HEX64.fullmatch(digest) for digest in digests):
        raise ValueError("APK_CERT_SHA256_INVALID: malformed signer certificate digest")
    unique = set(digests)
    if unique != {normalized_expected}:
        raise ValueError(
            "APK_SIGNING_CERT_MISMATCH: APK signer certificates do not match "
            "ANDROID_CERT_SHA256; signer digests="
            + ",".join(sorted(unique))
        )
    return unique


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--apksigner", type=Path, required=True)
    parser.add_argument("--expected", required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    if not args.apk.is_file():
        parser.error("APK_MISSING")
    result = subprocess.run(
        [str(args.apksigner), "verify", "--print-certs", str(args.apk)],
        check=True, capture_output=True, text=True,
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(result.stdout, encoding="utf-8")
    verify_report(result.stdout, args.expected)
    print("SIGNING_IDENTITY_VERIFIED")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
