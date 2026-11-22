#!/usr/bin/env python3
"""Fail-closed ABI + size policy for ARM64-only Gallery Drift APKs."""
import argparse
from pathlib import Path
from zipfile import ZipFile

REQUIRED_NATIVE = frozenset({
    "lib/arm64-v8a/libflutter.so",
    "lib/arm64-v8a/libapp.so",
    "lib/arm64-v8a/libmlkitcommonpipeline.so",
})
ALLOWED_ABI = "arm64-v8a"

def verify_apk(path: Path, max_mib: float = 36.0) -> dict[str, object]:
    if not path.is_file():
        raise ValueError("APK_MISSING: " + str(path))
    size = path.stat().st_size
    if size <= 0 or size > max_mib * 1024 * 1024:
        raise ValueError(f"APK_SIZE_BUDGET_FAIL: {size / (1024 * 1024):.2f} MiB exceeds {max_mib:.2f} MiB budget")
    with ZipFile(path) as archive:
        names = archive.namelist()
        paths = set(names)
        foreign_abis = set()
        abi_sizes: dict[str, int] = {}
        for name in names:
            if not name.startswith("lib/") or name.endswith("/"):
                continue
            bits = name.split("/")
            if len(bits) < 3:
                raise ValueError(f"APK_NATIVE_LIB_BAD_PATH: {name}")
            abi = bits[1]
            abi_sizes[abi] = abi_sizes.get(abi, 0) + archive.getinfo(name).file_size
            if abi != ALLOWED_ABI:
                foreign_abis.add(abi)
        if foreign_abis:
            raise ValueError("APK_FOREIGN_ABI_FAIL: " + ", ".join(sorted(foreign_abis)))
        missing = REQUIRED_NATIVE - paths
        if missing:
            raise ValueError("APK_REQUIRED_LIBRARY_MISSING: " + ", ".join(sorted(missing)))
        if len(names) != len(paths):
            raise ValueError("APK_DUPLICATE_ZIP_PATH: duplicate APK archive path")
    print(f"ARM64_ONLY_APK_VERIFIED size={size / (1024 * 1024):.2f}MiB native_abis={','.join(sorted(abi_sizes))}")
    return {"size_bytes": size, "abis": frozenset(abi_sizes)}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--max-mib", type=float, default=36.0)
    args = parser.parse_args()
    verify_apk(args.apk, args.max_mib)
