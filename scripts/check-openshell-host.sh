#!/usr/bin/env bash
# OpenShell host preflight.
#
# Checks whether this host (your VPS) can run the OpenShell sandbox boundary.
# OpenShell's support matrix requires four kernel facilities, "including when
# it runs inside a container or microVM":
#
#   1. Landlock LSM        (ABI 3+, Linux 6.2+)
#   2. seccomp             (nested user-notification filters +
#                           SECCOMP_IOCTL_NOTIF_ADDFD with SECCOMP_ADDFD_FLAG_SEND)
#   3. task-memory access  (process_vm_readv or /proc/<pid>/mem)
#   4. socket device bind  (SO_BINDTODEVICE on loopback)
#
# Usage:
#   scripts/check-openshell-host.sh              # static checks (no root, no compiler)
#   scripts/check-openshell-host.sh --probe      # + compile and run tiny C probes
#   scripts/check-openshell-host.sh --container  # + repeat probes inside a rootless container
#   scripts/check-openshell-host.sh --probe --container
#
# Exit codes: 0 = no hard failures, 1 = at least one hard failure, 2 = bad usage.
#
# NOTE: this is a static check plus syscall probes. The authoritative test is
# OpenShell's own probe, which runs when you create your first sandbox. If the
# checks here pass but `openshell sandbox create` fails, trust OpenShell.

set -uo pipefail

PROBE=0
CONTAINER=0
for arg in "$@"; do
  case "$arg" in
    --probe) PROBE=1 ;;
    --container) CONTAINER=1; PROBE=1 ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; sed -n '2,32p' "$0"; exit 2 ;;
  esac
done

if [[ -t 1 ]]; then
  R=$'\033[0m'; B=$'\033[1m'; OK=$'\033[32m'; BAD=$'\033[31m'
  WARN=$'\033[33m'; SKIP=$'\033[36m'
else
  R=; B=; OK=; BAD=; WARN=; SKIP=
fi

PASS_N=0; FAIL_N=0; WARN_N=0; SKIP_N=0
pass() { PASS_N=$((PASS_N+1)); printf '  %sPASS%s  %s\n' "$OK" "$R" "$1"; }
fail() { FAIL_N=$((FAIL_N+1)); printf '  %sFAIL%s  %s\n' "$BAD" "$R" "$1"; [[ -n ${2:-} ]] && printf '        %s\n' "$2"; }
warn() { WARN_N=$((WARN_N+1)); printf '  %sWARN%s  %s\n' "$WARN" "$R" "$1"; [[ -n ${2:-} ]] && printf '        %s\n' "$2"; }
skip() { SKIP_N=$((SKIP_N+1)); printf '  %sSKIP%s  %s\n' "$SKIP" "$R" "$1"; }
note() { printf '        %s\n' "$1"; }
section() { printf '\n%s%s%s\n' "$B" "$1" "$R"; }

# --- kernel helpers --------------------------------------------------------

