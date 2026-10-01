# Kernel fault in `BEDaisy.sys` (BattlEye) when Memory Integrity (HVCI) is enabled

**Status:** reproducible · awaiting vendor response
**Affects:** Rainbow Six Siege (Steam) + BattlEye · `BEDaisy.sys` SHA-256 `184F28E4AC5C178AE05078F57AB54F3F3AE9864BC2FEA8CE20CB62AB8F3ECB7A`
**Host:** Windows 11 Pro for Workstations 26H2, build 26300.9550
**Date observed:** 2026-09-30

---

## Summary

When **Memory Integrity (HVCI)** is enabled, launching Rainbow Six Siege produces a
**`0x7E` SYSTEM_THREAD_EXCEPTION_NOT_HANDLED** bugcheck in **`BEDaisy.sys`** — BattlEye's
kernel anti-cheat driver — within roughly **2 minutes 20 seconds** of launch.

With HVCI disabled, the **byte-identical** driver loads and the game runs normally.

Three of three attempts with HVCI enabled produced the same fault, at the same offset,
executing the same instruction. Two of two attempts with HVCI disabled produced no fault.

---

## Environment

| | |
| :--- | :--- |
| OS | Windows 11 Pro for Workstations, 26H2, build 26300.9550 |
| Base build lab | `26100.1.amd64fre.ge_release.240331-1435` |
| Insider programme | **not enrolled** — public release build |
| CPU / RAM | Intel Xeon W-2155 / 64 GB |
| GPU | NVIDIA RTX 3060 (12 GB) + GTX 1650 (4 GB) |
| HVCI at time of fault | **enabled** — `SecurityServicesConfigured` / `SecurityServicesRunning` = `{2}` |
| Other software | Hyper-V present (Docker Desktop + WSL2); HP Wolf Security installed |
| Dump flag | `Hypervisor.RootFlags.IsHyperV: 1` |

---

## Steps to reproduce

1. Enable **Memory Integrity** — Windows Security → Device security → Core isolation details.
2. Reboot.
3. Launch **Rainbow Six Siege** (Steam). BattlEye deploys `BEDaisy.sys` at launch.
4. The system bugchecks within approximately 2m 20s.
5. Disable Memory Integrity, reboot, launch again — no fault.

---

## Technical detail

Driver: `C:\Program Files (x86)\Common Files\BattlEye\BEDaisy.sys`

| property | value |
| :--- | :--- |
| Size | 39,096,056 bytes |
| SHA-256 | `184F28E4AC5C178AE05078F57AB54F3F3AE9864BC2FEA8CE20CB62AB8F3ECB7A` |
| Signature | valid WHQL — *Microsoft Windows Hardware Compatibility Publisher* |
| Redeployed | on **every** game launch |

```
BUGCHECK_CODE:           7e   (SYSTEM_THREAD_EXCEPTION_NOT_HANDLED)
BUGCHECK_P1:             ffffffffc0000005   (STATUS_ACCESS_VIOLATION)
ExceptionCode:           c0000005 (Access violation)
PROCESS_NAME:            System
AV.Type:                 Read
Faulting.IP.Type:        Paged
MODULE_NAME:             BEDaisy
IMAGE_NAME:              BEDaisy.sys
SYMBOL_NAME:             BEDaisy+1720619
BUCKET_ID_FUNC_OFFSET:   1720619
FAILURE_BUCKET_ID:       AV_BEDaisy!unknown_function
```

Faulting instruction:

```
fffff805`69340619 66448b5d00      mov     r11w,word ptr [rbp] ss:0018:0000001b`00000001=????
```

The driver dereferences `rbp` as a pointer. In every crash `rbp` holds a garbage value whose
low dword is `0x00000001`, and the read targets an unmapped address. The faulting code sits in
a **paged** section of the driver. Call-stack return address observed: `BEDaisy+0x3783`.

---

## Crash data

Three crashes, three dumps. Identical in every respect except addresses.

| # | time (local) | fault address | `rbp` value | offset in BEDaisy |
| :--- | :--- | :--- | :--- | :--- |
| 1 | ~18:24 | `fffff80540a10619` | `0x0000001100000001` | `+0x1720619` |
| 2 | ~18:38 | `fffff8052daa0619` | `0x0000000F00000001` | `+0x1720619` |
| 3 | ~19:46 | `fffff80569340619` | `0x0000001B00000001` | `+0x1720619` |

Full `!analyze -v` output for each crash is in [`analysis/`](analysis/).

---

## This is not file corruption

`BEDaisy.sys` was deleted and re-obtained through BattlEye's own update mechanism. The
replacement was **byte-identical** — same size, same SHA-256 — and crashed in exactly the same
way. A clean reinstall therefore cannot resolve this.

---

## A/B result

| HVCI state | attempts | outcome |
| :--- | :--- | :--- |
| **enabled** | 3 | BSOD every time — same offset, same instruction |
| **disabled** | 2 | no bugcheck; gameplay completed normally |

Note: BattlEye redeploys `BEDaisy.sys` on every launch, so each attempt is a fresh deployment.
Reboots alone did not change the outcome — crashes occurred across three separate boots with
HVCI enabled.

---

## What has *not* been tested — please read before citing this

- **One machine only.** A single host, one configuration.
- **No controlled crossover.** HVCI was disabled and the fault stopped, but HVCI was **not**
  re-enabled to reproduce it a fourth time. The evidence is 3-vs-2 on one system, not a
  formal controlled experiment.
- **HP Wolf Security** is installed and its kernel drivers were **not** modified. It is an
  untested co-variable.
- **Hyper-V and VBS remain enabled** with HVCI off, so "HVCI disabled" here does **not** mean
  "virtualisation disabled".
- The crash *instant* is inferred from recovery-boot event-log markers, not logged directly.

---

## Raw dumps are not published

See [DUMPS.md](DUMPS.md) for why. Kernel dumps contain sensitive memory contents and have been
deliberately withheld. Everything needed to identify the fault is in the `!analyze -v` output
under [`analysis/`](analysis/).

---

## Corroboration welcome

If you hit the same bugcheck — `0x7E`, `BEDaisy+0x1720619`, with `rbp` holding a garbage
pointer — please open an issue including your `!analyze -v` output, your `BEDaisy.sys`
SHA-256, and your Windows build. Independent reproductions are the fastest way to get this in
front of the right people.
