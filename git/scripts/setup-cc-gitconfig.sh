#!/usr/bin/env bash
# Setup Git config for AWS CodeCommit HTTPS (Git Bash / Windows).
# Clears system credential.helper=manager so AWS CLI credential-helper can auth
# without a username/password dialog. Prefer --fix-system or --migrate + bashrc NOSYSTEM.

set -euo pipefail

BACKUP_DIR="${HOME}/gitconfig-backups"
DO_FIX_SYSTEM=0
DO_MIGRATE=0
PROBE_KEY="setup.cc.gitconfig.probe"
BASHRC_MARKER="# managed-by: setup-cc-gitconfig.sh"
GLOBAL_GITCONFIG="${HOME}/.gitconfig"
USER_BASHRC="${HOME}/.bashrc"

print_help() {
  cat <<EOF
Usage: $(basename "$0") [options]

Prepare Git for CodeCommit HTTPS with AWS CLI credential-helper
(no GCM username/password dialog). Default is check-only.
Mutating flags back up configs first.

Options:
  --fix-system       Unset credential.helper in system gitconfig (if writable)
  --migrate          Merge system settings into existing global (skip GCM),
                     append GIT_CONFIG_NOSYSTEM=1 to existing ~/.bashrc
                     Requires ~/.gitconfig and ~/.bashrc (does not create them)
  --backup-dir DIR   Backup directory (default: ~/gitconfig-backups)
  -h, --help         Show this help and exit

Exit codes:
  0  No effective manager/manager-core helper, or --migrate succeeded
  1  Effective manager still active (see Recommendation)
  2  Usage error, missing prereqs, git missing, or unexpected failure

Policy:
  1) Writable system  -> unset system credential.helper (--fix-system)
  2) Read-only system -> --migrate (merge system->global, enable NOSYSTEM in ~/.bashrc)
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

is_gcm_helper() {
  local val="$1"
  case "$val" in
    manager|manager-core|manager-core.exe|git-credential-manager|git-credential-manager.exe|git-credential-manager-core|git-credential-manager-core.exe)
      return 0
      ;;
    *git-credential-manager*)
      return 0
      ;;
  esac
  return 1
}