kern_ge() { # kern_ge <current-release> <wanted major.minor>
  local cur=${1%%-*} want=$2
  local cmaj cremain cmin wmaj wmin
  cmaj=${cur%%.*}; cremain=${cur#*.}; cmin=${cremain%%.*}
  wmaj=${want%%.*}; wmin=${want#*.}
  (( cmaj > wmaj )) && return 0
  (( cmaj == wmaj && cmin >= wmin )) && return 0
  return 1
}

kernel_config() {
  if [[ -r /proc/config.gz ]]; then zcat /proc/config.gz 2>/dev/null && return
  elif [[ -r "/boot/config-$(uname -r)" ]]; then cat "/boot/config-$(uname -r)" && return
  elif [[ -r "/lib/modules/$(uname -r)/config" ]]; then cat "/lib/modules/$(uname -r)/config" && return
  fi
  return 1
}

KREL="$(uname -r)"
ARCH="$(uname -m)"
KCONF=""; KCONF_SOURCE="unavailable"
if KCONF="$(kernel_config)"; then
  if [[ -r /proc/config.gz ]]; then KCONF_SOURCE="/proc/config.gz"
  elif [[ -r "/boot/config-$(uname -r)" ]]; then KCONF_SOURCE="/boot/config-$(uname -r)"
  else KCONF_SOURCE="/lib/modules/$(uname -r)/config"; fi
fi
kconf_has() { [[ -n $KCONF ]] && grep -qE "^$1=(y|m)" <<<"$KCONF"; }

# --- probe machinery (defined before use) ---------------------------------

PROBE_DIR=""
CC=""
cleanup() { [[ -n $PROBE_DIR && -d $PROBE_DIR ]] && rm -rf "$PROBE_DIR"; return 0; }
trap cleanup EXIT

ensure_probe_dir() { [[ -n $PROBE_DIR ]] || PROBE_DIR="$(mktemp -d)"; }
pick_cc() { local c; for c in cc gcc clang; do command -v "$c" >/dev/null 2>&1 && { CC=$c; return 0; }; done; return 1; }

compile_probe() { # <name>
  local name=$1 src out extra=""
  src="$PROBE_DIR/$name.c"; out="$PROBE_DIR/$name"
  [[ -f $src ]] || return 1
  [[ $CONTAINER == 1 ]] && extra="-static"
  $CC -O2 -w $extra -o "$out" "$src" 2>"$PROBE_DIR/$name.build.log"
}

run_probe() { # <name>; exit 127 when no compiler is available
  local name=$1
  ensure_probe_dir; write_sources
  if [[ -z $CC ]] && ! pick_cc; then
    echo "no C compiler (cc/gcc/clang) on PATH"; return 127
  fi
  if [[ ! -x $PROBE_DIR/$name ]]; then
    compile_probe "$name" || { echo "compile failed:"; cat "$PROBE_DIR/$name.build.log" 2>/dev/null; return 127; }
  fi
  if [[ $name == bindtodevice && -n $(command -v unshare) ]]; then
    unshare --user --map-root-user --net "$PROBE_DIR/$name" 2>&1
  else
    "$PROBE_DIR/$name" 2>&1
  fi
}

write_sources() {
ensure_probe_dir
cat >"$PROBE_DIR/landlock.c" <<'EOF'
#define _GNU_SOURCE
#include <unistd.h>
#include <sys/syscall.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#ifndef SYS_landlock_create_ruleset
#define SYS_landlock_create_ruleset 444
#endif
int main(void) {
    long r = syscall(SYS_landlock_create_ruleset, (void *)0, 0, 1UL);
    if (r < 0) { fprintf(stderr, "%s", strerror(errno)); return 1; }
    printf("%ld", r);
    return 0;
}
EOF

cat >"$PROBE_DIR/seccomp.c" <<'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/ioctl.h>
#include <sys/prctl.h>
#include <linux/filter.h>
#include <linux/seccomp.h>
#include <linux/audit.h>
#ifndef SECCOMP_FILTER_FLAG_NEW_LISTENER
#define SECCOMP_FILTER_FLAG_NEW_LISTENER (1UL << 3)
#endif
#ifndef SECCOMP_ADDFD_FLAG_SEND
#define SECCOMP_ADDFD_FLAG_SEND (1U << 0)
#endif
static int install(unsigned long flags) {
    struct sock_filter insns[] = { BPF_STMT(BPF_RET | BPF_K, SECCOMP_RET_ALLOW) };
    struct sock_fprog prog = {
        .len = (unsigned short)(sizeof(insns) / sizeof(insns[0])),
        .filter = insns,
    };
    return (int)syscall(SYS_seccomp, SECCOMP_SET_MODE_FILTER, flags, &prog);
}
int main(void) {
    if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0) {
        fprintf(stderr, "no_new_privs: %s", strerror(errno)); return 10;
    }
    if (install(0) < 0) { fprintf(stderr, "baseline: %s", strerror(errno)); return 11; }
    int fd = install(SECCOMP_FILTER_FLAG_NEW_LISTENER);
    if (fd < 0) { fprintf(stderr, "nested-listener: %s", strerror(errno)); return 12; }
#ifdef SECCOMP_IOCTL_NOTIF_ADDFD
    {
        struct seccomp_notif_addfd a;
        memset(&a, 0, sizeof(a));
        a.flags = SECCOMP_ADDFD_FLAG_SEND;
        errno = 0;
        int r = ioctl(fd, SECCOMP_IOCTL_NOTIF_ADDFD, &a);
        if (r < 0 && errno == ENOTTY) {
            fprintf(stderr, "addfd-unsupported: %s", strerror(errno)); return 13;
        }
        printf("addfd-ok (%s)", r < 0 ? strerror(errno) : "ok");
    }
#else
    printf("addfd-headers-missing");
#endif
    close(fd);
    return 0;
}
EOF

cat >"$PROBE_DIR/taskmem.c" <<'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <sys/uio.h>
#include <sys/types.h>
#include <sys/wait.h>
int main(void) {
    int p[2];
    if (pipe(p) != 0) { perror("pipe"); return 1; }
    pid_t child = fork();
    if (child < 0) { perror("fork"); return 1; }
    if (child == 0) {
        char secret[32] = "openshell-probe";
        void *addr = secret;
        close(p[0]);
        if (write(p[1], &addr, sizeof addr) != (ssize_t)sizeof addr) _exit(2);
        for (;;) pause();
    }
    close(p[1]);
    void *addr = NULL;
    if (read(p[0], &addr, sizeof addr) != (ssize_t)sizeof addr) { perror("read"); kill(child, 9); return 1; }
    char buf[32];
    memset(buf, 0, sizeof buf);
    struct iovec local = { .iov_base = buf, .iov_len = sizeof buf };
    struct iovec remote = { .iov_base = addr, .iov_len = sizeof buf };
    ssize_t n = process_vm_readv(child, &local, 1, &remote, 1, 0);
    if (n < 0) {
        char path[64];
        snprintf(path, sizeof path, "/proc/%d/mem", (int)child);
        int fd = open(path, O_RDONLY);
        if (fd < 0) { fprintf(stderr, "process_vm_readv: %s; %s: %s", strerror(errno), path, strerror(errno)); kill(child, 9); return 1; }
        ssize_t m = pread(fd, buf, sizeof buf, (off_t)(intptr_t)addr);
        close(fd);
        if (m < 0) { fprintf(stderr, "pread(%s): %s", path, strerror(errno)); kill(child, 9); return 1; }
        printf("proc-mem-ok");
    } else {
        printf("process_vm_readv-ok");
    }
    kill(child, 9);
    waitpid(child, NULL, 0);
    return 0;
}
EOF

cat >"$PROBE_DIR/bindtodevice.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <net/if.h>
int main(void) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) { fprintf(stderr, "socket: %s", strerror(errno)); return 1; }
    if (setsockopt(fd, SOL_SOCKET, SO_BINDTODEVICE, "lo", 3) < 0) {
        fprintf(stderr, "SO_BINDTODEVICE: %s", strerror(errno)); return 1;
    }
    printf("bindtodevice-ok");
    return 0;
}
EOF
}

