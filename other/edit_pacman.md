# pacman / package storage — research notes

> **Status: research only. Nothing in this file has been applied to the system.**
> Last reviewed: 2026-10-16 · Pacman v7.1.0 / libalpm v16.0.1
> `/etc/pacman.conf` is still at stock defaults.

---

## 1. The real goals

This is not a space problem. Space is a side effect. The three actual goals,
in priority order:

| # | Goal | What it really means |
|---|---|---|
| **G1** | **Inspectability** | Packages kept where I can *see* them, so I can spot, |
|        |                    | inspect and delete malware myself if the package manager is compromised. |
| **G2** | **Wipe-and-reinstall without loss** | Reinstall Linux from scratch to guarantee a virus is gone, without losing my package set every time. |
| **G3** | **`/` stays constant** | `/` used to be 40G; it grew to 59G. Keep it stable and predictable. |

**Bottom line: the original plan (move pkg storage + `/usr` + `/opt` into HOME)
serves none of these properly, and breaks G1 and G2.** See §4.

---

## 2. Threat model — "Atomic Arch" (current, real)

Disclosed **2026-06-11 / 06-12**. A supply-chain campaign against the
**Arch User Repository**, specifically **orphaned** (maintainer-less) AUR
packages.

- 400 to ~1,900 AUR packages hijacked
- Malicious build scripts in PKGBUILDs pulling rogue npm deps (`atomic-lockfile`)
- **eBPF rootkit** deployment, credential stealers / infostealer
- Arch responded by disabling AUR adoption and pausing pushes

**This machine's exposure surface:** `yay v13.0.1` (AUR helper) + **21 foreign
packages** (`pacman -Qm`).

**Why moving things to HOME does not defend against this:** the compromise is
in *what gets built*, not *where files sit*. A malicious PKGBUILD builds a
package whose checksums are internally consistent, and pacman records them
faithfully. Relocating `/usr` or the DB changes nothing about that.

---

## 3. Verified state of this machine (2026-10-16)

### 3.1 Integrity check — clean

```
$ pacman -Qkk
  across all 1,624 packages:   0 altered files
  only 2 warnings: /etc/libaudit.conf (failed to calculate SHA256)
```

