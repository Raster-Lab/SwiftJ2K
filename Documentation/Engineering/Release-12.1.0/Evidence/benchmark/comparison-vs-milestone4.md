| Case | Direction | Milestone 4 median ms | Release median ms | Δ median | Codestream bytes |
| --- | --- | --- | --- | --- | --- |
| g10_300x200_gradient | decode | 18.8 (p95 19.2) | 14.9 (p95 15.3) | -20.7% | 25285 → 25285 |
| g10_300x200_gradient | encode | 16.2 (p95 16.7) | 12.5 (p95 13.0) | -22.8% | 25285 → 25285 |
| g12_129x67_gradient | decode | 15.2 (p95 15.8) | 5.9 (p95 6.1) | -61.4% | 3609 → 3609 |
| g12_129x67_gradient | encode | 15.0 (p95 19.6) | 5.5 (p95 5.8) | -63.7% | 3609 → 3609 |
| g16_256x256_smooth | decode | 32.5 (p95 42.9) | 18.0 (p95 18.7) | -44.7% | 64367 → 64367 |
| g16_256x256_smooth | encode | 25.5 (p95 31.4) | 14.6 (p95 15.3) | -42.7% | 64367 → 64367 |
| g16_64x64_random | decode | 14.8 (p95 15.6) | 5.3 (p95 5.6) | -64.0% | 8988 → 8988 |
| g16_64x64_random | encode | 9.2 (p95 10.0) | 5.2 (p95 5.5) | -43.4% | 8988 → 8988 |

worst median change: +0.0% (gate: investigate above +5%)
codestream sizes changed: none
binary sha256 baseline e369f9ccf8a26239 release 0f0deafdbbc2eebe
