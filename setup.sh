#!/usr/bin/env bash
#
# Copyright 2026 Ashutosh Patole
#
# Automated one-shot setup script for development environment and dotfiles.
# Supports both macOS and Linux (Debian/Ubuntu, Fedora/RHEL, Arch Linux).
# Adheres to Google Shell Style Guide best practices.
#
# Handles execution both as a standard user (prompting for sudo only when
# installing system packages) and via sudo (safely delegating user-space
# configurations like Oh My Zsh and symlinks to the invoking non-root user).

set -euo pipefail

# ==============================================================================
# Global Constants & Paths
# ==============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Terminal color escape codes
readonly COLOR_RESET=$'\033[0m'
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[0;33m'
readonly COLOR_BLUE=$'\033[0;34m'
readonly COLOR_BOLD=$'\033[1m'

# Default CLI packages to install
readonly CORE_PACKAGES=(
  git
  curl
  zsh
  tmux
  neovim
  fzf
  bat
  eza
)

# Flag options
DRY_RUN=false
SKIP_PACKAGES=false
SKIP_OMZ=false

# Target user identification (populated by init_target_user)
TARGET_USER=""
TARGET_HOME=""
TARGET_GROUP=""
IS_SUDO_INVOCATION=false

# ==============================================================================
# Logging Utilities
# ==============================================================================

log_info() {
  printf "%b[INFO]%b %s\n" "${COLOR_BLUE}" "${COLOR_RESET}" "$*"
}

log_success() {
  printf "%b[SUCCESS]%b %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$*"
}

log_warn() {
  printf "%b[WARN]%b %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$*" >&2
}

log_error() {
  printf "%b[ERROR]%b %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$*" >&2
}

# ==============================================================================
# Target User & Privilege Management
# ==============================================================================

# Determines the actual non-root user and home directory to configure.
# If invoked via 'sudo ./setup.sh', preserves SUDO_USER so user configs
# are never written to /root.
init_target_user() {
  if [[ "${EUID}" -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]] && [[ "${SUDO_USER}" != "root" ]]; then
    TARGET_USER="${SUDO_USER}"
    IS_SUDO_INVOCATION=true
  else
    TARGET_USER="$(id -un)"
    IS_SUDO_INVOCATION=false
  fi

  # Resolve TARGET_HOME reliably across Linux (getent), macOS (dscl), and fallback
  TARGET_HOME=""
  if command -v getent >/dev/null 2>&1; then
    TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
  fi
  if [[ -z "${TARGET_HOME}" ]] && command -v dscl >/dev/null 2>&1; then
    TARGET_HOME="$(dscl . -read "/Users/${TARGET_USER}" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
  fi
  if [[ -z "${TARGET_HOME}" ]]; then
    TARGET_HOME="$(eval echo "~${TARGET_USER}")"
  fi

  # Resolve primary group for TARGET_USER
  TARGET_GROUP="$(id -gn "${TARGET_USER}" 2>/dev/null || echo "${TARGET_USER}")"
}

# Runs a command with root privileges (using sudo only if not already root).
run_as_root() {
  if [[ "${DRY_RUN}" == true ]]; then
    log_info "[DRY-RUN] (root) $*"
    return 0
  fi

  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    log_error "Root privileges are required for: $*"
    return 1
  fi
}

# Runs a command as the TARGET_USER. If the script was started via sudo,
# drops privileges so files created in TARGET_HOME are owned by TARGET_USER.
run_as_target_user() {
  if [[ "${DRY_RUN}" == true ]]; then
    log_info "[DRY-RUN] (${TARGET_USER}) $*"
    return 0
  fi

  if [[ "${EUID}" -eq 0 ]] && [[ "${TARGET_USER}" != "root" ]]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo -u "${TARGET_USER}" -H "$@"
    elif command -v runuser >/dev/null 2>&1; then
      runuser -u "${TARGET_USER}" -- "$@"
    elif command -v su >/dev/null 2>&1; then
      su -s /bin/bash "${TARGET_USER}" -c "$(printf "%q " "$@")"
    else
      "$@"
    fi
  else
    "$@"
  fi
}

# ==============================================================================
# Helper Functions
# ==============================================================================

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

One-shot automated development environment and dotfiles installer.
Configures symlinks, installs core CLI tools, Oh My Zsh, Powerlevel10k, and plugins.
Supports macOS and Linux.

NOTE: You do NOT need to run this script with sudo directly.
Running as a normal user (./${SCRIPT_NAME}) will prompt for sudo only when
installing system packages. If run with sudo, it automatically configures
the invoking user's home directory instead of /root.

OPTIONS:
  -h, --help           Show this help message and exit.
  -d, --dry-run        Print actions that would be performed without making changes.
  --skip-packages      Skip package manager installations (brew/apt/dnf/pacman).
  --skip-omz           Skip Oh My Zsh and plugin installations.

EXAMPLES:
  ./${SCRIPT_NAME}
  ./${SCRIPT_NAME} --skip-packages
  ./${SCRIPT_NAME} --dry-run
EOF
}

