# Attribution and redistribution boundary

This project builds on the capture-worker design and patch engine by
`chen0416ccc-cpu/codex-windows-fast-patch-skill` and its contributors:

https://github.com/chen0416ccc-cpu/codex-windows-fast-patch-skill

Pinned upstream commit: `f29051c2c351eae707c87553509791a6f35b4bfe`.
Reference file: `scripts/patch-computer-use-helper-win10.ps1`.
Its download SHA-256 is recorded in `profile.json`.

At the time of review (2026-10-31), upstream did not declare an open-source
license. This repository therefore does not copy or relicense its patcher,
test suite, or worker machine code. The original adapter obtains that dependency
from the original public location and verifies the pinned bytes before use.
Availability at a public URL does not grant blanket redistribution rights.

Our contribution: exact 0.7.13 input/output binding, independently inspected
compatibility evidence, a standalone adapter, fixture lifecycle tests, and
documentation of local screenshot results and their limits.

The MIT license applies to the original files in this repository only.
OpenAI executables and third-party dependencies retain their respective rights.
No official or modified OpenAI executable is included or licensed here.
No affiliation with or endorsement by OpenAI or the upstream maintainer is implied.
