#!/bin/sh
# CPU performans karsilastirma: schedutil (varsayilan) vs performance. sudo ile calistir.
GPU=$(ls -d /sys/class/devfreq/*gpu* 2>/dev/null | head -1)
setg(){ for p in /sys/devices/system/cpu/cpufreq/policy*; do echo "$1" > "$p/scaling_governor"; done; }
maxt(){ for z in /sys/class/thermal/thermal_zone*/temp; do cat "$z"; done | sort -rn | head -1 | awk '{printf "%.0f",$1/1000}'; }
run(){ sysbench cpu --cpu-max-prime=20000 --threads=8 --time=15 run 2>/dev/null | awk -F: '/events per second/{gsub(/ /,"",$2);print $2}'; }
pf(){ echo $(( $(cat /sys/devices/system/cpu/cpufreq/policy7/scaling_cur_freq)/1000 ))MHz; }
echo "===== VARSAYILAN (schedutil) ====="; setg schedutil; sleep 2
echo "CPU olay/sn: $(run)   maxT=$(maxt)C   prime=$(pf)"
echo "===== PERFORMANS MODU ====="; setg performance; [ -n "$GPU" ] && echo performance > "$GPU/governor"; sleep 2
echo "CPU olay/sn: $(run)   maxT=$(maxt)C   prime=$(pf)"
[ -n "$GPU" ] && echo "GPU: cur=$(( $(cat $GPU/cur_freq)/1000000 ))MHz max=$(( $(cat $GPU/max_freq)/1000000 ))MHz"
echo "===== geri: schedutil (varsayilan) ====="; setg schedutil; [ -n "$GPU" ] && echo simple_ondemand > "$GPU/governor"
echo "bitti."