# Apply credential.helper empty-reset semantics (get-all does not).
effective_helpers() {
  local helper
  local -a helpers=()
  while IFS= read -r helper; do
    if [[ "$helper" == "" ]]; then
      helpers=()
      continue
    fi
    helpers+=("$helper")
  done < <(git config --get-all credential.helper 2>/dev/null || true)

  if ((${#helpers[@]} > 0)); then
    printf '%s\n' "${helpers[@]}"
  fi
}

effective_has_manager() {
  local helper
  while IFS= read -r helper; do
    [[ -z "$helper" ]] && continue
    if is_gcm_helper "$helper"; then
      return 0
    fi
  done < <(effective_helpers)
  return 1
}

system_config_path() {
  local origin path
  # Prefer an explicit list entry: file:<path><tab>key=value
  origin="$(git config --system --list --show-origin 2>/dev/null | head -n1 || true)"
  if [[ -n "$origin" ]]; then
    path="$(printf '%s\n' "$origin" | sed -E 's/^file:([^[:space:]]+).*/\1/')"
    if [[ -n "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
  fi
  return 1
}

can_write_system() {
  if git config --system --add "$PROBE_KEY" 1 2>/dev/null; then
    git config --system --unset-all "$PROBE_KEY" 2>/dev/null || true
    return 0
  fi
  git config --system --unset-all "$PROBE_KEY" 2>/dev/null || true
  return 1
}

backup_file() {
  local src="$1"
  local label="$2"
  local stamp dest
  [[ -f "$src" ]] || return 0
  mkdir -p "$BACKUP_DIR"
  stamp="$(date +%Y%m%d-%H%M%S)"
  dest="${BACKUP_DIR}/gitconfig.${label}.${stamp}.bak"
  cp -v "$src" "$dest"
}

backup_configs() {
  local sys_path global_path
  sys_path="$(system_config_path 2>/dev/null || true)"
  global_path="$(git config --global --list --show-origin 2>/dev/null | head -n1 | sed -E 's/^file:([^[:space:]]+).*/\1/' || true)"
  if [[ -z "$global_path" && -f "${HOME}/.gitconfig" ]]; then
    global_path="${HOME}/.gitconfig"
  fi
  if [[ -n "$sys_path" ]]; then
    backup_file "$sys_path" "system"
  fi
  if [[ -n "$global_path" ]]; then
    backup_file "$global_path" "global"
  fi
}

print_section() {
  log ""
  log "== $* =="
}

print_credential_section() {
  local scope="$1"
  print_section "${scope} credential.*"
  if ! git config --"${scope}" --get-regexp '^credential\.' 2>/dev/null; then
    log "(none or unreadable)"
  fi
}

windows_user_nosystem() {
  # Returns User env value, or empty if unset / not Windows.
  local val
  if ! command -v cmd.exe >/dev/null 2>&1; then
    return 1
  fi
  val="$(cmd.exe //c "if defined GIT_CONFIG_NOSYSTEM (echo %GIT_CONFIG_NOSYSTEM%) else (echo __UNSET__)" 2>/dev/null | tr -d '\r' | tail -n1)"
  if [[ -z "$val" || "$val" == "__UNSET__" || "$val" == "%GIT_CONFIG_NOSYSTEM%" ]]; then
    return 1
  fi
  printf '%s\n' "$val"
  return 0
}

print_nosystem_status() {
  print_section "GIT_CONFIG_NOSYSTEM status"
  log "shell GIT_CONFIG_NOSYSTEM=${GIT_CONFIG_NOSYSTEM-<unset>}"
  log "shell GIT_CONFIG_SYSTEM=${GIT_CONFIG_SYSTEM-<unset>}"

  local user_val
  if user_val="$(windows_user_nosystem)"; then
    log "Windows User env GIT_CONFIG_NOSYSTEM=${user_val}"
    if [[ -n "${GIT_CONFIG_NOSYSTEM:-}" && "${GIT_CONFIG_NOSYSTEM}" != "${user_val}" ]]; then
      warn "Shell and Windows User GIT_CONFIG_NOSYSTEM differ"
    fi
  else
    if command -v cmd.exe >/dev/null 2>&1; then
      log "Windows User env GIT_CONFIG_NOSYSTEM=<unset>"
      if [[ -n "${GIT_CONFIG_NOSYSTEM:-}" ]]; then
        warn "GIT_CONFIG_NOSYSTEM is set in this shell (e.g. ~/.bashrc) but not as a Windows User env var"
      fi
    else
      log "Windows User env check skipped (cmd.exe not available)"
    fi
  fi
}

fix_system_helpers() {
  print_section "Fixing system credential.helper"
  if ! can_write_system; then
    err "No write permission on system gitconfig; use --migrate instead"
    return 1
  fi
  if git config --system --get-all credential.helper >/dev/null 2>&1; then
    git config --system --unset-all credential.helper
    log "Unset system credential.helper"
  else
    log "System credential.helper already absent"
  fi
}

is_skipped_migrate_key() {
  local key="$1"
  local val="$2"
  if [[ "$key" == "$PROBE_KEY" ]]; then
    return 0
  fi
  if [[ "$key" == "credential.helper" ]] && is_gcm_helper "$val"; then
    return 0
  fi
  return 1
}

require_migrate_prereqs() {
  local missing=0
  if [[ ! -f "$GLOBAL_GITCONFIG" ]]; then
    err "Global gitconfig not found: ${GLOBAL_GITCONFIG}"
    warn "Create ~/.gitconfig first, then re-run --migrate"
    missing=1
  fi
  if [[ ! -f "$USER_BASHRC" ]]; then
    err "bashrc not found: ${USER_BASHRC}"
    warn "Create ~/.bashrc first, then re-run --migrate"
    missing=1
  fi
  if [[ "$missing" -ne 0 ]]; then
    return 1
  fi
  return 0
}

bashrc_has_nosystem() {
  grep -Eq '^[[:space:]]*export[[:space:]]+GIT_CONFIG_NOSYSTEM=' "$USER_BASHRC" 2>/dev/null \
    || grep -Eq '^[[:space:]]*GIT_CONFIG_NOSYSTEM=' "$USER_BASHRC" 2>/dev/null
}

append_nosystem_to_bashrc() {
  print_section "Persist GIT_CONFIG_NOSYSTEM in ~/.bashrc"
  if bashrc_has_nosystem; then
    log "GIT_CONFIG_NOSYSTEM already present in ${USER_BASHRC}"
  else
    {
      printf '\n%s\n' "$BASHRC_MARKER"
      printf 'export GIT_CONFIG_NOSYSTEM=1\n'
    } >> "$USER_BASHRC"
    log "Added GIT_CONFIG_NOSYSTEM=1 to ${USER_BASHRC}"
  fi

  log ""
  log "Reload your shell, then re-run this script:"
  log "  source ~/.bashrc"
  log "  # or close/reopen Git Bash"
}

migrate_system_to_global() {
  local key val count skipped
  print_section "Migrating system -> global"
  count=0
  skipped=0

  if ! git config --system --list >/dev/null 2>&1; then
    err "Unable to read system gitconfig"
    return 1
  fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    val="${line#*=}"

    if is_skipped_migrate_key "$key" "$val"; then
      log "skip: ${key}=${val}"
      skipped=$((skipped + 1))
      continue
    fi

    if git config --global --get-all "$key" 2>/dev/null | grep -Fxq -- "$val" || false; then
      continue
    fi

    git config --global --add "$key" "$val"
    log "add:  ${key}=${val}"
    count=$((count + 1))
  done < <(git config --system --list)

  log "Migrated ${count} value(s); skipped ${skipped} GCM/probe value(s)"
  log "Global settings preserved (merge-only; nothing deleted)"

  append_nosystem_to_bashrc
}

recommend_action() {
  local writable="$1"
  print_section "Recommendation"
  if effective_has_manager; then
    if [[ "$writable" == "yes" ]]; then
      log "System gitconfig is writable."
      log "Run: $0 --fix-system"
    else
      log "System gitconfig is read-only."
      log "Run: $0 --migrate"
      log "This merges system settings into ~/.gitconfig and enables GIT_CONFIG_NOSYSTEM in ~/.bashrc."
    fi
  else
    log "No effective GCM manager helper detected."
    if [[ -n "${GIT_CONFIG_NOSYSTEM:-}" ]]; then
      warn "OK depends on GIT_CONFIG_NOSYSTEM (system config ignored)"
    fi
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        print_help
        exit 0
        ;;
      --fix-system)
        DO_FIX_SYSTEM=1
        shift
        ;;
      --migrate)
        DO_MIGRATE=1
        shift
        ;;
      --backup-dir)
        if [[ $# -lt 2 ]]; then
          err "--backup-dir requires a directory"
          exit 2
        fi
        BACKUP_DIR="$2"
        shift 2
        ;;
      *)
        err "Unknown option: $1"
        print_help
        exit 2
        ;;
    esac
  done

  if [[ "$DO_FIX_SYSTEM" -eq 1 && "$DO_MIGRATE" -eq 1 ]]; then
    err "Use either --fix-system or --migrate, not both"
    exit 2
  fi
}

main() {
  parse_args "$@"

  if ! command -v git >/dev/null 2>&1; then
    err "git is not installed or not on PATH"
    exit 2
  fi

  log "Git config credential check"
  log "git: $(git --version)"

  local sys_path writable
  sys_path="$(system_config_path 2>/dev/null || true)"
  if [[ -n "$sys_path" ]]; then
    log "system gitconfig: ${sys_path}"
  else
    warn "Could not resolve system gitconfig path"
  fi

  if can_write_system; then
    writable="yes"
    log "system write permission: yes"
  else
    writable="no"
    log "system write permission: no"
  fi

  if [[ "$DO_MIGRATE" -eq 1 ]]; then
    require_migrate_prereqs || exit 2
  fi

  if [[ "$DO_FIX_SYSTEM" -eq 1 || "$DO_MIGRATE" -eq 1 ]]; then
    print_section "Backup"
    backup_configs
  fi

  if [[ "$DO_FIX_SYSTEM" -eq 1 ]]; then
    fix_system_helpers || exit 2
  fi

  if [[ "$DO_MIGRATE" -eq 1 ]]; then
    migrate_system_to_global || exit 2
  fi

  print_credential_section system
  print_credential_section global

  print_section "Effective credential.helper (after empty-reset rules)"
  local eff
  eff="$(effective_helpers)"
  if [[ -n "$eff" ]]; then
    printf '%s\n' "$eff"
  else
    log "(none)"
  fi
  log ""
  log "-- raw values with origins (before empty-reset rules) --"
  git config --list --show-origin 2>/dev/null | grep -i credential.helper || log "(none)"

  print_section "Effective system gitconfig origins"
  if [[ -n "$sys_path" ]] && git config --list --show-origin 2>/dev/null | grep -Fq "file:${sys_path}"; then
    log "SYSTEM CONFIG IS ACTIVE in effective config"
    git config --list --show-origin 2>/dev/null | grep -F "file:${sys_path}" || true
  elif git config --list --show-origin 2>/dev/null | grep -q 'etc/gitconfig'; then
    log "SYSTEM CONFIG IS ACTIVE in effective config"
    git config --list --show-origin 2>/dev/null | grep 'etc/gitconfig' || true
  else
    log "System gitconfig not present in effective config"
  fi

  print_nosystem_status
  recommend_action "$writable"

  # --migrate succeeds even if this session still sees system manager (reload required).
  if [[ "$DO_MIGRATE" -eq 1 ]]; then
    print_section "Result"
    log "OK: migrate complete; reload shell for GIT_CONFIG_NOSYSTEM to take effect"
    exit 0
  fi

  if effective_has_manager; then
    print_section "Result"
    log "FAIL: credential.helper manager is still effective"
    log "See Recommendation above (--fix-system or --migrate)."
    exit 1
  fi

  if [[ -n "${GIT_CONFIG_NOSYSTEM:-}" ]]; then
    warn "Passing with GIT_CONFIG_NOSYSTEM set (system config ignored)"
  fi

  print_section "Result"
  log "OK: no effective credential.helper manager"
  exit 0
}

main "$@"