# Detects underlying operating system.
detect_os() {
  local os_type
  os_type="$(uname -s)"
  case "${os_type}" in
    Darwin)
      echo "macos"
      ;;
    Linux)
      echo "linux"
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}

# Detects primary package manager available on the system.
detect_package_manager() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  else
    echo "none"
  fi
}

# ==============================================================================
# Package Installation
# ==============================================================================

# Installs core CLI packages depending on OS and available package manager.
install_packages() {
  if [[ "${SKIP_PACKAGES}" == true ]]; then
    log_info "Skipping system package installation (--skip-packages specified)."
    return 0
  fi

  local os_type
  os_type="$(detect_os)"
  local pkg_mgr
  pkg_mgr="$(detect_package_manager)"

  log_info "Detected OS: ${os_type} (Package manager: ${pkg_mgr})"

  case "${pkg_mgr}" in
    brew)
      log_info "Installing packages via Homebrew (as ${TARGET_USER})..."
      if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY-RUN] brew install ${CORE_PACKAGES[*]}"
        return 0
      fi
      for pkg in "${CORE_PACKAGES[@]}"; do
        if run_as_target_user brew list "${pkg}" >/dev/null 2>&1; then
          log_info "Package '${pkg}' is already installed."
        else
          log_info "Installing '${pkg}'..."
          run_as_target_user brew install "${pkg}" || log_warn "Failed to install '${pkg}' via brew."
        fi
      done
      ;;

    apt)
      log_info "Updating apt package list..."
      run_as_root apt-get update -y || log_warn "apt-get update encountered issues."

      local apt_packages=(git curl zsh tmux neovim fzf bat)
      for pkg in "${apt_packages[@]}"; do
        if dpkg -s "${pkg}" >/dev/null 2>&1; then
          log_info "Package '${pkg}' is already installed."
        else
          log_info "Installing '${pkg}' via apt..."
          run_as_root apt-get install -y "${pkg}" || log_warn "Could not install '${pkg}'."
        fi
      done

      # On Debian/Ubuntu, bat is often packaged as batcat; symlink batcat -> bat in user's bin
      if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        log_info "Symlinking batcat to ${TARGET_HOME}/.local/bin/bat for Debian/Ubuntu compatibility..."
        if [[ "${DRY_RUN}" == false ]]; then
          run_as_target_user mkdir -p "${TARGET_HOME}/.local/bin"
          run_as_target_user ln -sf "$(command -v batcat)" "${TARGET_HOME}/.local/bin/bat"
        fi
      fi

      # Attempt to install eza if available in repos
      if ! command -v eza >/dev/null 2>&1; then
        run_as_root apt-get install -y eza >/dev/null 2>&1 || {
          log_warn "'eza' is not available in standard apt repositories on this distribution."
          log_warn "Refer to https://github.com/eza-community/eza/blob/main/INSTALL.md to install eza."
        }
      fi
      ;;

    pacman)
      log_info "Installing packages via pacman..."
      run_as_root pacman -Syu --needed --noconfirm "${CORE_PACKAGES[@]}" || {
        log_warn "pacman encountered issues installing some packages."
      }
      ;;

    dnf)
      log_info "Installing packages via dnf..."
      run_as_root dnf install -y "${CORE_PACKAGES[@]}" || {
        log_warn "dnf encountered issues installing some packages."
      }
      ;;

    none)
      log_warn "No supported package manager (brew/apt/dnf/pacman) detected."
      log_warn "Please ensure git, zsh, tmux, neovim, bat, and eza are installed manually."
      ;;
  esac
}

# ==============================================================================
# Oh My Zsh & Plugins Setup
# ==============================================================================

