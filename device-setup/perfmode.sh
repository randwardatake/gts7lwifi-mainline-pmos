#!/bin/sh
# gts7 performans profili: CPU governor + GPU devfreq
# Kullanim: perfmode.sh [on|off|status]
GPU="$(ls -d /sys/class/devfreq/*gpu* 2>/dev/null | head -1)"
MODE="${1:-status}"
cpu_gov(){ for p in /sys/devices/system/cpu/cpufreq/policy*; do echo "$1" | sudo tee "$p/scaling_governor" >/dev/null; done; }
temps(){ for z in /sys/class/thermal/thermal_zone*/temp; do awk '{printf "%.0f ",$1/1000}' "$z"; done | tr ' ' '\n' | sort -rn | head -1; }
case "$MODE" in
  on)  cpu_gov performance; [ -n "$GPU" ] && echo performance | sudo tee "$GPU/governor" >/dev/null; echo "== PERFORMANS MODU: ACIK ==";;
  off) cpu_gov schedutil;   [ -n "$GPU" ] && echo simple_ondemand | sudo tee "$GPU/governor" >/dev/null; echo "== PERFORMANS MODU: KAPALI (varsayilan) ==";;
esac
echo "CPU gov : $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor) (little) / $(cat /sys/devices/system/cpu/cpufreq/policy7/scaling_governor) (prime)"
echo "CPU freq: little=$(( $(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_cur_freq)/1000 ))MHz  big=$(( $(cat /sys/devices/system/cpu/cpufreq/policy4/scaling_cur_freq)/1000 ))MHz  prime=$(( $(cat /sys/devices/system/cpu/cpufreq/policy7/scaling_cur_freq)/1000 ))MHz"
[ -n "$GPU" ] && echo "GPU     : gov=$(cat $GPU/governor) cur=$(( $(cat $GPU/cur_freq)/1000000 ))MHz max=$(( $(cat $GPU/max_freq)/1000000 ))MHz"
echo "En sicak zone: $(temps)C"
