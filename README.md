# Independent replication of the mechanical checks on Levent Alpöge's Lean proof of the Riemann Hypothesis

On 2026-11-20, Levent Alpöge released a Lean 4 project that claims a proof of the Riemann Hypothesis and of the Generalized Riemann Hypothesis for Dirichlet L-functions. The proof exists only as Lean code: 175,187 .lean source files, about 17.4 million lines. All credit for the proof belongs to Levent Alpöge.

This repository records my independent replication of the mechanical checks on a home desktop PC. I did not review the mathematics. I checked that the code compiles, that it states what it claims, and that it depends only on Lean's standard axioms.

The proof itself is not included here. Download it from the original source (see Links).

## Result

| Check | Result |
|---|---|
| Archive is the original | `lean.tar.gz` (239,275,554 bytes) has SHA-256 `9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc`, which matches the hash published by Andrew Sutherland (MIT) |
| Statements say what they claim | `riemannHypothesis : RiemannHypothesis` uses Mathlib's own definition. The four L-function statements in `src/Statements.lean` (16 lines) read correctly |
| No shortcuts in the source | No `sorry`, `native_decide`, `implemented_by` or `@[extern]`, no `debug.skipKernelTC` or `unsafe`, no `set_option` touching kernel checking, and the word `axiom` appears nowhere in `src` (whole-word search, 0 matches) |
| Every proof step checked | `lake build`: 183,903 jobs, 0 errors |
| Sources untouched | All 175,187 .lean source file hashes taken before the build still match after it |
| Only standard axioms | All five theorems in `Main.lean` depend only on `propext`, `Classical.choice`, `Quot.sound` (see `logs/axioms.log`) |

```text
'riemannHypothesis' depends on axioms: [propext, Classical.choice, Quot.sound]
'riemannZeta_eq_zero_re' depends on axioms: [propext, Classical.choice, Quot.sound]
'LFunction_ne_zero_of_half_lt_re' depends on axioms: [propext, Classical.choice, Quot.sound]
'LFunction_eq_zero_re' depends on axioms: [propext, Classical.choice, Quot.sound]
'LFunction_eq_zero_re_of_isPrimitive' depends on axioms: [propext, Classical.choice, Quot.sound]
def RiemannHypothesis : Prop :=
∀ (s : ℂ), riemannZeta s = 0 → (¬∃ n, s = -2 * (↑n + 1)) → s ≠ 1 → s.re = 1 / 2
```

### What this does not establish

- **No second kernel.** Sutherland also checked the proof with nanoda, an independently written checker. That needs about 100 GB of RAM, more than this machine has. My result relies on Lean's kernel being correct.
- **Mathlib's definitions are trusted.** The check assumes `riemannZeta` and `DirichletCharacter.LFunction` in Mathlib are the real objects.
- **Mathlib was not compiled locally.** Mathlib's compiled files came from Mathlib's official cache (`lake exe cache get`) rather than being compiled locally. The project's own 175,187 files were all compiled on this machine.
- **No mathematical understanding.** A kernel-checked proof shows the statement follows from Lean's axioms, assuming the kernel and Mathlib's definitions are correct. It does not explain why.

## Machine

- Intel Core i9-14900K (24 cores, 32 threads), 64 GB RAM, 1.6 TB NVMe
- Windows 11 with WSL2 (Ubuntu 26.04)
- Lean v4.33.1, Mathlib at commit `0df444a360eaa60ab8c11dca51a86af692955474` (both pinned by the project)

Timeline: about 31 hours of actual building, 38 hours from first start to finish including a crash and restarts. The last five files took about an hour each.

## How to reproduce

All commands run inside WSL, in the Linux home folder (not under `/mnt/c`, which is much slower for 175k files).

### 1. Prepare WSL

`C:\Users\<you>\.wslconfig`:

```ini
[wsl2]
memory=56GB
processors=32
swap=64GB
```

(for a 64 GB machine: leave Windows about 8 GB)

Then `wsl --shutdown` and reopen Ubuntu. Install tools:

```bash
sudo apt update && sudo apt install -y git curl tmux zstd htop
```

Make sure the Windows drive that holds the WSL virtual disk has plenty of free space (see Lessons, point 1). Disable sleep and schedule Windows Update restarts for after the build.

### 2. Download and verify the original archive

```bash
mkdir -p ~/rh && cd ~/rh
git clone https://github.com/Yzemzgui/riemann-lean-check.git ~/rh/riemann-lean-check
for i in $(seq -w 1 14); do curl -fLO https://alpo.ge/lean.tar.gz.part$i; done
cat lean.tar.gz.part{01..14} > lean.tar.gz
echo "9631b4f020199e580ba86178cb56c6e9b09f690c2369a80dc4334aa93f49c7fc  lean.tar.gz" | sha256sum -c
tar -xzf lean.tar.gz && cd lean
cat lean-toolchain        # leanprover/lean4:v4.33.1
```

### 3. Fingerprint the sources

```bash
cd ~/rh/lean
find src -type f -name '*.lean' -print0 | xargs -0 sha256sum > ~/rh/src.sha256
wc -l ~/rh/src.sha256     # 175187
```

### 4. Read the statements

