# Validation record — 2026-10-31

## Inspected target

Windows 10 22H2 build 19045; Desktop 26.1027.3384.0; Sky 0.7.13.
The exact complete input/output digests are in `profile.json`.

The local adaptation was first developed and deployed on a local branch of the
upstream project. This repository packages an independent adapter that must
produce the same complete output hash; it is not a new worker implementation.

## Static checks

- PE machine AMD64; original size 1,551,152 bytes; 10 original sections.
- Callback RVA `0x42489`, normal return `0x45601`. Entry does not depend on
  incoming event arguments RDX/R8; subsequent values are loaded from the closure.
- IAT RVAs: CreateThread `0x177018`, CloseHandle `0x176fd8`, RoInitialize
  `0x176f30`, RoUninitialize `0x176f38`.
- Thirteen patch-region guards inspected; eleven matched the upstream reference.
  The checksum and certificate-overlay guards were rebound to this exact input.
  This does not establish whole-binary equivalence between Sky versions.
- Candidate changes 551 bytes. Full candidate hash verified.
- Upstream isolated native unwind test passed 47 instruction boundaries and
  ten live caller frames. It substitutes API/COM stubs and does not run the real
  capture callback; this is ABI/unwind evidence, not screenshot evidence.
- Upstream fixture install, idempotence, backup integrity, rollback/idempotence
  and unknown-input refusal passed before live deployment.

## Runtime observations from the deployed identical candidate

The standalone `Test-Fix.ps1` was also run successfully on the same Windows 10
host before publication. It reconstructed the exact candidate and passed offline
status/no-cache, original preservation, fixture install/idempotence, backup hash,
rollback/idempotence and unknown-input refusal checks. It did not modify the live
helper or rerun screenshots; runtime observations below concern the identical
candidate already deployed through the upstream development branch.

| Test | Result |
|---|---|
| Original blank Notepad | No image, timeout after 5278ms |
| Patched foreground Notepad | Correct image, 108ms |
| Dynamic owned test window, three inspected captures | 93/94/97ms; frame counters and clock changed |
| Ten additional requests | All returned an image; 87/83/99/90/93/88/86/84/110/116ms; final image inspected |
| Fresh helper after observed old-process exits | Correct dynamic image, 202ms |
| Main helper short resource sample | Threads/handles 76/1010 → 75/1001; working set 111640576 → 112017408 bytes |

The tests used the documented native Computer Use API. No input actions were
performed. A static image return or successful function call alone was not counted
as target-content verification.

## Known limits

The first occluded Notepad capture displayed occluding content. It was excluded
from successful target-capture acceptance. Activate the target and inspect its
image before any later authorized use.

No full Windows/Desktop reboot, sleep/resume, prolonged resource soak, broad GPU
coverage or input-action acceptance was performed. The original deadlock was not
dynamically proven on this host. Upstream RoInitialize-error and timeout/cancel
resource lifetime behavior remains unverified. This is an experimental local
compatibility fix, not a universal or officially signed correction.