# Installs Oh My Zsh for TARGET_USER if not already present.
install_oh_my_zsh() {
  if [[ "${SKIP_OMZ}" == true ]]; then
    log_info "Skipping Oh My Zsh setup (--skip-omz specified)."
    return 0
  fi

  local omz_dir="${TARGET_HOME}/.oh-my-zsh"
  if [[ -d "${omz_dir}" ]]; then
    log_info "Oh My Zsh is already installed at: ${omz_dir}"
    return 0
  fi

  log_info "Installing Oh My Zsh unattended for user '${TARGET_USER}'..."
  if [[ "${DRY_RUN}" == true ]]; then
    log_info "[DRY-RUN] curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh"
    return 0
  fi

  # Run unattended without overriding existing .zshrc or automatically switching shell
  run_as_target_user env HOME="${TARGET_HOME}" USER="${TARGET_USER}" \
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  log_success "Oh My Zsh installed successfully for '${TARGET_USER}'."
}

# Clones or updates Powerlevel10k and custom plugins in TARGET_HOME.
install_zsh_plugins() {
  if [[ "${SKIP_OMZ}" == true ]]; then
    return 0
  fi

  local zsh_custom="${TARGET_HOME}/.oh-my-zsh/custom"
  local p10k_dir="${zsh_custom}/themes/powerlevel10k"
  local autosuggest_dir="${zsh_custom}/plugins/zsh-autosuggestions"
  local syntax_dir="${zsh_custom}/plugins/zsh-syntax-highlighting"

  # 1. Powerlevel10k theme
  if [[ -d "${p10k_dir}" ]]; then
    log_info "Powerlevel10k theme already installed at: ${p10k_dir}"
  else
    log_info "Cloning Powerlevel10k theme for '${TARGET_USER}'..."
    if [[ "${DRY_RUN}" == false ]]; then
      run_as_target_user git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${p10k_dir}"
      log_success "Powerlevel10k installed."
    else
      log_info "[DRY-RUN] git clone powerlevel10k to ${p10k_dir}"
    fi
  fi

  # 2. zsh-autosuggestions
  if [[ -d "${autosuggest_dir}" ]]; then
    log_info "Plugin zsh-autosuggestions already installed."
  else
    log_info "Cloning zsh-autosuggestions for '${TARGET_USER}'..."
    if [[ "${DRY_RUN}" == false ]]; then
      run_as_target_user git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${autosuggest_dir}"
      log_success "zsh-autosuggestions installed."
    else
      log_info "[DRY-RUN] git clone zsh-autosuggestions to ${autosuggest_dir}"
    fi
  fi

  # 3. zsh-syntax-highlighting
  if [[ -d "${syntax_dir}" ]]; then
    log_info "Plugin zsh-syntax-highlighting already installed."
  else
    log_info "Cloning zsh-syntax-highlighting for '${TARGET_USER}'..."
    if [[ "${DRY_RUN}" == false ]]; then
      run_as_target_user git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${syntax_dir}"
      log_success "zsh-syntax-highlighting installed."
    else
      log_info "[DRY-RUN] git clone zsh-syntax-highlighting to ${syntax_dir}"
    fi
  fi
}

# ==============================================================================
# Symlink Management
# ==============================================================================

# Creates or updates a symbolic link pointing to a target file or directory.
# If a regular file/directory already exists, creates a timestamped backup.
#
# Arguments:
#   $1: Source path in dotfiles repo
#   $2: Destination path in TARGET_HOME
create_symlink() {
  local source="$1"
  local dest="$2"

  if [[ ! -e "${source}" ]]; then
    log_warn "Source '${source}' does not exist, skipping."
    return 0
  fi

  local dest_dir
  dest_dir="$(dirname "${dest}")"

  if [[ "${DRY_RUN}" == true ]]; then
    log_info "[DRY-RUN] Symlink: ${dest} -> ${source}"
    return 0
  fi

  if [[ ! -d "${dest_dir}" ]]; then
    run_as_target_user mkdir -p "${dest_dir}"
  fi

  # Destination is already a symlink
  if [[ -L "${dest}" ]]; then
    local current_target
    current_target="$(readlink "${dest}")"
    if [[ "${current_target}" == "${source}" ]]; then
      log_info "Symlink already up to date: ${dest} -> ${source}"
      return 0
    fi
    log_info "Updating symlink: ${dest} -> ${source} (was ${current_target})"
    run_as_target_user rm -f "${dest}"
  # Destination is a regular file or directory (not a symlink)
  elif [[ -e "${dest}" ]]; then
    local backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "Existing file/directory found at ${dest}. Backing up to ${backup}"
    run_as_target_user mv "${dest}" "${backup}"
  fi

  run_as_target_user ln -s "${source}" "${dest}"
  log_success "Linked: ${dest} -> ${source}"
}

