# `BEDaisy.sys` (BattlEye) kernel fault at `+0x1720619` — in the minifilter unload path

**Status:** reproduced **5×** · mechanism identified · **independent of Memory Integrity / HVCI**
**Driver:** `BEDaisy.sys` — 39,096,056 bytes — SHA-256 `184F28E4AC5C178AE05078F57AB54F3F3AE9864BC2FEA8CE20CB62AB8F3ECB7A` — valid WHQL
**Host:** Windows 11 Pro for Workstations 26H2, build 26300.9550
**Games observed:** Rainbow Six Siege (Steam), via BattlEye

---

> ### Correction to the earlier version of this repository
>
> This repo previously reported the fault as an **HVCI / Memory Integrity incompatibility**, on the
> basis of 3 crashes with HVCI enabled and none with it disabled.
>
> **That conclusion was wrong and has been withdrawn.** The fault was subsequently reproduced
> **with Memory Integrity completely disabled**, producing a byte-identical crash stack. The
> original 3-vs-0 split was coincidence: the HVCI-disabled runs simply never coincided with a
> BattlEye anticheat update, which is the actual trigger. Details in
> [Crash 5](#crash-5--hvci-disabled-decisive) below.

---

## Summary

`BEDaisy.sys` — BattlEye's kernel anti-cheat **minifilter driver** — faults inside its own
**`FilterUnloadCallback`** when the driver is unloaded, producing a
**`0x7E` SYSTEM_THREAD_EXCEPTION_NOT_HANDLED** bugcheck.

The unload is driven by **BattlEye's own anticheat updater**: when an anticheat update is
required, the game closes so the update can apply, the driver unloads, and its unload routine
dereferences freed memory.

Five of five observed crashes are identical in every respect except addresses.

---

## The defect

```
BUGCHECK_CODE:           7e   (SYSTEM_THREAD_EXCEPTION_NOT_HANDLED)
BUGCHECK_P1:             ffffffffc0000005   (STATUS_ACCESS_VIOLATION)
ExceptionCode:           c0000005 (Access violation)
PROCESS_NAME:            System
AV.Type:                  Read
Faulting.IP.Type:        Paged
MODULE_NAME:             BEDaisy
IMAGE_NAME:              BEDaisy.sys
SYMBOL_NAME:             BEDaisy+1720619
BUCKET_ID_FUNC_OFFSET:   1720619
FAILURE_BUCKET_ID:       AV_BEDaisy!unknown_function
```

Faulting instruction, byte-identical every time:

```
66448b5d00      mov     r11w,word ptr [rbp] ss:0018:0000001b`00000001=????
```

The driver dereferences `rbp` as a pointer. In every crash `rbp` holds a **garbage value whose
low dword is `0x00000001`** — a consistent corruption signature, not a random bit-flip. The
faulting code sits in a **paged** section of the driver.

## The stack — identical in every crash

`FLTMGR!FltpDoUnloadFilter` invokes a minifilter's unload callback. The callback it is invoking
is `BEDaisy+0x97a4` — BattlEye's `FilterUnloadCallback`. It then faults deeper in.

```
BEDaisy+0x1720619                     <-- fault (paged)
BEDaisy+0x12e21
BEDaisy+0x1c5ba2
BEDaisy+0x97a4                        <-- FilterUnloadCallback
FLTMGR!FltpDoUnloadFilter+0xa3
FLTMGR!FltpMiniFilterDriverUnload+0x194
nt!IopLoadUnloadDriver+0x120
nt!ExpWorkerThread+0x29f
nt!PspSystemThreadStartup+0x5a
nt!KiStartSystemThread+0x34
```

A garbage pointer read inside an unload routine is the classic signature of a
**use-after-free / stale pointer**. The fault is in the `System` process, in kernel mode.

## The trigger

> **BattlEye's anticheat self-update forces the game to close → `BEDaisy.sys` unloads → its
> unload callback dereferences freed memory → `0x7E`.**

Observed directly: Siege displayed *"an anticheat update was required and it would self-restart"*,
the game closed, and the machine bugchecked immediately afterwards (5 seconds after the last
30-second health sample).

At the instant of the fault, a **Windows Installer operation was in flight** — the dumps show
`TrustedInstaller.exe`, `msiexec.exe` and `ax_installer.exe` live alongside `RainbowSix.exe`,
`BEService.exe` and the Ubisoft Connect stack.

**Honest caveat:** the game also closed and unloaded `BEDaisy` several times during this
investigation **without** crashing. Unloading alone is therefore *not* sufficient — the fault
appears to require the unload to coincide with installer-driven kernel filter churn. This is the
one part of the picture that is inferred rather than directly demonstrated.

## Crash 5 — HVCI disabled (decisive)

The fault reproduces with **Memory Integrity switched off**, producing the identical stack:

| check | state at crash 5 |
| :--- | :--- |
| `SecurityServicesConfigured` | `{0}` |
| `SecurityServicesRunning` | `{0}` |
| `HKLM\…\HypervisorEnforcedCodeIntegrity\Enabled` | `0` |
| Health sampler, every 30 s from 09:10:49 to 09:13:51 | `hvciRunning = False` (all samples) |
| `BEDaisy` state, final two samples | `Running` |
| Bugcheck | 5 seconds after the final sample |

**HVCI is not the cause.** There is nothing about this defect that a user can work around by
disabling a security feature.

---

## Crash data

All five crashes, identical except addresses:

| # | time (local) | HVCI | fault address | `rbp` | offset |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | 2026-09-30 18:24 | on | `fffff80540a10619` | `0x0000001100000001` | `+0x1720619` |
| 2 | 2026-09-30 18:38 | on | `fffff8052daa0619` | `0x0000000F00000001` | `+0x1720619` |
| 3 | 2026-09-30 19:47 | on | `fffff80569340619` | `0x0000001B00000001` | `+0x1720619` |
| 4 | 2026-10-01 08:49 | on | `fffff80744ee0619` | `0x0000001300000001` | `+0x1720619` |
| 5 | 2026-10-01 09:13 | **off** | `fffff80088bb0619` | — | `+0x1720619` |

Extracts of the crash-4 and crash-5 analyses are in [`analysis/`](analysis/), including full
stacks and the process snapshots showing the installer activity.
`!analyze -v` output for crashes 1–3 is also there.

### On the `…0619` suffix

BEDaisy's base address is 64 KB-aligned and the offset `0x1720619` has low 16 bits `0x0619`, so
**every** fault address from this defect ends in `0619`. If your crash address ends that way and
the module is `BEDaisy`, it is very likely this same defect. Address arithmetic:

```
crash 5:  0xfffff80088bb0619 − 0x1720619 = 0xfffff80087490000   (64 KB aligned ✓)
crash 4:  0xfffff80744ee0619 − 0x1720619 = 0xfffff807437c0000   (64 KB aligned ✓)
```

---

## What this is not

- **Not file corruption.** `BEDaisy.sys` was deleted and re-obtained through BattlEye's own
  update mechanism. The replacement was **byte-identical** — same size, same SHA-256.
- **Not an HVCI compatibility issue.** Proven wrong; see crash 5.
- **Not a hardware fault.** No `WHEA-Logger` events, no display-driver resets.
- **Not fixed by a reinstall.** See above; and BattlEye redeploys the driver on every launch.

## Reproduction

1. Rainbow Six Siege (Steam) installed, with BattlEye.
2. Launch the game so `BEDaisy.sys` loads.
3. Allow / wait for a BattlEye anticheat update prompt.
4. Let the game close so the update can apply.
5. → bugcheck `0x7E`, `BEDaisy+0x1720619`, within seconds. **No HVCI requirement.**

## What has *not* been tested

Stated so the evidence can be weighed properly:

- **One machine, one configuration.** A single host. Reproducible here, not claimed to be
  fleet-wide.
- **The installer-concurrency requirement is inferred**, not demonstrated — see the caveat above.
- **HP Wolf Security** is installed and its kernel drivers were never modified. Its minifilters
  (`vlflt`, `Gemma`, `atc`, `BdDci4`) were observed loading and unloading during the crash period
  but were not isolated.
- Crash times for 9/30 are taken from recovery-boot event-log markers; 10/1 times are confirmed
  by a 30-second health sampler.

## Raw dumps are not published

See [DUMPS.md](DUMPS.md). Kernel memory dumps contain sensitive memory contents and are
deliberately withheld. Everything needed to identify the fault — signature, stack, hashes — is in
[`analysis/`](analysis/). Dumps can be supplied privately to BattlEye if they want them.

## Corroboration welcome

If you hit the same bugcheck — `0x7E`, `BEDaisy+0x1720619`, `AV_BEDaisy!unknown_function` —
please open an issue with your `!analyze -v` output, your `BEDaisy.sys` SHA-256
(`check-affected.ps1` collects this, read-only, no username or machine name), and your Windows
build. **Independent reproductions on other hardware are the fastest way to get this in front of
the right people.**
