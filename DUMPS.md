# Why the raw dumps are not in this repository

Five kernel dumps back the analysis in [`analysis/`](analysis/):

| crash | dump | size (bytes) |
| :--- | :--- | ---: |
| 1 · 2026-09-30 18:24 | `093026-21062-01.dmp` | 5,558,753 |
| 2 · 2026-09-30 18:38 | `093026-20718-01.dmp` | 3,814,739 |
| 3 · 2026-09-30 19:47 | `093026-21359-01.dmp` | 3,671,580 |
| 4 · 2026-10-01 08:49 | `MEMORY.DMP` (full) | 4,085,634,113 |
| 5 · 2026-10-01 09:13 | `MEMORY.DMP` (full) | 3,790,539,173 |

They are **deliberately not published.**

A kernel dump is a snapshot of kernel memory. It can contain credentials, session tokens,
filesystem paths, network configuration, registry contents and other processes' resident data.
Publishing one is a disclosure risk, and because git history is effectively permanent, a
later deletion does not undo it. `*.dmp` is listed in `.gitignore` to prevent it happening by
accident.

## What *is* published instead

Analysis extracts for every crash, in [`analysis/`](analysis/). Those carry everything required
to identify and triage the fault:

- bugcheck code and parameters
- faulting module, image and symbol
- the faulting instruction and its offset
- the failure bucket ID
- **the call stack** — which is what localises this defect to BEDaisy's minifilter unload path
  (`FLTMGR!FltpDoUnloadFilter` → `BEDaisy+0x97a4` → fault at `+0x1720619`)

Crashes 4 and 5 include the process list observed at the instant of the fault, showing the
Windows Installer activity that accompanies the trigger. Only process **names** are published —
no paths, no command lines, no user data.

## If you need the dumps themselves

If you are **BattlEye** or **Ubisoft** and want the raw dumps for your own analysis, please make
contact through your normal support channel. They are retained and can be supplied privately,
including via a time-limited link if that is easier than a multi-gigabyte attachment.

Please do not ask for them to be posted publicly.

## A note on the freezes during collection

Two of the dumps were captured after configuring `CrashDumpEnabled = 7` and
`AlwaysKeepMemoryDump = 1`. Note that with that setting Windows writes a **full** `MEMORY.DMP`
(~3.8 GB) and does **not** write a minidump — so a minidump-based collector will legitimately
find nothing. That caught this investigation out once; it is recorded here so it does not catch
anyone else out.
