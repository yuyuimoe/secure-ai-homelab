#!/usr/bin/env bash
# KVM / nested-virtualization preflight.
#
# Answers one question in four steps: does THIS host have usable KVM hardware
# acceleration, and if not, which layer is blocking it?
#
#   1. Where am I?      guest VM, container, or bare metal (and which hypervisor)
#   2. CPU flag         does the CPU advertise vmx (Intel) / svm (AMD)?
#   3. Kernel modules   is kvm_intel/kvm_amd loadable, and what does dmesg say?
#   4. Device + test    does /dev/kvm exist and can a real KVM guest start?
#
# The verdict distinguishes the two cases that look alike but are NOT:
#   * "just disabled"  -> flags/module/device are fixable by you (needs root)
#   * "not exposed"    -> the hypervisor withholds it; only your VPS provider
#                         can enable nested virtualization. No guest-side switch.
#
# Usage:
#   scripts/check-kvm.sh            # no root required, read-only
#   scripts/check-kvm.sh --load     # + try `modprobe kvm_intel|kvm_amd` (root)
#   scripts/check-kvm.sh --test     # + start a throwaway QEMU with -accel kvm
#
# Exit codes: 0 = KVM usable, 1 = KVM not usable, 2 = bad usage.

set -uo pipefail

LOAD=0
TEST=0
for arg in "$@"; do
  case "$arg" in
    --load) LOAD=1 ;;
    --test) TEST=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; sed -n '2,24p' "$0" >&2; exit 2 ;;
  esac
done

if [[ -t 1 ]]; then
  R=$'\033[0m'; B=$'\033[1m'; OK=$'\033[32m'; BAD=$'\033[31m'
  WARN=$'\033[33m'; INFO=$'\033[36m'
else
  R=; B=; OK=; BAD=; WARN=; INFO=
fi

pass()  { printf '  %sPASS%s  %s\n' "$OK" "$R" "$1"; }
fail()  { printf '  %sFAIL%s  %s\n' "$BAD" "$R" "$1"; }
warn()  { printf '  %sWARN%s  %s\n' "$WARN" "$R" "$1"; }
info()  { printf '  %sINFO%s  %s\n' "$INFO" "$R" "$1"; }
note()  { printf '        %s\n' "$1"; }
section() { printf '\n%s%s%s\n' "$B" "$1" "$R"; }

# --- 1. where am I ---------------------------------------------------------

detect_virt() { # systemd-detect-virt exits non-zero when it finds nothing
  local v
  v="$(systemd-detect-virt ${1:-} 2>/dev/null)"
  printf '%s' "${v:-none}"
}
VIRT="$(detect_virt)"
CONTAINER="$(detect_virt -c)"
DMI_VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
DMI_PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
CPU_VENDOR="$(awk -F: '/vendor_id/{gsub(/ /,"",$2); print $2; exit}' /proc/cpuinfo)"

section "1. Where am I"
info "virtualization : ${VIRT}"
info "container      : ${CONTAINER}"
info "DMI vendor     : ${DMI_VENDOR:-unknown}"
info "DMI product    : ${DMI_PRODUCT:-unknown}"
info "CPU vendor     : ${CPU_VENDOR:-unknown}"

IN_CONTAINER=0
[[ "$CONTAINER" != "none" && "$CONTAINER" != "unknown" ]] && IN_CONTAINER=1
IN_GUEST=0
[[ "$VIRT" != "none" && "$VIRT" != "unknown" ]] && IN_GUEST=1

if (( IN_CONTAINER )); then
  note "A /dev/kvm missing here usually means the runtime just did not pass it"
  note "through. That is fixed by the caller, not by this container:"
  note "  podman run --device /dev/kvm ...   /   docker run --device /dev/kvm ..."
fi
if (( IN_GUEST )); then
  note "This host is itself a guest (${VIRT}). Nested virtualization must be"
  note "granted by the hypervisor underneath it."
fi

# --- 2. CPU virtualization flag -------------------------------------------

section "2. CPU virtualization flag"
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
  FLAG=vmx; MODULE=kvm_intel
