# Cover notes

Replace `REPO_URL` with the repository link before sending. Each note is self-contained — the
recipient should not have to follow the link to understand the report.

Suggested order: **BattlEye first** (they own the driver), then Ubisoft, then Microsoft.
Public issue tracker last, so the vendor notes can reference a live link.

---

## → BattlEye

*Channel: battleye.com/support → contact form*

**Subject:** `BEDaisy.sys` 0x7E (STATUS_ACCESS_VIOLATION) when Memory Integrity is enabled

`BEDaisy.sys` faults with bugcheck `0x7E` (Arg1 `ffffffffc0000005`, STATUS_ACCESS_VIOLATION)
at `BEDaisy+0x1720619` when Windows Memory Integrity (HVCI) is enabled.

The faulting instruction is `mov r11w, word ptr [rbp]`, with `rbp` holding a garbage pointer
(`0x0000001B00000001`). It reproduces 3 out of 3 times with HVCI enabled and 0 out of 2 with it
disabled, using a byte-identical driver
(SHA-256 `184F28E4AC5C178AE05078F57AB54F3F3AE9864BC2FEA8CE20CB62AB8F3ECB7A`). A reinstall did
not help — your update mechanism served a file with the identical hash.

Host: Windows 11 Pro for Workstations 26H2, build 26300.9550 — a public release build, not
Insider. The fault appears within ~2m20s of game launch, on every launch, with HVCI on.

Full `!analyze -v` output for all three crashes: REPO_URL
Raw dumps are available privately on request.

Questions:

1. Is `BEDaisy.sys` expected to be compatible with HVCI?
2. Is there a known incompatibility with HVCI on Windows 11 26H2 / build 26300?

---

## → Ubisoft

*Channel: support.ubisoft.com → Rainbow Six Siege*

**Subject:** Rainbow Six Siege bugchecks (BSOD) via BEDaisy.sys when Memory Integrity is enabled

Since moving to Windows 11 26H2, Rainbow Six Siege blue-screens my machine within about two
minutes of launch whenever Windows Memory Integrity (HVCI) is enabled. The fault is in
BattlEye's `BEDaisy.sys`, not in Siege itself — but BattlEye ships with the game, so from a
player's perspective this is an R6 playability problem.

The only workaround I have is turning off Memory Integrity, i.e. disabling a Windows security
feature in order to play. I would rather not have to.

Reproduced 3 of 3 times with HVCI enabled and 0 of 2 with it disabled, on a byte-identical
driver. Windows 11 Pro for Workstations 26H2, build 26300.9550.

Full `!analyze -v` output and analysis: REPO_URL

Would you be able to pass this to the BattlEye team, or advise whether it is already known?

---

## → Microsoft

*Channel: Feedback Hub → Security and Privacy → Device security, or Windows Security feedback*

**Subject:** HVCI: `BEDaisy.sys` (BattlEye) bugchecks `0x7E` at `+0x1720619` with Memory
Integrity enabled

With Memory Integrity (HVCI) enabled on Windows 11 26H2 build 26300.9550, BattlEye's
`BEDaisy.sys` faults with `0x7E` (Arg1 `ffffffffc0000005`) at `BEDaisy+0x1720619`, executing
`mov r11w, word ptr [rbp]` against a garbage pointer. 3 of 3 with HVCI on; 0 of 2 with HVCI
off; byte-identical driver both ways.

I am not asking Microsoft to fix a third-party driver. Two things that may fall in scope:

1. Whether `BEDaisy.sys` (this build) should be flagged in the HVCI driver-compatibility list,
   so that a user enabling Memory Integrity is warned beforehand instead of discovering it via
   a bugcheck. At present nothing warns them, and the setting appears to take effect normally.
2. Whether anything in the 26H2 code-integrity or HVCI changes interacts badly with kernel
   drivers that perform load-time self-checks — the fault occurs in a paged section and looks
   like a corrupted pointer rather than a blocked operation.

Full `!analyze -v` output: REPO_URL

---

## → public issue tracker (optional, last)

Title: `0x7E in BEDaisy.sys at +0x1720619 when Memory Integrity (HVCI) is enabled`

Body: link REPO_URL, state the two reproducing conditions (HVCI on, Siege launched), and invite
others hitting the same bugcheck to add their `!analyze -v` output and driver SHA-256.
