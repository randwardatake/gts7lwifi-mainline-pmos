# Adreno 650 (a650 / SM8250) ACD levels — from downstream

Source: `arch/arm64/boot/dts/vendor/qcom/kona-v2-gpu.dtsi` (lineage-23.2,
Samsung android_kernel_samsung_sm8250). Property: `qcom,acd-level` per pwrlevel.

| GPU freq (MHz) | qcom,acd-level |
|---|---|
| 525 – 670      | `0x802b5ffd`   |
| 305 – 490      | `0xa02b5ffd`   |

Downstream Samsung stock **tops at 670 MHz** (speed-bin 1). The 800–940 MHz
figures in enthusiast writeups come from KonaBess *adding* pwrlevels on top,
reusing the 670 ACD value (0x802b5ffd) — on the Android/KGSL stack.

Mainline uses these via the OPP property `qcom,opp-acd-level` (parsed by
`a6xx_gmu_acd_probe`). The GMU node needs `qcom,qmp = <&aoss_qmp>` (present
in sm8250.dtsi). OPPs without an ACD level run ACD-off (fine up to 670).
