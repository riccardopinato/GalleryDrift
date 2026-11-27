"""Update GalleryDrift's pinned Dart Git dependency to latest Art Drift main Drift Core change.

This script never edits Dart sources or updates main directly. It edits the
dependency pin and provenance document for a separate CI-gated PR.
"""
from __future__ import annotations
import json
import re
import urllib.request
from pathlib import Path

API = ("https://api.github.com/repos/riccardopinato/"
       "ArtDrift-Infinite-Art-Gallery/commits?path=packages%2Fdrift_core&per_page=1")
PUB = Path("pubspec.yaml")
DOC = Path("docs/DRIFT_CORE_CONSUMER.md")


def latest_core_commit() -> str:
    request = urllib.request.Request(API, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "GalleryDrift-core-sync/1",
        "X-GitHub-Api-Version": "2022-11-28",
    })
    with urllib.request.urlopen(request, timeout=20) as response:
        data = json.load(response)
    if not isinstance(data, list) or not data:
        raise RuntimeError("No Drift Core commits found on source default branch")
    sha = data[0].get("sha", "")
    if not re.fullmatch(r"[a-f0-9]{40}", sha):
        raise RuntimeError("Invalid Drift Core source commit SHA")
    return sha


def update_pin(new_sha: str) -> bool:
    source = PUB.read_text(encoding="utf-8")
    match = re.search(
        r"(?ms)(^  drift_core:\n    git:\n"
        r"      url: https://github\.com/riccardopinato/ArtDrift-Infinite-Art-Gallery\.git\n"
        r"      ref: )([a-f0-9]{40})(\n"
        r"      path: packages/drift_core\n)",
        source,
    )
    if not match:
        raise RuntimeError("GalleryDrift pinned core dependency contract changed")
    previous = match.group(2)
    if previous == new_sha:
        print("DRIFT_CORE_NO_CHANGE", new_sha)
        return False
    new_content = source[:match.start(2)] + new_sha + source[match.end(2):]
    provenance = DOC.read_text(encoding="utf-8")
    current_pin_line = f"Pinned core source commit: {previous}"
    if current_pin_line not in provenance:
        raise RuntimeError("Provenance document no longer matches the pinned SHA")
    PUB.write_text(new_content, encoding="utf-8")
    # Replace only the live pin, never immutable historical commit references.
    DOC.write_text(provenance.replace(current_pin_line,
        f"Pinned core source commit: {new_sha}", 1), encoding="utf-8")
    print("DRIFT_CORE_NEW_PIN", previous, "->", new_sha)
    return True


if __name__ == "__main__":
    update_pin(latest_core_commit())
