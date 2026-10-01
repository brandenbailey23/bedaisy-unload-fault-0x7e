# Why the raw dumps are not in this repository

Three kernel dumps back the analysis in [`analysis/`](analysis/):

| dump | size (bytes) |
| :--- | ---: |
| `093026-21062-01.dmp` | 5,558,753 |
| `093026-20718-01.dmp` | 3,814,739 |
| `093026-21359-01.dmp` | 3,671,580 |

They are **deliberately not published.**

A kernel dump is a snapshot of kernel memory. It can contain credentials, session tokens,
filesystem paths, network configuration, registry contents and other processes' resident data.
Publishing one is a disclosure risk, and because git history is effectively permanent, a
later deletion does not undo it. `*.dmp` is listed in `.gitignore` to prevent it happening by
accident.

## What *is* published instead

The full `!analyze -v` output for all three crashes, in [`analysis/`](analysis/). That output
carries everything required to identify and triage the fault:

- bugcheck code and parameters
- faulting module, image and symbol
- the faulting instruction and its offset
- the failure bucket ID

## If you need the dumps themselves

If you are **BattlEye**, **Ubisoft** or **Microsoft** and want the raw dumps for your own
analysis, please make contact through your normal support channel. They are retained and can
be supplied privately, including via a time-limited link if that is easier than an attachment.

Please do not ask for them to be posted publicly.
