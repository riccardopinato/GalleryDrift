#!/usr/bin/env python3
"""Verify APK signer X.509 certificate SHA-256 from PEM, not localized text.

Android's apksigner verifies the APK cryptographic signature and --print-certs-pem
prints signer certificate(s) in machine-readable PEM.  Comparing the DER SHA-256
is independent of the human-readable reporting format and SDK range labels.
"""
import argparse
import hashlib
import re
import ssl
import subprocess
from pathlib import Path

PEM_CERTIFICATE = re.compile(
    r"-----BEGIN CERTIFICATE-----\s*[A-Za-z0-9+/\s=]+?\s*-----END CERTIFICATE-----",
    flags=re.MULTILINE,
)
HEX64 = re.compile(r"[0-9a-f]{64}\Z")


def normalize(value: str) -> str:
    return re.sub(r"[:\s]", "", value).lower()


def verify_report(report: str, expected: str) -> set[str]:
    expected_sha = normalize(expected)
    if not HEX64.fullmatch(expected_sha):
        raise ValueError("EXPECTED_FINGERPRINT_INVALID: require 64 hexadecimal digits")
    matches = PEM_CERTIFICATE.findall(report)
    if not matches:
        raise ValueError(
            "APK_CERT_PEM_NOT_FOUND: apksigner did not report any signer certificate PEM"
        )
    observed = set()
    for pem in matches:
        try:
            der = ssl.PEM_cert_to_DER_cert(pem)
        except (ValueError, ssl.SSLError) as error:
            raise ValueError("APK_CERT_PEM_INVALID: malformed signer certificate") from error
        observed.add(hashlib.sha256(der).hexdigest())
    if observed != {expected_sha}:
        raise ValueError(
            "APK_SIGNING_CERT_MISMATCH: APK signer certificate SHA-256 differs "
            "from the pinned expected certificate; observed="
            + ",".join(sorted(observed))
        )
    return observed


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
        [str(args.apksigner), "verify", "--print-certs-pem", str(args.apk)],
        check=True, capture_output=True, text=True
    )
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(result.stdout, encoding="utf-8")
    verify_report(result.stdout, args.expected)
    print("SIGNING_IDENTITY_VERIFIED_FROM_PEM")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
