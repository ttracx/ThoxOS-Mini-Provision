[![THOX](https://img.shields.io/badge/THOX-AI-10b981?style=for-the-badge&labelColor=09090b)](https://thox.ai)
[![License](https://img.shields.io/badge/license-proprietary-71717a?style=flat-square)](LICENSE)
[![Target](https://img.shields.io/badge/target-ThoxOS%20Mini%20VM-10b981?style=flat-square)](https://github.com/ttracx/thoxos-mini-utm)
[![Base](https://img.shields.io/badge/base-Debian%2011%20LXDE-ce4a7a?style=flat-square)](#)
[![Provisioner](https://img.shields.io/badge/script-provision--thoxos--mini.sh-3b82f6?style=flat-square)](provision-thoxos-mini.sh)
[![First Boot](https://img.shields.io/badge/systemd-thoxos--mini--firstboot-orange?style=flat-square)](first-boot/thoxos-mini-firstboot.service)
[![Version](https://img.shields.io/badge/version-0.1.0-10b981?style=flat-square)](VERSION)
[![Status](https://img.shields.io/badge/status-public%20release-10b981?style=flat-square)](https://github.com/ttracx/ThoxOS-Mini-Provision/releases)

# ThoxOS Mini Provision

Turns a fresh Debian 11 LXDE guest (the UTM prebuilt image, ARM64) into
ThoxOS Mini: the ThoxOS desktop sub-brand UI on LXDE, the UTM auto-resolution
fix, the SPICE agent, optional disk grow, and forced credential change off the
`debian/debian` + `root/password` defaults.

Run this INSIDE the VM.

## One-liner (after you push this repo to GitHub)

```
curl -fsSL https://raw.githubusercontent.com/ttracx/ThoxOS-Mini-Provision/main/install.sh \
  | sudo THOX_ROOT_PW='CHANGEME-root' THOX_USER_PW='CHANGEME-thoxy' bash
```

`install.sh` clones the whole repo so the wallpaper, icons, and themes come
along (a single-file download cannot install the UI), then runs the provisioner.

Add `THOX_GROW_ROOT=1` only if you enlarged the disk in UTM.

## From a local checkout (no hosting needed)

```
git clone https://github.com/ttracx/ThoxOS-Mini-Provision.git
cd ThoxOS-Mini-Provision
sudo THOX_ROOT_PW='CHANGEME-root' THOX_USER_PW='CHANGEME-thoxy' bash install.sh
# or call the provisioner directly:
sudo THOX_ROOT_PW='CHANGEME-root' THOX_USER_PW='CHANGEME-thoxy' bash provision-thoxos-mini.sh
```

## What it installs

- ThoxOS Mini UI: emerald-on-graphite LXDE theme, Openbox window theme, branded
  panel, terminal, greeter, wallpaper, ThoxOSMini icon theme.
- `xrandr-thox-autoresize` (login + on-demand) for the known UTM resize bug.
  Manual: `xrandr --output Virtual-1 --auto`.
- SPICE agent (clipboard + display).
- Optional root filesystem grow (`THOX_GROW_ROOT=1`).
- New `root` and user passwords (refuses to keep the image defaults).

## First-boot (run once automatically)

Copy this repo to `/opt/thoxos-mini` and enable the unit so the provisioner runs
once on first boot:

```
sudo cp -r . /opt/thoxos-mini
sudo cp first-boot/thoxos-mini-firstboot.service /etc/systemd/system/
echo 'THOX_ROOT_PW=CHANGEME-root'  | sudo tee /etc/thoxos-mini.env
echo 'THOX_USER_PW=CHANGEME-thoxy' | sudo tee -a /etc/thoxos-mini.env
sudo systemctl enable thoxos-mini-firstboot.service
```

## After it finishes

Log out and back in (or reboot) so LXDE loads the theme, panel, and wallpaper.

## Notes

- Slow under UTM SE on iPhone/iPad (no JIT); expected, not a failure.
- Keep the guest ARM64 and CPU `cortex-a72` in UTM to avoid the init panic.
- Privacy-first: ThoxOSCompanion pairs over LAN/MeshStack; nothing leaves the
  mesh in plaintext.

---

## Related projects
- [ttracx/thoxos-mini-utm](https://github.com/ttracx/thoxos-mini-utm) - ThoxOS Mini UTM VM image + iOS auto-launcher (private)
- [ttracx/thox-utm](https://github.com/ttracx/thox-utm) - THOX customized UTM app for iOS + macOS (private)
- [ttracx/thoxos-companion-ios](https://github.com/ttracx/thoxos-companion-ios) - ThoxOS Companion iOS app
- [ttracx/thox-llm](https://github.com/ttracx/thox-llm) - central docs

## Inventor attribution
The technologies in this repository are documented in IP-008 through IP-012, filed 2026-04-03 with PCT deadline 2027-03-04. Inventors of record: Craig Ross and Phamy Xaypanya.

---

**Thox.ai LLC** | Cedar Park, Texas

Copyright (c) 2026 Thox.ai LLC. All rights reserved.

THOX, Thox.ai, THOX Nova, and ThoxOS are trademarks of Thox.ai LLC.

<!-- THOX-DOCS-STANDARD:START -->
## Repository Description

ThoxOS Mini provisioning kit: provision-thoxos-mini.sh + first-boot systemd unit + LXDE theme assets to apply the THOX brand layer to a Debian 11 LXDE VM.

## Documentation

- [Repository documentation](docs/README.md)
- [Security policy](SECURITY.md)
- [Contributing guide](CONTRIBUTING.md)
- [Legal notice](NOTICE.md)

## THOX.ai LLC

This repository is maintained by THOX.ai LLC.

- Tommy Xaypanya is CTO.
- Craig Ross is CEO.

## Copyright and Legal

Copyright (c) 2026 THOX.ai LLC. All rights reserved unless this repository includes a separate license file that states otherwise.

THOX-specific documentation, configuration, branding, product definitions, and integration work are owned by THOX.ai LLC unless explicitly noted. Third-party dependencies, forks, vendored components, and upstream source materials remain governed by their original licenses and notices.
<!-- THOX-DOCS-STANDARD:END -->
