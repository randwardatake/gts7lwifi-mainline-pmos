# gts7lwifi — mainline postmarketOS port + tuning

Private backup of the work to bring **Samsung Galaxy Tab S7 Wi-Fi** (SM-T870 /
`gts7lwifi` / Qualcomm SM8250 / Adreno 650) up on **mainline Linux 7.2.0 +
postmarketOS edge + XFCE**, plus GPU overclock experiments, display/YouTube tuning,
and a security toolkit.

> Source, configs, patches and docs only — no large binaries (boot/rootfs/firmware
> images and kernel source trees are kept out; see below).

## Layout

| Path | What |
|---|---|
| `kernel/linux-samsung-gts7lwifi/` | pmaport: `APKBUILD` + 33 patches + kernel config. The whole custom kernel. Build with `pmbootstrap build linux-samsung-gts7lwifi`. |
| `boot/package-pmos.sh` | Packs kernel+DTB+initramfs into a uniLoader-wrapped, AVB-signed `boot.img` for sda22. |
| `boot/uniLoader-gts7lwifi_defconfig` | uniLoader config for this board (TEXT/PAYLOAD/RAMDISK layout). |
| `oc/` | GPU overclock: DTS overrides (v1 TURBO **failed**, v2 NOM_L1+ACD), `acd-values-downstream.md`, and `bench-results/` (glmark2/vkmark/sysbench + OPP sweeps). |
| `device-setup/` | `perfmode.sh`, `gts7-bench.sh`, `sec-toolkit.sh`, `gts7-setup-root.sh` (security toolkit + chromium tweaks), `make-desktop-launchers.sh`, `chromium.conf`, `h264ify-policy.json`, `GUVENLIK-REHBERI.html`. |
| `docs/FINDINGS.md` | **Read this** — all findings (OC ceiling, ACD discovery, tearing/YouTube fixes, WiFi limits, recovery). |
| `docs/handoff.md` | Original uniLoader boot bring-up handoff (earlier stage). |

## Quick reference

- **Device access:** `ssh gts7` (user `user` @ 172.16.42.1 over USB net).
- **GPU:** mainline stock ceiling 670 MHz; >670 needs ACD (`qcom,opp-acd-level`,
  value `0x802b5ffd`); 905–940 MHz is Android/KGSL/KonaBess-only. Pin clocks with
  `perfmode.sh on` for gaming.
- **Boot partition:** `/dev/sda22`. Back up with `dd if=/dev/sda22 of=backup.img`
  before flashing; OC failures are soft (software render) and restored by `dd`-ing
  the backup back.

## NOT included here (back up separately — binary/proprietary)

Kept out of git on purpose; copy these to external storage before wiping the machine:

- `~/gts7-backups/boot-los-backup.img` — LineageOS boot image, **required** by
  `package-pmos.sh` as the magiskboot repack base.
- `~/gts7-backups/boot-current-working-*.img` — known-good kernel (recovery).
- `~/gts7-backups/apnhlos.img`, `firmware/`, `recovery-los-backup.img` — device
  firmware / recovery backups.
- `~/.ssh/gts7_ed25519` (+ `.pub`) and `~/.ssh/config` — tablet SSH key/host.
- Kernel source trees (`~/linux-sm8250`) — re-fetchable from the pmaport source URL.
