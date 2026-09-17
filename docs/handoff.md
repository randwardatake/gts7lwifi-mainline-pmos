# Handoff — uniLoader port to Samsung Galaxy Tab S7 Wi-Fi

**Device:** SM-T870 / `gts7lwifi` / Qualcomm SM8250 (kona) / 6 GB RAM
**Loader:** [ivoszbg/uniLoader](https://github.com/ivoszbg/uniLoader), chainloaded by Samsung ABL as the `boot.img` kernel
**Working tree:** `/home/randward/uniLoader` (WSL Debian, ext4)
**Status:** uniLoader runs on device (splash reaches the framebuffer). The Linux kernel never starts. Root causes identified, fixes drafted, **nothing flashed/verified on device yet.**

---

## 1. How uniLoader actually boots a kernel

Verified by reading the source, not guessed:

| File | Behaviour |
|---|---|
| `arch/aarch64/linker.lds.S` | Embeds `blob/Image`, `blob/dtb`, `blob/ramdisk` **into the loader binary**. Exports `kernel_size`, `ramdisk_size`, `_reloc_size`. |
| `arch/aarch64/reloc.S` | With `CONFIG_POSITION_INDEPENDENT=y`, copies the **entire image** (loader + all three blobs, `_reloc_size` bytes) to `CONFIG_TEXT_BASE`, then jumps there. |
| `arch/aarch64/start.S` | arm64 image header is emitted from `reloc.S` when `LINUX_KRNL_HEADER_IMG=y` **and** PIE is set (the `start.S` copy is only for non-PIE). Current combination is correct. |
| `arch/aarch64/load-kernel.c` | `memcpy(PAYLOAD_ENTRY, kernel, kernel_size)` → `memcpy(RAMDISK_ENTRY, ramdisk, ramdisk_size)` → `load_kernel_and_jump(dt, 0,0,0, PAYLOAD_ENTRY)`, i.e. `br x4` with `x0 = dtb`, `x1..x3 = 0`. Correct arm64 protocol. |
| `main/boot-fdt.c` → `drivers/ramdisk-handler.c` | The **only** DTB patching upstream does is `/chosen/linux,initrd-start` + `linux,initrd-end`. No `bootargs`. No `/memory`. Fails outright if `/chosen` does not exist. |

Two consequences that drive everything below:

- The DTB is **never** copied to a load address. It is passed straight out of `fdt_buf`, a `static char[CONFIG_FDT_BUF_SIZE]` in the loader's `.bss`, i.e. it lives next to `TEXT_BASE`.
- Nothing patches `/memory`. On a normal boot **ABL** fills it in; uniLoader hands over its own embedded DTB that ABL never sees.

---

## 2. Root cause #1 (fatal): `/memory` is empty

`blob/dtb` is the **stock downstream kona DTB** and contains:

```dts
memory {
        device_type = "memory";
        reg = <0x00 0x00 0x00 0x00>;   /* base 0, size 0 */
};
```

Linux therefore comes up with **zero usable RAM** and dies in `early_init_dt_scan_memory()`, long before any console exists — which matches the observed "nothing at all happens" symptom.

Mainline device trees have the identical trap (`reg = <0 0x80000000 0 0>` with a `/* We expect the bootloader to fill in the size */` comment), so switching to a mainline DT does **not** avoid this.

### Fix: `uniloader-gts7lwifi-memory-node.patch`

Adds `include/main/memory-map.h` (per-board bank table, guarded by `CONFIG_SAMSUNG_GTS7LWIFI`, no-op for other boards) and `patch_memory()` in `main/boot-fdt.c`, which writes the real banks into `/memory` right before handoff.

Details worth knowing before editing it:

- Refuses to run unless root `#address-cells` / `#size-cells` are both 2 (the `<base,size>` pairs are encoded as 64-bit).
- `fdt_path_offset(fdt, "/memory")` matches **both** `memory` and `memory@80000000` (libfdt's `fdt_nodename_eq` ignores the unit address), so it works for downstream and mainline trees. Creates the node if missing.
- If the ramdisk/`/chosen` patch fails, it still patches `/memory` as long as `fdt_check_header(fdt_buf)` passes — booting without an initrd beats booting without memory.

Verified on the host against the repo's own libfdt (**not** on device):

```bash
# from the uniLoader checkout
gcc -O1 -w -o /tmp/t -Iinclude -Iinclude/lib/libfdt -I<shim-with-util.h> \
  -DS32_MAX=2147483647 -D__aarch64__=1 \
  -DCONFIG_LIBFDT -DCONFIG_FDT_BUF_SIZE=500000 \
  -DCONFIG_SAMSUNG_GTS7LWIFI -DCONFIG_RAMDISK_ENTRY=0xe0000000UL \
  test-fdt.c stubs.c main/boot-fdt.c drivers/ramdisk-handler.c lib/libfdt/*.c
```

Result: 7 banks, **5850 MiB** total, bank boundaries identical to stock `/proc/iomem`; passes with and without a `/chosen` node.

> **Host-test trap:** `drivers/ramdisk-handler.c` guards its `fdt_setprop_u64` calls with `#ifdef __aarch64__ / #elif __arm__`. On an x86 host **neither** is defined, so the initrd properties are silently compiled out and the handler still returns 0. Always pass `-D__aarch64__=1` in host tests, or you will "discover" a bug that does not exist.
> The `stubs.c` shim must provide `__optimized_memcpy` / `__optimized_memmove`; `util.h` (`ARRAY_SIZE`) must come from a shim dir, because `-Ilib/unic` drags in a `stdint.h`/`string.h` that collide with glibc.

---

## 3. Root cause #2: memory layout overlaps

Current (broken) defconfig:

```
CONFIG_TEXT_BASE=0x86e00000
CONFIG_PAYLOAD_ENTRY=0x94000000
CONFIG_RAMDISK_ENTRY=0x97000000
```

- **Kernel eats the ramdisk.** Only 48 MB between payload and ramdisk. arm64 requires `image_size` bytes free from the kernel base (BSS included); the stock kernel measures ~65 MB (`Kernel code` 41.5 MB + `Kernel data` 21 MB). It also grows toward the framebuffer at `0x9c000000`.
- **TEXT_BASE window is 36 MB.** `0x86e00000–0x891fffff` is the only System RAM there; `0x89200000–0x9031bfff` (~225 MB) never appears as System RAM at all — it is firmware (modem/ADSP/CDSP/TZ). With PIE the loader copies loader + Image + ramdisk into that 36 MB window. Measure the built image; if it exceeds 36 MB it is overwriting firmware.

### New layout — all three inside `0xc0000000–0xe3bfffff` (572 MB, no reserved sub-ranges)

```
CONFIG_TEXT_BASE=0xc0000000       # loader + embedded Image/dtb/ramdisk
CONFIG_PAYLOAD_ENTRY=0xd0000000   # kernel, 256 MB of headroom
CONFIG_RAMDISK_ENTRY=0xe0000000   # ramdisk, 60 MB up to the 0xe3c00000 reserved edge
```

Conservative alternative: `TEXT 0xc0000000 / PAYLOAD 0x90c00000 / RAMDISK 0xd0000000`.

---

## 4. Memory map (derived from stock `/proc/iomem`)

Usable windows (contiguous System RAM with no `reserved` children):

| Window | Size | Notes |
|---|---|---|
| `0xc0000000–0xe3bfffff` | **572 MB** | nothing reserved inside — preferred |
| `0x90a00000–0x9bffffff` | 182 MB | `0x9c000000–0x9e3fffff` is reserved (cont_splash / framebuffer) |
| `0xa0200000–0xaeffffff` | 238 MB | stock kernel loads here; free under uniLoader |
| `0xb1800000–0xbcbfffff` | 180 MB | |
| `0x86e00000–0x891fffff` | 36 MB | current TEXT_BASE; tight |

Bank list used by the patch (System RAM minus firmware carveouts, ≈5850 MiB):

```dts
reg = <0x00 0x86e00000 0x00 0x02400000>,
      <0x00 0x90a00000 0x00 0x0e600000>,
      <0x00 0x9fa00000 0x00 0x00601000>,
      <0x00 0xa0002000 0x00 0x100fe000>,
      <0x00 0xb0200000 0x00 0x0ca00000>,
      <0x00 0xc0000000 0x00 0x3fc00000>,
      <0x00 0xffc20000 0x01 0x003e0000>;
```

Four sub-MB fragments (`0x80600000`, `0x80894000`, `0x9031c000`) were dropped as noise; add them back if you want bit-exact parity.

**Rules:**

- Address ranges **absent** from `/proc/iomem` are firmware-owned. Never load into them.
- The `Kernel code` / `Kernel data` lines move on every boot (**KASLR**). They are useful only to estimate `image_size`; never derive load addresses from them.
- Framebuffer / cont_splash is `0x9c000000` (matches `board/samsung/board-gts7lwifi.c`, `1600x2560`, ARGB8888). Keep it intact and keep it inside a declared memory bank, or simplefb output dies.

---

## 5. Open questions / blockers

1. **Which kernel is in `blob/Image` — downstream or mainline?** `blob/dtb` is downstream (`compatible = "qcom,kona"`, `qcom,msm-id = <0x164 0x20001>`). A mainline kernel will not boot that DTB and vice versa. Resolve this before debugging anything else.
2. **Does `blob/dtb` have a `/chosen` node with `bootargs`?** uniLoader adds no command line. At minimum `bootargs = "console=tty0 earlycon rw"`; a downstream kernel additionally expects the `androidboot.*` parameters ABL normally supplies.
3. **Is the built loader image smaller than its TEXT_BASE window?** Check before assuming relocation is safe.

---

## 6. Next steps, in order

1. `git apply uniloader-gts7lwifi-memory-node.patch`
2. Update the three addresses in `configs/gts7lwifi_defconfig` (§3).
3. Confirm `/chosen` + `bootargs` in `blob/dtb`; add if missing.
4. Rebuild, check the image size against the TEXT_BASE window, repack into `boot.img`, flash, observe.
5. If the kernel starts but produces no output, add a `simple-framebuffer` node at `0x9c000000` plus `CONFIG_FB_SIMPLE` and `console=tty0`, or reserve a `ramoops` region and read pstore after reboot (Samsung's own log area is `ss_plog` at `0x9f800000`).

### Verify commands

```bash
cd /home/randward/uniLoader
fdtget blob/dtb /memory reg          # must be the 7 banks, not zeroes
fdtget -l blob/dtb /chosen           # node must exist
dtc -I dtb -O dts blob/dtb | head -40
make ARCH=aarch64 CROSS_COMPILE=aarch64-linux-gnu- gts7lwifi_defconfig
make ARCH=aarch64 CROSS_COMPILE=aarch64-linux-gnu-
ls -l uniLoader.img*                 # compare against the TEXT_BASE window
```

---

## 7. Environment notes

- **Samsung downstream tree is not in WSL.** It lives at `C:\Users\randward\android_kernel_samsung_sm8250` (NTFS, empty working tree, `.git` intact on `lineage-23.2`). Read it from WSL with `git --git-dir=/mnt/c/Users/randward/android_kernel_samsung_sm8250/.git archive|show` — read-only works even with an empty working tree. Mainline trees: `C:\Users\randward\mainline`, `mainline-backup`.
- `/home/randward` was wiped once and recreated root-owned; `chown randward` from a root WSL session before recreating directories.
- **Never edit files on the WSL 9P/UNC path with `sed -i` / `cat >` / `echo >`** — it produces corrupt symlink/inode artifacts (e.g. an unremovable `drivers/kernelsu` with `Input/output error`). Inside WSL on ext4 this does not apply; `git apply` and normal editors are fine.
- Toolchain: `/home/randward/proton-clang/bin` is clang 13 — fine for uniLoader, **too old for mainline 6.x**; use `gcc-aarch64-linux-gnu` or clang ≥ 15 there.
- `git push` from WSL can hang on Windows Git Credential Manager; push from PowerShell instead.
- Windows git cannot check out trees containing `aux.c` (reserved device name, nouveau has one) — extract such trees from the WSL side via `git --git-dir=... archive | tar`.
- Very long `adb shell "..."` one-liners can trip the terminal command parser; split them or run a script file instead.