elif [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
  FLAG=svm; MODULE=kvm_amd
else
  FLAG=""; MODULE=""
  warn "Unrecognised CPU vendor '${CPU_VENDOR:-?}'; assuming Intel spelling"
  FLAG=vmx; MODULE=kvm_intel
fi

if grep -qw "$FLAG" /proc/cpuinfo; then
  pass "CPU advertises '${FLAG}' in /proc/cpuinfo"
  HAVE_FLAG=1
else
  fail "CPU does NOT advertise '${FLAG}' in /proc/cpuinfo" \
       "The hypervisor is masking the virtualization extension. Nothing inside"
  note "this guest can turn it back on — see the verdict below."
  HAVE_FLAG=0
fi
note "lscpu says: $(lscpu 2>/dev/null | awk -F: '/Virtualization:/{gsub(/^ +/,"",$2); print $2; exit}' || echo 'n/a')"

# --- 3. kernel modules ----------------------------------------------------

section "3. Kernel modules"
LSCONF="$(lsmod 2>/dev/null || true)"
if grep -q "^kvm " <<<"$LSCONF"; then
  pass "kvm core module loaded"
  HAVE_KVM=1
else
  HAVE_KVM=0
  if (( HAVE_FLAG )); then
    warn "kvm core module not loaded"
    if (( LOAD )); then
      if [[ "$(id -u)" == "0" ]]; then
        modprobe kvm && modprobe "$MODULE" 2>/dev/null
      else
        sudo modprobe kvm && sudo modprobe "$MODULE" 2>/dev/null
      fi
      if grep -q "^kvm " <<<"$(lsmod 2>/dev/null)"; then
        pass "kvm now loaded (you ran --load)"
        HAVE_KVM=1
      else
        fail "modprobe kvm failed" "See dmesg output below."
      fi
    else
      note "Re-run with --load (as root) to try loading it."
    fi
  else
    note "Meaningless without the CPU flag: the module cannot bind without ${FLAG}."
  fi
fi

if grep -qE "^kvm_(intel|amd) " <<<"$LSCONF" || grep -qE "^kvm_(intel|amd) " <<<"$(lsmod 2>/dev/null)"; then
  pass "${MODULE} loaded"
else
  (( HAVE_KVM )) && warn "${MODULE} not loaded"
fi

DMESG="$( { dmesg 2>/dev/null || sudo -n dmesg 2>/dev/null; } | grep -iE 'kvm|vmx|svm' | tail -15 )"
if [[ -n "$DMESG" ]]; then
  note "recent dmesg:"
  while IFS= read -r line; do note "  $line"; done <<<"$DMESG"
fi
if grep -qiE 'disabled by bios|VMX not enabled|not supported by CPU' <<<"$DMESG"; then
  note "^^ that message is the decisive one: the firmware/hypervisor refused it."
fi

# --- 4. device node + real test -------------------------------------------

section "4. /dev/kvm device"
if [[ -c /dev/kvm ]]; then
  DEV_PERM="$(stat -c '%A %U:%G' /dev/kvm 2>/dev/null)"
  pass "/dev/kvm exists (${DEV_PERM})"
  HAVE_DEV=1
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    pass "current user can read/write /dev/kvm"
  else
    warn "current user cannot rw /dev/kvm"
    note "Fix: sudo usermod -aG kvm \"\$(id -un)\"  (then re-login)"
  fi
else
  HAVE_DEV=0
  if (( HAVE_KVM )); then
    warn "/dev/kvm missing although kvm is loaded (udev/mdev issue)"
  else
    fail "/dev/kvm does not exist"
  fi
fi

if (( TEST )); then
  if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    warn "--test given but qemu-system-x86_64 is not installed"
    note "Debian/Ubuntu: sudo apt install qemu-system-x86"
  elif (( HAVE_DEV )); then
    QERR="$(mktemp)"
    if qemu-system-x86_64 -accel kvm -machine q35 -m 128 -S -display none \
         -monitor none -serial none -daemonize -pidfile /tmp/.kvm-check.pid \
         2>"$QERR"; then
      pass "a KVM-accelerated guest started successfully (-accel kvm)"
      kill "$(cat /tmp/.kvm-check.pid)" 2>/dev/null
      rm -f /tmp/.kvm-check.pid
    else
      fail "QEMU could not start with -accel kvm"
      while IFS= read -r line; do note "  $line"; done <"$QERR"
    fi
    rm -f "$QERR"
  else
    warn "--test skipped: no usable /dev/kvm"
  fi
fi

# --- verdict ---------------------------------------------------------------

section "Verdict"
if (( HAVE_FLAG && HAVE_DEV )); then
  printf '  %sKVM is usable.%s KVM-accelerated VMs (QEMU/KVM, Firecracker, Kata, microVMs) can run here.\n' "$OK" "$R"
  exit 0
fi

if (( ! HAVE_FLAG )); then
  printf '  %sNOT FIXABLE FROM INSIDE.%s The CPU never advertises %s — the hypervisor is hiding it.\n' "$BAD" "$R" "$FLAG"
  echo
  echo "  On a VPS this is a provider-side setting. There is no guest-side switch:"
  echo "    * look for a 'nested virtualization' / 'nested virt' toggle in the"
  echo "      provider's control panel or API for this server, or"
  echo "    * open a ticket asking them to expose VMX/SVM for your instance."
  echo
  echo "  If your provider cannot enable it, the guest will never have KVM."
  if (( IN_GUEST )); then
    echo "  You are a guest of '${VIRT}' — confirm with: dmesg | head -20"
  fi
  exit 1
fi

printf '  %sDISABLED, BUT POSSIBLY FIXABLE.%s The CPU supports %s; the blocker is on this host.\n' "$WARN" "$R" "$FLAG"
echo
echo "  Try, in order:"
echo "    1. scripts/check-kvm.sh --load            (load kvm/${MODULE})"
echo "    2. check the kernel shipped the module:"
echo "         modinfo ${MODULE}                    (Debian: apt install linux-image-amd64)"
echo "    3. if you own the host, make sure nesting is on:"
echo "         cat /sys/module/${MODULE}/parameters/nested      # want Y"
echo "         echo 'options ${MODULE} nested=1' | sudo tee /etc/modprobe.d/kvm.conf"
echo "    4. if it is a container, pass the device through from the caller:"
echo "         --device /dev/kvm"
exit 1
