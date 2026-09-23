| Case | Direction | Baseline median ms | Release median ms | Δ median | Codestream bytes |
| --- | --- | --- | --- | --- | --- |
| g10_300x200_gradient | decode | 14.9 (p95 15.3) | 14.5 (p95 15.2) | -3.0% | 25285 → 25285 |
| g10_300x200_gradient | encode | 12.5 (p95 13.0) | 11.6 (p95 12.0) | -7.4% | 25285 → 25285 |
| g12_129x67_gradient | decode | 5.9 (p95 6.1) | 5.6 (p95 5.6) | -4.7% | 3609 → 3609 |
| g12_129x67_gradient | encode | 5.5 (p95 5.8) | 5.0 (p95 5.4) | -7.6% | 3609 → 3609 |
| g16_256x256_smooth | decode | 18.0 (p95 18.7) | 17.3 (p95 18.1) | -4.2% | 64367 → 64367 |
| g16_256x256_smooth | encode | 14.6 (p95 15.3) | 13.9 (p95 14.4) | -5.0% | 64367 → 64367 |
| g16_64x64_random | decode | 5.3 (p95 5.6) | 5.2 (p95 5.5) | -3.3% | 8988 → 8988 |
| g16_64x64_random | encode | 5.2 (p95 5.5) | 4.9 (p95 5.1) | -6.2% | 8988 → 8988 |

worst median change: -3.0% (gate: investigate above +5%)
codestream sizes changed: none
binary sha256 baseline 0f0deafdbbc2eebe release 144b410bdc3ca556