`-Qkk` is the real tool (the man page: *"Specifying this option twice will
perform more detailed file checking — permissions, file sizes, modification
times — for packages that contain the needed mtree file"*). It checks SHA256 +
size + mtime against the DB.

**What this proves:** no installed package file has been modified after
installation.
**What it does NOT prove:** that packages were *built* clean — see §2. A
compromised PKGBUILD yields internally-consistent checksums. That is why the
PKGBUILDs in `~/.cache/yay` still need review.

Note `pacman -Qk` (single `-k`) only checks file **presence** — 269 files, 0
missing for `bash`. Use `-kk` for content.

### 3.2 AUR exposure — 21 foreign packages

```
2026-05-20   nvidia-580xx-dkms · nvidia-580xx-utils · nvidia-580xx-settings
             lib32-nvidia-580xx-utils
2026-05-26   catppuccin-gtk-theme-mocha
2026-09-14   protobuf3.21 (+ -debug)
2026-09-18   bridge-utils (+ -debug)
2026-09-25   ttf-times-new-roman
2026-10-02   libcava · brave-bin · yay-bin · libxnvctrl-580xx
             mcpelauncher-linux-bin · mcpelauncher-ui-bin (+ -debug each)
2026-10-05   opencl-nvidia-580xx
```

**Nothing was installed inside the June 11–12 disclosure window.** The May
batch predates disclosure by ~3 weeks (campaign start date unknown — may have
been running before detection). The Sep/Oct batch postdates Arch's cleanup.

**Highest residual interest** — the low-traffic, orphan-shaped profile that was
actually targeted:

| Package | Why it's interesting |
|---|---|
| `protobuf3.21` | version-pinned — the classic orphaned AUR package |
| `ttf-times-new-roman` | font package, low traffic |
| `bridge-utils` | odd: it exists in the official repos — why AUR? |
| `catppuccin-gtk-theme-mocha` | theme, low traffic |

Lower concern: `brave-bin`, `yay-bin` (heavily trafficked, unlikely orphan
targets), and the nvidia-580xx family (niche but a coherent set).

### 3.3 What actually grows on `/`

```
/tmp                tmpfs  7.8G (7.0G avail)  ← already RAM, not on /  ✓
/var/lib            318M                       ← tiny
   systemd 124M · dkms 89M · pacman 68M · plocate 22M
   libvirt 6.6M · texmf 5.3M · flatpak 3.4M   (flatpak already cleaned)
journal             557.7M                     ← grows
/var/log            562M                       ← grows
/var/cache/pacman   4.8G                       ← THE growth driver
```

`/usr` and `/opt` are **static** — they grow only when you install something,
in steps, not continuously.

### 3.4 Filesystems

```
/       sda2  ext4   59G   31G used   26G free   55%
/home   sda7  ext4  175G   48G used  119G free   29%
/var    (on sda2 — NOT a separate mount)
```

```
/etc/fstab:  UUID=ad83cbd7-9209-4bc8-8350-d4945a1c1e42  /home  ext4  rw,relatime  0 2
```

No `nofail`, no early mount → `/home` mounts at `local-fs.target`, i.e. **after**
systemd has already executed from `/usr/lib`.

### 3.5 pacman configuration

| | |
|---|---|
| `DownloadUser` | `alpm` (line 38, active); user exists, groups = `alpm` only |
| `SigLevel` | `Required DatabaseOptional` (line 44) — Arch default |
| multilib | enabled (line 93) |
| mirrors | 51 entries |
| hooks | 66 official (`/usr/share/libalpm/hooks`), **0 local** (`/etc/pacman.d/hooks`) |
| local DB | `/var/lib/pacman/local` — **1,624 packages**, `ALPM_DB_VERSION` **9**, 68 MB |
| `RootDir`/`DBPath`/`CacheDir` | all unset = defaults |
| packages | 1,624 total · 206 explicit · **21 foreign** |
| kernels | `7.1.11-arch1-1` — **only one** |

### 3.6 Permissions that decide everything

```
/home          drwxr-xr-x   root:root      ← alpm CAN traverse (o+rx)
/home/playme   drwx--x---   playme:playme  ← alpm CANNOT (not owner, not in group, other=---)
```

### 3.7 Sizes on `/` for the record

```
/usr/lib   8.8G   python3.14 736M · modules 577M · jvm 550M · firmware 539M
                  wine 488M · libreoffice 452M · ghc-9.6.7 415M
/usr/share 4.1G   fonts 554M · locale 536M · dotnet 493M · doc 468M
                  julia 379M · edk2 208M · qemu 143M
/opt       7.7G   brave-bin (pacman) · mcpelauncher-* (pacman)
                  containerd · resolve · yay-bin  (manual)
```

Toolchains installed: `ghc 9.6.7-1`, `julia 2:1.13.1-1`,
`dotnet-sdk 10.0.12.sdk112-1`, `wine-staging 11.19-1`,
`libreoffice-fresh 26.8.1-1`.

### 3.8 yay — already entirely in HOME

```
yay v13.0.1 - libalpm v16.0.1
~/.cache/yay      1.8G, 16 build dirs, live PKGBUILDs   ← already in HOME
~/.config/yay     4.0K
```

**The single most valuable artifact for G1 is already in your HOME directory.**

---

## 4. Verdict: the proposed architecture vs. the goals

| Move | Gain | G1 inspect | G2 reinstall | G3 constant | Risk |
|---|---|---|---|---|---|
| `CacheDir` → `/home` partition | 4.8G | neutral | **helps** (signed offline source) | **helps** | none |
| `/usr/lib` → HOME | 8.8G | **worse** | **breaks** | no | **fatal, unbootable** |
| `/usr/share` → HOME | 4.1G | **worse** | **breaks** | no | early-boot breakage |
| `/opt` → HOME symlink | 7.7G | neutral | **breaks** | no | moderate |
| `DBPath` → HOME | 68 MB | **worse** | **breaks** | no | **detaches pacman** |
| `LogFile`/`GPGDir` → HOME | ~10 MB | **worse** | no | no | **locks you out** |
| yay → HOME | 0 | — | — | — | already there |

### G1 — inspectability: moving to HOME makes it *worse*

Everything is already fully inspectable at standard paths. Two things matter
here:

1. **Standard layout enables the strongest detection technique there is —
   diffing against a pristine Arch install.** A nonstandard layout destroys
   that baseline. If your goal is "spot what doesn't belong", you want your
   system to look as much like stock Arch as possible.
2. **The attack vector is in what gets built, not where files sit.** Moving
   `/usr` cannot help. Reviewing the 21 `PKGBUILD`s and the artifacts in
   `~/.cache/yay` can.

### G2 — wipe-and-reinstall: moving to HOME actively breaks it

A fresh install writes a **real** `/usr`, `/opt` — overwriting any symlink you
planted. Your HOME copies become orphans. The reinstall does not "find" your
packages in HOME; it installs its own.

**What actually preserves a package set is 4,066 bytes of text:**

```bash
pacman -Qe > ~/pkglist_explicit.txt     # 206 packages
pacman -Qm > ~/pkglist_aur.txt          # 21 foreign (AUR)
```

After a fresh install:

```bash
pacman -S --needed - < ~/pkglist_explicit.txt
yay   # rebuild AUR packages from the list — do NOT restore old AUR builds
```

Do **not** preserve `/var/lib/pacman` across a wipe: `--needed` skips anything
the DB says is installed, so an inherited DB would make the restore a no-op.
A manifest is strictly better — readable, diffable, greppable, and trivially
small.

**Asymmetry that matters for G1:** the *official* package cache is
cryptographically signed and re-verifiable, so reusing it offline is safe.
AUR packages are **built locally and never signed** — restoring old AUR build
artifacts would restore exactly the compromise you are wiping to remove.
→ preserve the official cache, **purge `~/.cache/yay`**.

### G3 — constant `/`: move the growing things, not the static things

| | Verdict |
|---|---|
| `/tmp` | already tmpfs (RAM) — nothing to do |
| `/var/lib` | 318 M total — not worth touching |
| `/var/cache/pacman` **4.8G** | **the real growth driver — move this** |
| journal 557 M | cap it, or make it volatile |
| `/usr/lib`, `/usr/share`, `/opt` | static; moving them doesn't stop `/usr` growing on |
|                                  |install — a second copy just starts growing in HOME |

Two levers actually make `/` constant:

1. `CacheDir` → the `/home` partition (removes 4.8 G *and* its regrowth)
2. journal: `SystemMaxUse=` in `/etc/systemd/journald.conf`, or
   `Storage=volatile` to put it in RAM alongside `/tmp`

### On the HOME-loss theory

`/` (sda2) and `/home` (sda7) are **separate filesystems** — `/` filling cannot
delete files on `/home`. But an application with cache on `/` and data on
`/home` can fail or abort mid-write when `/` fills, which is a plausible
*indirect* cause of data loss in HOME.

So keeping `/` headroomed is worth doing — **for that reason**, not because a
full `/` erases HOME. Adding 20 G was reasonable; the correct follow-up is to
stop the *growing* storage living there in the first place.

---

## 5. Recommended actions

**Do now (serves G1 and G2, zero risk):**

```bash
# G2 — your entire reinstall plan, 4 KB
pacman -Qe > ~/pkglist_explicit.txt
pacman -Qm > ~/pkglist_aur.txt

# G1 — periodic integrity check (currently CLEAN)
pacman -Qkk 2>&1 | grep -vE ': [0-9]+ total files, 0 altered files$' \
                 | grep -v 'failed to calculate SHA256'
```

```bash
sudo cp -a /opt /home/playme/opt     # 7.7G copy; /home has 119G free
sudo mv /opt /opt.old                # same-fs rename, instant
sudo ln -s /home/playme/opt /opt
```

# verify apps launch, then: sudo rm -rf /opt.old
**Do next (serves G3):**

1. `CacheDir` → the `/home` **partition**, but *not* inside `/home/playme`:

   ```bash
   sudo install -d -o root -g root -m 755 /home/pacman-cache
   # /etc/pacman.conf → [options]
   # CacheDir = /home/pacman-cache/
   ```

   `/home` is `755 root:root`, so `alpm` can traverse it. Inside `/home/playme`
   (`710`) it cannot — see §7 Problem 2.

2. Cap the journal, or make it volatile.

**Do after research (serves G1):**

3. Audit the 21 AUR packages against the published Atomic Arch affected list,
   prioritising `protobuf3.21`, `ttf-times-new-roman`, `bridge-utils`,
   `catppuccin-gtk-theme-mocha`. Check upstream AUR page history for
   maintainer changes around the campaign.
4. Review the `PKGBUILD`s in `~/.cache/yay` (16 build dirs) — **then** purge
   the cache. They are evidence first, junk second.
5. Consider `SigLevel = Required DatabaseRequired` — Arch does sign `core.db`;
   verify your mirrors serve `*.db.sig` first, or pacman will refuse everything.
6. Re-check `/etc/pacman.d/hooks` (currently 0) — libalpm hooks are a classic
   persistence mechanism.

---

## 6. Original plan (draft — preserved verbatim)

```markdown
1. Fix the Path / Username Mismatch
    sudo pacman-db-upgrade --root /home/playme/ --dbpath /home/playme/pacman/lib

2. Put Directives Under [options] in pacman.conf
   [options]
   CacheDir = /home/playme/pacman/cache
   DBPath   = /home/playme/pacman/lib
   LogFile  = /home/playme/pacman/pacman.log
   GPGDir   = /home/playme/pacman/gnupg

3. Keyring Setup (pacman-key)
       sudo pacman-key --config pacman.conf --init
       sudo pacman-key --config pacman.conf --populate archlinux

4. Create the Directory Structure First
   mkdir -p /home/playme/pacman/{cache,lib/local,gnupg}
   sudo pacman-db-upgrade --config pacman.conf --root /home/playme/

5. Important Gotcha: Permissions and Sandboxing
   If alpm does not have write permissions to your user's home folder
   (/home/playme/pacman/cache), downloads will fail with permission errors:
       sudo chmod 777 /home/playme/pacman/cache
```

**What the draft gets right:** options really are `[options]`-only keys;
`pacman-key` really needs `--config` for a relocated `GPGDir`; files created
under `sudo` really do become `root:root`; the download sandbox really does
exist and the predicted symptom is correct.

---

## 7. Why the original plan fails

### Problem 1 — `pacman-db-upgrade` does not migrate your DB

It only bumps `ALPM_DB_VERSION` on an **existing** database. Ours is already
**9**, so on a real DB it is a no-op — and against the `mkdir -p .../lib/local`
in step 4 it merely stamps a version onto an **empty directory**.

Your real DB has **1,624 packages**. After any `DBPath` relocation, pacman reads
an empty one instead:

| Command | Result |
|---|---|
| `pacman -Q` | 0 packages |
| `pacman -Syu` | **"there is nothing to do" forever** — the system silently stops updating |
| `pacman -Qdtq` | computed against wrong data → can remove libs the other 1,624 packages use |
| `pacman -Qk` / `-R` / `-Qi` | meaningless |

This happens from the `DBPath` line **alone** — no `RootDir` change required.
`RootDir = /home/playme` is worse: package *files* would extract to `~/usr`,
`~/etc` — off your PATH and invisible to the running system.

**The DB is 68 MB. There is no space argument for moving it.** If it ever is
moved, *move* the real one, never create a fresh one:

```bash
sudo rsync -aHAX /var/lib/pacman/ /home/playme/pacman/lib/
```

But see §4 G2 — for a wipe-and-reinstall, a manifest beats a DB outright.

### Problem 2 — `chmod 777` cannot fix the permission failure

`alpm` needs execute on **every** path component to reach
`/home/playme/pacman/cache/`. It dies at `/home/playme` (`710`; `alpm` is not
in group `playme`, `other = ---`). Changing the leaf to `777` changes nothing —
traversal fails first. And `777` on a directory root stages packages from is
bad practice even when it works.

**Actual fix:** put the cache *beside* your home dir, mirroring the original's
ownership — `/home` is `755 root:root`:

```bash
sudo install -d -o root -g root -m 755 /home/pacman-cache
```

Alternatives if it must live under `/home/playme`: `DownloadUser = root`
(disables the download sandbox; sigs still verified),
`sudo usermod -aG playme alpm`, or `sudo chmod o+x /home/playme`.

### Problem 3 — do not relocate `GPGDir`

No measurable space win (~10 MB), and it is the single misconfiguration that
makes pacman reject **every** package with signature errors — the classic way
to lock yourself out of your own package manager. Keep `/etc/pacman.d/gnupg`.

### `/usr/lib` — 8.8G — ❌ unbootable

Contains `ld-linux-x86-64.so.2` (the dynamic loader every binary needs),
`libc.so.6`, `/usr/lib/systemd` (PID 1) and `/usr/lib/modules` (kernel
modules). systemd executes from `/usr/lib` **before any fstab mount runs**, and
`/home` has no early-mount entry. A symlink or bind mount there is dangling at
PID 1 → no boot → live USB to recover.

Could only work by mounting the target **from inside the initramfs**, which
makes boot depend on `/home` existing at all. Not worth it.

### `/usr/share` — 4.1G — ❌ early-boot pieces

Holds `/usr/share/zoneinfo` (timezone data used everywhere),
`/usr/share/systemd`, `/usr/share/pacman` (keyrings),
`/usr/share/libalpm` (hooks). Same boot-order problem, minus instant death.
Its bulk — `fonts` 554 M, `locale` 536 M, `doc` 468 M — should be **pruned or
uninstalled**, not relocated.

### `/opt` — 7.7G — ⚠️ the only feasible one, but it doesn't serve a goal

Nothing there is needed for PID 1 or a login, `/home` has no `nofail`, and
desktop entries / `ExecStart=` paths / pacman's file checks all resolve through
a symlink. Worst case: `/opt` apps missing, system still boots.

```bash
sudo cp -a /opt /home/playme/opt     # 7.7G copy
sudo mv /opt /opt.old                # same-fs rename, instant
sudo ln -s /home/playme/opt /opt
# verify brave / resolve / containerd launch, then:
sudo rm -rf /opt.old
```

Open question: does `containerd.service` start before `/home` is mounted? Check
`systemctl list-dependencies containerd.service` before committing.

---

## 8. Warnings

- **Do not run `pacman -Qdtq | xargs pacman -Rns` while `DBPath` is
  relocated** — orphan detection against a detached database computes against
  wrong data and can pull out libraries the rest of the system uses.
- **No old-kernel purge needed** — only one kernel is installed.
- **`pacman -Qkk` = 0 altered does not mean clean.** It cannot see new files
  that were added, nor a kernel-level implant (eBPF rootkits are precisely the
  Atomic Arch payload). Treat it as necessary, not sufficient.
- `/` has **26 G free**. Nothing here is urgent.
- **Before any structural change: save `~/pkglist_explicit.txt` and
  `~/pkglist_aur.txt`.** That is your only guaranteed path back.

---

## 9. Open questions

1. **Is the real goal a bigger root partition?** `/` is 59 G against
   `/home`'s 175 G. If that imbalance is the complaint, the answer is
   partition work — a much riskier and different project than any config edit.
2. Are `ghc`, `julia`, `dotnet-sdk`, `wine-staging`, `libreoffice-fresh` all in
   use? ~2.2 G of libs/shares alone, likely more as full packages.
3. What were the Atomic Arch affected package names, exactly? Needed to check
   the 21 against a definitive list rather than by profile.
4. When did the campaign actually start? The May 2026 batch predates
   *disclosure*; if the campaign began earlier, those four nvidia packages and
   `catppuccin-gtk-theme-mocha` need the same scrutiny.
5. Do your mirrors serve `*.db.sig`? Decides whether `DatabaseRequired` is
   available.