# Sets up all project dotfile symlinks targeting TARGET_HOME.
setup_symlinks() {
  log_info "Configuring dotfile symlinks for '${TARGET_USER}' in ${TARGET_HOME}..."

  # Neovim config
  create_symlink "${SCRIPT_DIR}/nvim" "${TARGET_HOME}/.config/nvim"

  # Tmux config (both XDG ~/.config/tmux/tmux.conf and classic ~/.tmux.conf)
  create_symlink "${SCRIPT_DIR}/tmux.conf" "${TARGET_HOME}/.config/tmux/tmux.conf"
  create_symlink "${SCRIPT_DIR}/tmux.conf" "${TARGET_HOME}/.tmux.conf"

  # Zsh configs
  create_symlink "${SCRIPT_DIR}/zshrc" "${TARGET_HOME}/.zshrc"
  create_symlink "${SCRIPT_DIR}/zprofile" "${TARGET_HOME}/.zprofile"

  # Powerlevel10k theme configuration (if present)
  if [[ -f "${SCRIPT_DIR}/p10k.zsh" ]]; then
    create_symlink "${SCRIPT_DIR}/p10k.zsh" "${TARGET_HOME}/.p10k.zsh"
  fi
}

# ==============================================================================
# Shell Verification
# ==============================================================================

verify_shell() {
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"

  if [[ -z "${zsh_path}" ]]; then
    log_warn "Zsh is not installed or not in PATH."
    return 0
  fi

  local user_shell=""
  if command -v getent >/dev/null 2>&1; then
    user_shell="$(getent passwd "${TARGET_USER}" 2>/dev/null | cut -d: -f7 || true)"
  fi
  if [[ -z "${user_shell}" ]]; then
    user_shell="${SHELL:-}"
  fi

  if [[ "${user_shell}" != *"/zsh" ]]; then
    log_info "Note: Current default shell for '${TARGET_USER}' is ${user_shell:-unknown}."
    log_info "To set zsh as the default shell, run:"
    if [[ "${EUID}" -eq 0 ]]; then
      printf "    %bchsh -s %s %s%b\n" "${COLOR_BOLD}" "${zsh_path}" "${TARGET_USER}" "${COLOR_RESET}"
    else
      printf "    %bchsh -s %s%b\n" "${COLOR_BOLD}" "${zsh_path}" "${COLOR_RESET}"
    fi
  else
    log_success "Zsh is already the default shell for '${TARGET_USER}'."
  fi
}

# ==============================================================================
# Main Routine
# ==============================================================================

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      --skip-packages)
        SKIP_PACKAGES=true
        shift
        ;;
      --skip-omz)
        SKIP_OMZ=true
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  init_target_user

  printf "%b=======================================================%b\n" "${COLOR_BOLD}" "${COLOR_RESET}"
  printf "%b Dotfiles & Environment Setup Script%b\n" "${COLOR_BOLD}" "${COLOR_RESET}"
  printf "%b Source: %s%b\n" "${COLOR_BLUE}" "${SCRIPT_DIR}" "${COLOR_RESET}"
  printf "%b Target User: %s (Home: %s)%b\n" "${COLOR_GREEN}" "${TARGET_USER}" "${TARGET_HOME}" "${COLOR_RESET}"
  if [[ "${IS_SUDO_INVOCATION}" == true ]]; then
    printf "%b [SUDO INVOCATION DETECTED]%b System packages -> root; User configs -> %s\n" \
      "${COLOR_YELLOW}" "${COLOR_RESET}" "${TARGET_USER}"
  fi
  printf "%b=======================================================%b\n" "${COLOR_BOLD}" "${COLOR_RESET}"

  install_packages
  install_oh_my_zsh
  install_zsh_plugins
  setup_symlinks
  verify_shell

  printf "\n%b✔ Setup complete for %s!%b Open a new shell or run %bsource ~/.zshrc%b to apply.\n" \
    "${COLOR_GREEN}" "${TARGET_USER}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_RESET}"
}

main "$@"
