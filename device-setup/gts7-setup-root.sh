#!/bin/sh
# gts7 — root kurulum (chromium ayari + guvenlik araclari). sudo ile calistir.
set -e
echo "== [1/5] Chromium flag'leri =="
cp -n /etc/chromium/chromium.conf /etc/chromium/chromium.conf.bak 2>/dev/null || true
cat > /etc/chromium/chromium.conf <<'CONF'
# gts7 tweaks: GPU rasterization/zero-copy => video/scroll'da CPU rahatlar
CHROMIUM_FLAGS="--ozone-platform-hint=auto --ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy --canvas-oop-rasterization --enable-features=CanvasOopRasterization"
CONF
echo "== [2/5] h264ify policy (YouTube -> H.264) =="
mkdir -p /etc/chromium/policies/managed
cat > /etc/chromium/policies/managed/h264ify.json <<'JSON'
{ "ExtensionInstallForcelist": [ "aeblfdkhhhdcdjpifhhbdiojplfjncoa;https://clients2.google.com/service/update2/crx" ] }
JSON
echo "== [3/5] apk update + guvenlik araclari =="
apk update
apk add nmap arp-scan masscan wavemon iw \
        wireshark tshark tcpdump \
        bettercap ettercap \
        bluez bluez-deprecated \
        hashcat john hydra \
        macchanger nftables libcap-setcap libcap-getcap
echo "== [4/5] wireshark izinleri =="
addgroup wireshark 2>/dev/null || true
adduser user wireshark 2>/dev/null || true
setcap 'cap_net_raw,cap_net_admin=eip' "$(command -v dumpcap)" 2>/dev/null || true
rc-service bluetooth start 2>/dev/null || true; rc-update add bluetooth 2>/dev/null || true
echo "== [5/5] Dogrulama =="
for t in nmap bettercap wireshark wavemon hashcat john hydra ettercap arp-scan macchanger; do
  printf "%-12s " "$t"; command -v "$t" >/dev/null && echo OK || echo EKSIK
done
echo "BITTI. Wireshark grubu icin bir kez cikis/giris gerekebilir."
