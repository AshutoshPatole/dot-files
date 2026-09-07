#!/usr/bin/env bash
#
# Copyright 2026 Ashutosh Patole
#
# Automated one-shot setup script for development environment and dotfiles.
# Supports both macOS and Linux (Debian/Ubuntu, Fedora/RHEL, Arch Linux).
# Adheres to Google Shell Style Guide best practices.

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
# Helper Functions
# ==============================================================================

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

One-shot automated development environment and dotfiles installer.
Configures symlinks, installs core CLI tools, Oh My Zsh, Powerlevel10k, and plugins.
Supports macOS and Linux.

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

# Runs a command with sudo if available and necessary.
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
    log_info "Installing packages via Homebrew..."
    if [[ "${DRY_RUN}" == true ]]; then
      log_info "[DRY-RUN] brew install ${CORE_PACKAGES[*]}"
      return 0
    fi
    for pkg in "${CORE_PACKAGES[@]}"; do
      if brew list "${pkg}" >/dev/null 2>&1; then
        log_info "Package '${pkg}' is already installed."
      else
        log_info "Installing '${pkg}'..."
        brew install "${pkg}" || log_warn "Failed to install '${pkg}' via brew."
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

    # On Debian/Ubuntu, bat is often packaged as batcat; symlink batcat -> bat if needed
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
      log_info "Symlinking batcat to ~/.local/bin/bat for Debian/Ubuntu compatibility..."
      if [[ "${DRY_RUN}" == false ]]; then
        mkdir -p "${HOME}/.local/bin"
        ln -sf "$(command -v batcat)" "${HOME}/.local/bin/bat"
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

# Installs Oh My Zsh if not already present.
install_oh_my_zsh() {
  if [[ "${SKIP_OMZ}" == true ]]; then
    log_info "Skipping Oh My Zsh setup (--skip-omz specified)."
    return 0
  fi

  local omz_dir="${HOME}/.oh-my-zsh"
  if [[ -d "${omz_dir}" ]]; then
    log_info "Oh My Zsh is already installed at: ${omz_dir}"
    return 0
  fi

  log_info "Installing Oh My Zsh unattended..."
  if [[ "${DRY_RUN}" == true ]]; then
    log_info "[DRY-RUN] curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh"
    return 0
  fi

  # Run unattended without overriding existing .zshrc or automatically switching shell
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  log_success "Oh My Zsh installed successfully."
}

# Clones or updates Powerlevel10k and custom plugins.
install_zsh_plugins() {
  if [[ "${SKIP_OMZ}" == true ]]; then
    return 0
  fi

  local zsh_custom="${ZSH_CUSTOM:-"${HOME}/.oh-my-zsh/custom"}"
  local p10k_dir="${zsh_custom}/themes/powerlevel10k"
  local autosuggest_dir="${zsh_custom}/plugins/zsh-autosuggestions"
  local syntax_dir="${zsh_custom}/plugins/zsh-syntax-highlighting"

  # 1. Powerlevel10k theme
  if [[ -d "${p10k_dir}" ]]; then
    log_info "Powerlevel10k theme already installed at: ${p10k_dir}"
  else
    log_info "Cloning Powerlevel10k theme..."
    if [[ "${DRY_RUN}" == false ]]; then
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${p10k_dir}"
      log_success "Powerlevel10k installed."
    else
      log_info "[DRY-RUN] git clone powerlevel10k to ${p10k_dir}"
    fi
  fi

  # 2. zsh-autosuggestions
  if [[ -d "${autosuggest_dir}" ]]; then
    log_info "Plugin zsh-autosuggestions already installed."
  else
    log_info "Cloning zsh-autosuggestions..."
    if [[ "${DRY_RUN}" == false ]]; then
      git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${autosuggest_dir}"
      log_success "zsh-autosuggestions installed."
    else
      log_info "[DRY-RUN] git clone zsh-autosuggestions to ${autosuggest_dir}"
    fi
  fi

  # 3. zsh-syntax-highlighting
  if [[ -d "${syntax_dir}" ]]; then
    log_info "Plugin zsh-syntax-highlighting already installed."
  else
    log_info "Cloning zsh-syntax-highlighting..."
    if [[ "${DRY_RUN}" == false ]]; then
      git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "${syntax_dir}"
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
#   $2: Destination path at system location
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
    mkdir -p "${dest_dir}"
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
    rm -f "${dest}"
  # Destination is a regular file or directory (not a symlink)
  elif [[ -e "${dest}" ]]; then
    local backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
    log_warn "Existing file/directory found at ${dest}. Backing up to ${backup}"
    mv "${dest}" "${backup}"
  fi

  ln -s "${source}" "${dest}"
  log_success "Linked: ${dest} -> ${source}"
}

# Sets up all project dotfile symlinks.
setup_symlinks() {
  log_info "Configuring dotfile symlinks from ${SCRIPT_DIR}..."

  # Neovim config
  create_symlink "${SCRIPT_DIR}/nvim" "${HOME}/.config/nvim"

  # Tmux config (both XDG ~/.config/tmux/tmux.conf and classic ~/.tmux.conf)
  create_symlink "${SCRIPT_DIR}/tmux.conf" "${HOME}/.config/tmux/tmux.conf"
  create_symlink "${SCRIPT_DIR}/tmux.conf" "${HOME}/.tmux.conf"

  # Zsh configs
  create_symlink "${SCRIPT_DIR}/zshrc" "${HOME}/.zshrc"
  create_symlink "${SCRIPT_DIR}/zprofile" "${HOME}/.zprofile"

  # Powerlevel10k theme configuration (if present)
  if [[ -f "${SCRIPT_DIR}/p10k.zsh" ]]; then
    create_symlink "${SCRIPT_DIR}/p10k.zsh" "${HOME}/.p10k.zsh"
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

  if [[ "${SHELL:-}" != *"/zsh" ]]; then
    log_info "Note: Current default shell is ${SHELL:-unknown}."
    log_info "To set zsh as your default shell, run:"
    printf "    %bchsh -s %s%b\n" "${COLOR_BOLD}" "${zsh_path}" "${COLOR_RESET}"
  else
    log_success "Zsh is already your default shell."
  fi
}

# ==============================================================================
# Main Routine
# ==============================================================================

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -d | --dry-run)
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

  printf "%b=======================================================%b\n" "${COLOR_BOLD}" "${COLOR_RESET}"
  printf "%b Dotfiles & Environment Setup Script%b\n" "${COLOR_BOLD}" "${COLOR_RESET}"
  printf "%b Source: %s%b\n" "${COLOR_BLUE}" "${SCRIPT_DIR}" "${COLOR_RESET}"
  printf "%b=======================================================%b\n" "${COLOR_BOLD}" "${COLOR_RESET}"

  install_packages
  install_oh_my_zsh
  install_zsh_plugins
  setup_symlinks
  verify_shell

  printf "\n%b✔ Setup complete!%b Open a new shell or run %bsource ~/.zshrc%b to apply.\n" \
    "${COLOR_GREEN}" "${COLOR_RESET}" "${COLOR_BOLD}" "${COLOR_RESET}"
}

main "$@"