run_in_container() {
  local image="alpine:3.20" name out rc err detail
  ensure_probe_dir; write_sources
  [[ -z $CC ]] && ! pick_cc && { skip "no C compiler for the container probes"; return 0; }
  for name in landlock seccomp taskmem; do
    if ! compile_probe "$name"; then
      skip "$name: static compile failed"; continue
    fi
    err="$PROBE_DIR/$name.err"
    out="$($ENGINE run --rm -v "$PROBE_DIR:/probe:ro" "$image" "/probe/$name" 2>"$err")"; rc=$?
    if (( rc == 0 )); then
      detail=$out
      [[ $name == landlock && $out =~ ^[0-9]+$ ]] && detail="ABI $out"
      pass "$name inside $image: ${detail:-ok}"
    elif grep -qiE 'unable to find|pull access|no such image|network|dial tcp|connection refused' "$err"; then
      skip "$name: could not run $image (pull/network?)"; return 0
    else
      fail "$name inside $image failed" "$(cat "$err" 2>/dev/null) $out"
    fi
  done
  return 0
}

# --- header ----------------------------------------------------------------

printf '%sOpenShell host preflight%s\n' "$B" "$R"
printf 'kernel   %s %s\n' "$KREL" "$ARCH"
printf 'config   %s\n' "$KCONF_SOURCE"

# --- 0. environment --------------------------------------------------------

section "[0/5] Environment"

case "$ARCH" in
  x86_64|aarch64) pass "architecture $ARCH (OpenShell publishes $ARCH binaries)" ;;
  *) warn "architecture $ARCH" "OpenShell release binaries target x86_64 and aarch64" ;;
esac

if kern_ge "$KREL" "6.2"; then
  pass "kernel $KREL >= 6.2 (Landlock ABI 3 baseline)"
else
  fail "kernel $KREL < 6.2" "Landlock ABI 3 needs Linux 6.2+; OpenShell fails closed"
fi