```bash
cd ~/rh/lean
cat src/Main.lean src/Statements.lean
```

### 5. Scan for shortcuts

```bash
cd ~/rh/lean
grep -rnE '\bsorry\b|native_decide|implemented_by|@\[extern' src | head
grep -rnw 'axiom' src | head
grep -rnw 'skipKernelTC' src | head
grep -rnw 'unsafe' src | head
grep -rhoE 'set_option [A-Za-z_.]+' src | sort -u | grep -iE 'debug|kernel|trust'
grep -rnE "(def|abbrev|theorem|structure|class|inductive|opaque|axiom)\s+([A-Za-z_.]*\.)?RiemannHypothesis\b" src
```

All six should print nothing.

### 6. Build

```bash
cd ~/rh/lean
curl https://elan.lean-lang.org/elan-init.sh -sSf | sh -s -- -y
source ~/.elan/env
lake exe cache get        # prebuilt Mathlib for the pinned commit
```

Start a tmux session with `tmux new -s rh`, and inside it run:

```bash
cd ~/rh/lean
lake build 2>&1 | tee -a ~/rh/build.log
```

Once the build is running, start the cleanup loop in a second tmux session (see Lessons, point 1):

```bash
bash ~/rh/riemann-lean-check/scripts/cleanup-setup-json.sh
```

To check on the build:

```bash
grep -o '\[[0-9]*/[0-9]*\]' ~/rh/build.log | tail -1   # progress
grep -c "error:" ~/rh/build.log                        # should stay 0
tail -3 ~/rh/build.log                                 # ends with "Build completed successfully"
```

Watch `vmstat 5`. If `wa` (waiting on disk) stays above about 20% near the end, stop with `Ctrl+C` and restart with fewer parallel jobs:

```bash
LEAN_NUM_THREADS=16 lake build 2>&1 | tee -a ~/rh/build.log
```

Finished modules are kept. Only the ones in progress are redone.

### 7. Final checks

```bash
cd ~/rh/lean
sha256sum -c --quiet ~/rh/src.sha256 && echo "ALL 175187 FILES UNCHANGED"
lake env lean ~/rh/riemann-lean-check/CheckAxioms.lean 2>&1 | tee ~/rh/axioms.log
```

`CheckAxioms.lean` is in this repository. Running it takes about an hour, because `import Main` loads almost the whole project.

## Lessons learned

1. **Lake's per-module setup files can dwarf the build itself.** Compiled proofs (`.olean`) were about 65 GB, but Lake also wrote a `*.setup.json` file per module listing the paths of every transitive import, about 6 MB each. That added up to roughly 700 GB and filled my C: drive at 71% of the build, which crashed WSL. A test on one finished module showed Lake does not need these files after the module is compiled, so a loop that deletes setup files older than 10 minutes keeps disk usage flat (around 110 GB). The WSL virtual disk does not shrink by itself: after deleting, run `sudo fstrim -v /`, then `compact vdisk` with `diskpart`.
2. **Watch the Windows drive, not `df`.** `df` inside WSL showed about 950 GB available, which is only the virtual disk's ceiling. The real limit is the Windows drive. When WSL crashed, its own logs were wiped, but the Windows event log showed other programs failing with write errors at the same moment, which pointed to a full disk.
3. **Lowering WSL memory made things worse.** At 47 GB the build thrashed between swap and file cache (`us` 2%, `wa` 80%). 56 GB had run 13 hours with almost no swap, so going back fixed it.
4. **Fewer jobs can be much faster.** In the heaviest final stretch, 32 parallel modules needed more imported files than fit in the file cache, and Linux re-read them from disk at about 1 GB/s. Restarting with `LEAN_NUM_THREADS=16` took the build from about 9 to about 100 jobs per minute.
5. **The tail is long and disk-bound.** The top-level files import almost everything. One of them read about 1.2 TB from disk in 25 minutes, re-reading roughly 65 GB of compiled files many times. More RAM is the only real fix.
6. **Restarts are cheap.** Lake skips everything already built, so stopping and restarting costs only the files in progress. That made it safe to fix problems mid-build.

## Files

| File | Content |
|---|---|
| `CheckAxioms.lean` | The axiom check run against the built project |
| `scripts/cleanup-setup-json.sh` | Loop that deletes Lake setup files older than 10 minutes (modules that have already started compiling) |
| `logs/axioms.log` | Output of the axiom check |
| `logs/build.log.gz` | Full build log (564 MB uncompressed), across all runs. Warnings repeat because Lake replays the messages of modules built in earlier runs, and the 42 `.trace: unexpected end of input` warnings come from trace files cut off by the crash, all of whose modules Lake then rebuilt |
| `logs/src.sha256.gz` | SHA-256 of every .lean source file, taken before the build |

## Links

- Alpöge's note: https://alpo.ge/remark.pdf
- Original archive: `https://alpo.ge/lean.tar.gz.part01` to `part14`
- Andrew Sutherland's verification files and hashes: https://math.mit.edu/~drew/grh/
- Another independent build: https://github.com/Hertaspace/alpoge-rh-lean-verification

All credit for the proof belongs to Levent Alpöge (working with Claude). I used Claude as a guide while running these checks.
