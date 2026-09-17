# Galaxy Tab S7 Wi-Fi (gts7lwifi / SM8250) — mainline pmOS findings

Device: Samsung SM-T870 · Qualcomm SM8250 (Snapdragon 865) · Adreno 650 · 6 GB.
OS: postmarketOS edge + XFCE (X11), self-built mainline kernel **7.2.0**
(`linux-samsung-gts7lwifi`, pmaport). Boot chain: Samsung ABL → boot.img
(kernel = `uniLoader.gz`) → uniLoader → mainline kernel + `sm8250-samsung-gts7lwifi.dtb`
+ initramfs, on partition **`/dev/sda22`** (AVB-signed, packed by `boot/package-pmos.sh`).

## GPU overclock (Adreno 650)

- **Mainline hard ceiling (stock table) = 670 MHz** (`opp-level = NOM_L1`; stock
  non-turbo is 587 = NOM). CPU already exposes full silicon max (little 1.8 / big
  2.42 / prime 3.09 GHz).
- **On mainline the GX 3D clock is GMU-managed** — there is no static frequency
  table in `gpucc-sm8250.c`; the GX rail uses dummy `vdd`/`vddcx` regulators and
  the GMU votes RPMh corners derived from each OPP's `opp-level`.
- **>670 needs ACD.** Adding a bare `opp-700000000` (TURBO corner, no ACD) →
  `a6xx_gmu_set_oob: GMU OOB GPU_SET timeout` → `GMU firmware initialization timed
  out` → `gpu hw init failed: -110` → freedreno falls back to **llvmpipe** (software).
  Merely having a >670 OPP present breaks the whole GMU bringup (all-or-nothing).
  This was the same failure as earlier 690/700 attempts.
- **ACD is the missing piece, and it's mainline-native** (no Android required):
  kernel 7.2.0 implements `a6xx_gmu_acd_probe` reading `qcom,opp-acd-level`; the GMU
  node already has `qcom,qmp = <&aoss_qmp>`. See `oc/gpu-oc-700-nom_l1-acd.dts-override`
  and `oc/acd-values-downstream.md` (a650 ACD = `0x802b5ffd` for high levels).
  Status: v2 (700 @ NOM_L1 + ACD) built/flashed; **HW-accel verification pending**.
- **KonaBess "905–940 MHz" is Android/KGSL-only** — the downstream driver programs
  the GX PLL/ACD directly, bypassing the mainline GMU handshake. Even Samsung's
  downstream stock table tops at 670; higher levels are KonaBess additions.
- **Real gaming win = pin clocks, not OC:** `device-setup/perfmode.sh on` sets GPU
  devfreq `performance` (holds 670) + CPU `performance`. Benchmark: schedutil 5587
  vs performance 5518 sysbench events/s (equal, noise) but performance runs hotter
  (67 vs 61 °C) — schedutil already maxes cores under load; perf mode's value is
  GPU pinning + reduced ramp latency for games.

## Display tearing (XFCE / X11)

- Cause: xfwm4 compositing on with `vblank_mode = xpresent` on the 120 Hz panel —
  a known-tearing combo on freedreno. No DPU underrun/HW errors in dmesg.
- Fix: `xfconf-query -c xfwm4 -p /general/vblank_mode -s glx` (+ `xfwm4 --replace`).

## YouTube stutter

- Cause: Venus HW decoder exists (`/dev/video1`) but Chromium/Firefox can't use it
  (Adreno has no video decode; no VA-API↔Venus bridge) → browser software-decodes
  VP9/AV1.
- Browser-only fix (applied): `device-setup/chromium.conf` GPU flags +
  `h264ify-policy.json` (forces H.264) + default 720p.
- Best (optional): `mpv --hwdec=v4l2m2m-copy` / FreeTube genuinely uses Venus.

## WiFi / security capability

- Internal WiFi = **ath11k** → **no packet injection** (deauth/aireplay impossible);
  monitor is unreliable. Bluetooth (hci0) works. LAN MITM / scanning / BLE / offline
  cracking all work in managed mode.
- Real deauth needs an external USB adapter (AR9271/ath9k_htc, mt76x2u, rtl8xxxu) +
  those drivers built into the kernel (currently disabled).
- Toolkit installed via `device-setup/gts7-setup-root.sh`: nmap, wireshark/tshark,
  tcpdump, bettercap, ettercap, hashcat, john, hydra, arp-scan, masscan, wavemon,
  macchanger, nftables, bluez. Wireshark dumpcap given caps for non-root capture.
- The tablet is NOT a Flipper Zero (no SubGHz/NFC/IR hardware) — it's a WiFi/BT/LAN
  pentest box. Usage guide: `device-setup/GUVENLIK-REHBERI.html` (with legal warning).

## Recovery / flash notes

- Always back up the boot partition first: `dd if=/dev/sda22 of=backup.img`.
- OC failure mode is **soft** (software render, still boots to SSH) → restore by
  `dd`-ing the backup boot image back to sda22 and rebooting.
- Fast DTB iteration: edit `sm8250-samsung-gts7lwifi.dts`, `make ARCH=arm64 LLVM=1
  dtbs` in the kernel tree, swap into `uniLoader/blob/dtb` (re-apply `/chosen`
  bootargs + initrd window via fdtput), build uniLoader, `magiskboot` repack over the
  LOS boot image, `dd` to sda22. Full kernel: `pmbootstrap build
  linux-samsung-gts7lwifi` then `boot/package-pmos.sh`.
