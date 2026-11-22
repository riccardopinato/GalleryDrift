"""Regression tests for machine-readable signed APK X.509 certificate checking."""
import hashlib
import ssl
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_release_apk import verify_report

DER1 = b"\x30\x03\x02\x01\x01"
DER2 = b"\x30\x03\x02\x01\x02"
PEM1 = ssl.DER_cert_to_PEM_cert(DER1)
PEM2 = ssl.DER_cert_to_PEM_cert(DER2)
SHA1 = hashlib.sha256(DER1).hexdigest()
SHA2 = hashlib.sha256(DER2).hexdigest()


class ApkCertificateParsingTests(unittest.TestCase):
    def test_production_workflow_cli_parameters_not_escaped(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / ".github/workflows/release-signed.yml").read_text(encoding="utf-8")
        command = next(
            (line.strip() for line in workflow.splitlines()
             if line.lstrip().startswith("python3 scripts/verify_release_apk.py")),
            "",
        )
        self.assertTrue(command, "APK verification command missing")
        self.assertIn('--apk "$APK"', command)
        self.assertIn('--apksigner "$SDK_BUILD_TOOLS/apksigner"', command)
        self.assertIn('--expected "$ANDROID_CERT_SHA256"', command)
        self.assertIn('--report build/apk-signer-report.txt', command)
        self.assertNotIn("\\", command)

    def test_pem_with_numbered_signer(self):
        output = f"Signer #1 certificate SHA-256 digest: {SHA1}\n{PEM1}"
        self.assertEqual(verify_report(output, SHA1.upper()), {SHA1})

    def test_pem_with_sdk_range_signer(self):
        output = f"Signer (minSdkVersion=24, maxSdkVersion=36) cert info\n{PEM1}"
        expected = ":".join(SHA1[i:i + 2] for i in range(0, 64, 2))
        self.assertEqual(verify_report(output, expected), {SHA1})

    def test_repeated_same_certificate(self):
        self.assertEqual(verify_report(PEM1 + "\n" + PEM1, SHA1), {SHA1})

    def test_different_certificates_rejected(self):
        with self.assertRaisesRegex(ValueError, "APK_SIGNING_CERT_MISMATCH"):
            verify_report(PEM1 + "\n" + PEM2, SHA1)

    def test_wrong_certificate_rejected(self):
        with self.assertRaisesRegex(ValueError, "APK_SIGNING_CERT_MISMATCH"):
            verify_report(PEM1, SHA2)

    def test_report_without_pem_rejected(self):
        with self.assertRaisesRegex(ValueError, "APK_CERT_PEM_NOT_FOUND"):
            verify_report("Signer #1 certificate SHA-256 digest: " + SHA1, SHA1)

    def test_invalid_expected_fingerprint(self):
        with self.assertRaisesRegex(ValueError, "EXPECTED_FINGERPRINT_INVALID"):
            verify_report(PEM1, "wrong")

    def test_malformed_pem_rejected(self):
        invalid = "-----BEGIN CERTIFICATE-----\n@@@\n-----END CERTIFICATE-----"
        with self.assertRaisesRegex(ValueError, "APK_CERT_PEM_NOT_FOUND"):
            verify_report(invalid, SHA1)


if __name__ == "__main__":
    unittest.main()
