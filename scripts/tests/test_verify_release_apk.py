"""Regression tests for Android build-tools signer-report formats."""
import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_release_apk import verify_report

SHA = "f40006cf22c4498e49f35737d050f65d0a0514e3ba8e946a089027aa1044399b"
OTHER = "a" * 64


class ApkCertificateParsingTests(unittest.TestCase):
    def test_numbered_signer(self):
        report = f"Signer #1 certificate SHA-256 digest: {SHA}\n"
        self.assertEqual(verify_report(report, SHA.upper()), {SHA})

    def test_sdk_range_signer(self):
        report = f"Signer (minSdkVersion=24, maxSdkVersion=32) certificate SHA-256 digest: {SHA}\n"
        self.assertEqual(verify_report(report, ":".join(SHA[i:i+2] for i in range(0, 64, 2))), {SHA})

    def test_multiple_sdk_range_signers_same_certificate(self):
        report = (
            f"Signer (minSdkVersion=24, maxSdkVersion=32) certificate SHA-256 digest: {SHA}\n"
            f"Signer (minSdkVersion=33, maxSdkVersion=36) certificate SHA-256 digest: {SHA}\n"
        )
        self.assertEqual(verify_report(report, SHA), {SHA})

    def test_wrong_signer_rejected(self):
        report = f"Signer #1 certificate SHA-256 digest: {OTHER}\n"
        with self.assertRaisesRegex(ValueError, "APK_SIGNING_CERT_MISMATCH"):
            verify_report(report, SHA)

    def test_mixed_signers_rejected(self):
        report = (
            f"Signer #1 certificate SHA-256 digest: {SHA}\n"
            f"Signer #2 certificate SHA-256 digest: {OTHER}\n"
        )
        with self.assertRaisesRegex(ValueError, "APK_SIGNING_CERT_MISMATCH"):
            verify_report(report, SHA)

    def test_missing_cert_sha_rejected(self):
        with self.assertRaisesRegex(ValueError, "APK_CERT_SHA256_NOT_FOUND"):
            verify_report("Signer #1 public key SHA-256 digest: " + SHA, SHA)

    def test_bad_expected_rejected(self):
        with self.assertRaisesRegex(ValueError, "EXPECTED_FINGERPRINT_INVALID"):
            verify_report("Signer #1 certificate SHA-256 digest: " + SHA, "bad")


if __name__ == "__main__":
    unittest.main()