cgroup_fs="$(stat -fc %T /sys/fs/cgroup 2>/dev/null || echo unknown)"
if [[ $cgroup_fs == cgroup2fs ]]; then
  pass "cgroups v2 mounted"
else
  warn "cgroups v2 not detected (found: $cgroup_fs)" "the Podman driver requires cgroups v2"
fi

userns_ok=1
if [[ -r /proc/sys/kernel/unprivileged_userns_clone ]] && \
   [[ "$(cat /proc/sys/kernel/unprivileged_userns_clone)" != "1" ]]; then
  userns_ok=0; fail "unprivileged user namespaces disabled" "sysctl kernel.unprivileged_userns_clone=0"
fi
if [[ -r /proc/sys/kernel/apparmor_restrict_unprivileged_userns ]] && \
   [[ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns)" != "0" ]]; then
  userns_ok=0; fail "AppArmor restricts unprivileged user namespaces" "sysctl kernel.apparmor_restrict_unprivileged_userns=0 (Ubuntu 23.10+)"
fi
if [[ -r /proc/sys/user/max_user_namespaces ]] && \
   [[ "$(cat /proc/sys/user/max_user_namespaces)" == "0" ]]; then
  userns_ok=0; fail "user.max_user_namespaces == 0" "user namespaces are disabled"
fi
(( userns_ok == 1 )) && pass "user namespaces available"

ENGINE=""
if command -v podman >/dev/null 2>&1; then
  pass "podman $(podman --version 2>/dev/null | awk '{print $3}')"; ENGINE=podman
elif command -v docker >/dev/null 2>&1; then
  pass "docker $(docker --version 2>/dev/null | awk '{print $3}' | tr -d ,)"; ENGINE=docker
else
  warn "no podman or docker on PATH" "the OpenShell gateway needs a container runtime socket"
fi

if command -v podman >/dev/null 2>&1; then
  if grep -qE "^${USER}:[0-9]+:[0-9]+" /etc/subuid 2>/dev/null && \
     grep -qE "^${USER}:[0-9]+:[0-9]+" /etc/subgid 2>/dev/null; then
    pass "subuid/subgid range present for $USER"
  else
    warn "no subuid/subgid range for $USER" "rootless containers need /etc/subuid and /etc/subgid"
  fi
fi

# --- 1. Landlock -----------------------------------------------------------

section "[1/5] Landlock LSM (filesystem)"
if [[ -r /sys/kernel/security/lsm ]]; then
  if grep -qw landlock /sys/kernel/security/lsm; then
    pass "landlock listed in /sys/kernel/security/lsm"
  else
    fail "landlock is not in the active LSM list" "/sys/kernel/security/lsm: $(cat /sys/kernel/security/lsm 2>/dev/null)"
  fi
elif [[ -d /sys/kernel/security ]]; then
  warn "cannot read /sys/kernel/security/lsm" "run as root, or probe with --probe"
else
  warn "securityfs not mounted" "mount -t securityfs none /sys/kernel/security, or probe with --probe"
fi

if [[ $PROBE == 1 ]]; then
  out="$(run_probe landlock)"; rc=$?
  if (( rc == 0 )); then
    if [[ $out =~ ^[0-9]+$ ]] && (( out >= 3 )); then
      pass "Landlock ABI $out (need >= 3)"
    else
      fail "Landlock ABI $out < 3" "upgrade the kernel to Linux 6.2+"
    fi
  elif (( rc == 127 )); then
    skip "Landlock probe skipped: $out"
  else
    fail "Landlock probe failed" "$out"
  fi
else
  note "run with --probe to read the exact Landlock ABI"
fi

# --- 2. seccomp ------------------------------------------------------------

section "[2/5] seccomp (network mediation)"
if kconf_has CONFIG_SECCOMP; then
  pass "CONFIG_SECCOMP=y"
elif [[ -n $KCONF ]]; then
  fail "CONFIG_SECCOMP not enabled" "seccomp is compiled out"
else
  skip "kernel config unavailable; cannot confirm CONFIG_SECCOMP"
fi
if kconf_has CONFIG_SECCOMP_FILTER; then
  pass "CONFIG_SECCOMP_FILTER=y"
elif [[ -n $KCONF ]]; then
  fail "CONFIG_SECCOMP_FILTER not enabled" "seccomp filters are unavailable"
else
  skip "kernel config unavailable; cannot confirm CONFIG_SECCOMP_FILTER"
fi

if kern_ge "$KREL" "6.11"; then
  pass "kernel $KREL >= 6.11 (SECCOMP_ADDFD_FLAG_SEND present upstream)"
else
  warn "kernel $KREL < 6.11" "SECCOMP_ADDFD_FLAG_SEND was added upstream in 6.11; a distro backport may still provide it — confirm with OpenShell's own probe"
fi

if [[ $PROBE == 1 ]]; then
  out="$(run_probe seccomp)"; rc=$?
  if (( rc == 0 )); then
    pass "nested seccomp user-notification filter installed"
    if grep -q '^addfd-ok' <<<"$out"; then
      pass "SECCOMP_IOCTL_NOTIF_ADDFD is wired ($(grep '^addfd-ok' <<<"$out" | sed 's/^addfd-ok //'))"
    elif grep -q '^addfd-headers-missing' <<<"$out"; then
      skip "ADDFD ioctl not tested: host headers predate the kernel's ADDFD support"
    else
      warn "ADDFD ioctl untested" "$out"
    fi
  elif (( rc == 127 )); then
    skip "seccomp probe skipped: $out"
  else
    fail "nested seccomp user-notification probe failed" "$out"
  fi
else
  note "run with --probe to install a real nested user-notification filter"
fi

# --- 3. task memory --------------------------------------------------------

section "[3/5] task-memory access"
if kern_ge "$KREL" "3.2"; then
  pass "kernel $KREL supports process_vm_readv"
else
  fail "kernel $KREL < 3.2" "process_vm_readv is unavailable"
fi
if [[ -r /proc/self/mem ]]; then
  pass "/proc/self/mem is readable (fallback path present)"
else
  warn "/proc/self/mem not readable" "check that procfs is mounted normally"
fi
if [[ -r /proc/sys/kernel/yama/ptrace_scope ]]; then
  ys="$(cat /proc/sys/kernel/yama/ptrace_scope)"
  if [[ $ys == "3" ]]; then
    fail "Yama ptrace_scope=3 blocks cross-process memory access" "OpenShell reads a same-UID child with process_vm_readv"
  else
    pass "Yama ptrace_scope=$ys (same-UID parent/child is allowed)"
  fi
else
  pass "no Yama ptrace_scope restriction"
fi

if [[ $PROBE == 1 ]]; then
  out="$(run_probe taskmem)"; rc=$?
  if (( rc == 0 )); then
    pass "task-memory probe: $out"
  elif (( rc == 127 )); then
    skip "task-memory probe skipped: $out"
  else
    fail "task-memory probe failed" "$out"
  fi
else
  note "run with --probe to read a forked child's memory for real"
fi

# --- 4. SO_BINDTODEVICE ----------------------------------------------------

section "[4/5] socket device binding (SO_BINDTODEVICE)"
if [[ $PROBE == 1 ]]; then
  out="$(run_probe bindtodevice)"; rc=$?
  if (( rc == 0 )); then
    pass "SO_BINDTODEVICE on loopback succeeded${out:+ ($out)}"
  elif (( rc == 127 )); then
    skip "SO_BINDTODEVICE probe skipped: $out"
  else
    fail "SO_BINDTODEVICE probe failed" "$out"
  fi
else
  note "run with --probe to bind a UDP socket to 'lo'"
fi

# --- 5. container profile --------------------------------------------------

section "[5/5] Inside the container runtime's seccomp profile"
if [[ $CONTAINER == 1 ]]; then
  run_in_container
else
  note "run with --container to repeat the probes under the runtime's default seccomp profile"
fi

# --- summary ---------------------------------------------------------------

printf '\n%sSummary%s  %s%d passed%s  %s%d failed%s  %s%d warned%s  %s%d skipped%s\n' \
  "$B" "$R" "$OK" "$PASS_N" "$R" "$BAD" "$FAIL_N" "$R" \
  "$WARN" "$WARN_N" "$R" "$SKIP" "$SKIP_N" "$R"

if (( FAIL_N > 0 )); then
  printf '\nThis host fails at least one OpenShell requirement. Fix the FAIL lines first.\n'
  exit 1
fi

printf '\nNo hard failures. Next: install the gateway and run one smoke-test sandbox.\n'
printf 'The authoritative check is OpenShell itself:\n'
printf '  openshell sandbox create --name preflight -- true\n'
exit 0
