#!/bin/bash
##############################################################################
# ZZRENVCHECK INSTALLATION SCRIPT
##############################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log_info() {
    printf "${GREEN}ℹ️  %s${NC}\n" "$*"
}

log_warn() {
    printf "${YELLOW}⚠️  %s${NC}\n" "$*"
}

log_error() {
    printf "${RED}❌ %s${NC}\n" "$*"
}

log_success() {
    printf "${GREEN}✅ %s${NC}\n" "$*"
}

show_help() {
    cat << EOF
${BLUE}ZZRENVCHECK Installation Script${NC}

Installs zzrenvcheck validation.sh as a standalone command-line tool.
Works WITHOUT requiring R installation on the host system!

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --prefix DIR, -p DIR    Install to specified directory (default: ~/bin)
    --name NAME, -n NAME    Command name (default: zzrenvcheck)
    --help, -h              Show this help message

EXAMPLES:
    $0                              # Install to ~/bin/zzrenvcheck
    $0 --prefix ~/.local            # Install to ~/.local/bin/zzrenvcheck
    $0 --name check-packages        # Install as ~/bin/check-packages
    $0 -p /usr/local -n renvcheck   # Install to /usr/local/bin/renvcheck (requires sudo)

INSTALLATION STRUCTURE:
    INSTALL_DIR/
    ├── zzrenvcheck           # Main executable wrapper
    └── zzrenvcheck-modules/  # Support modules (core.sh, utils.sh, etc.)

The installed script uses shell commands (grep, sed, awk, jq, curl) to validate
R package dependencies without requiring R. Perfect for CI/CD environments.

For R-based workflows with richer output, use the R package instead:
    remotes::install_github("rgt47/zzrenvcheck")

EOF
}

# Default installation settings
INSTALL_PREFIX="$HOME"
COMMAND_NAME="zzrenvcheck"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix|-p)
            if [[ -z "${2:-}" ]]; then
                log_error "Error: --prefix requires a directory argument"
                exit 1
            fi
            INSTALL_PREFIX="$2"
            shift 2
            ;;
        --name|-n)
            if [[ -z "${2:-}" ]]; then
                log_error "Error: --name requires a command name argument"
                exit 1
            fi
            COMMAND_NAME="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            log_error "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set up installation paths
INSTALL_DIR="$INSTALL_PREFIX/bin"
INSTALL_PATH="$INSTALL_DIR/$COMMAND_NAME"
MODULES_DIR="$INSTALL_DIR/${COMMAND_NAME}-modules"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info "Installing zzrenvcheck to $INSTALL_PATH"

# Create installation directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    log_info "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

# Check if source modules exist
if [[ ! -d "$SCRIPT_DIR/modules" ]]; then
    log_error "modules/ directory not found in $SCRIPT_DIR"
    exit 1
fi

# Check for existing installation
if [[ -e "$INSTALL_PATH" ]]; then
    log_error "Installation target already exists: $INSTALL_PATH"
    log_error "Please remove it first or choose a different name/location:"
    log_error "  rm $INSTALL_PATH"
    log_error "  rm -rf $MODULES_DIR"
    log_error "  # OR"
    log_error "  $0 --prefix /different/path"
    log_error "  # OR"
    log_error "  $0 --name different-name"
    exit 1
fi

if [[ -d "$MODULES_DIR" ]]; then
    log_error "Modules directory already exists: $MODULES_DIR"
    log_error "Please remove it first: rm -rf $MODULES_DIR"
    exit 1
fi

# Copy modules directory
log_info "Copying modules directory..."
cp -r "$SCRIPT_DIR/modules" "$MODULES_DIR"

# Create wrapper script
log_info "Creating wrapper script..."
cat > "$INSTALL_PATH" << EOF
#!/bin/bash
##############################################################################
# ZZRENVCHECK - R Package Dependency Validator
##############################################################################
#
# Wrapper script created by install.sh
# This script requires NO R installation!
#
# Validates that all R packages used in code are properly declared
# in DESCRIPTION and locked in renv.lock for reproducibility.
#
# Dependencies: grep, sed, awk, jq (for JSON parsing), curl (for CRAN API)
#
##############################################################################

set -euo pipefail

# Determine installation directory
INSTALL_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="\$INSTALL_DIR/${COMMAND_NAME}-modules"

# Validate installation
if [[ ! -d "\$MODULES_DIR" ]]; then
    echo "❌ Error: Modules directory not found: \$MODULES_DIR"
    echo "❌ zzrenvcheck installation may be corrupted"
    exit 1
fi

if [[ ! -f "\$MODULES_DIR/validation.sh" ]]; then
    echo "❌ Error: validation.sh not found in \$MODULES_DIR"
    echo "❌ zzrenvcheck installation may be corrupted"
    exit 1
fi

# Execute validation script
cd "\$MODULES_DIR"
exec bash "\$MODULES_DIR/validation.sh" "\$@"
EOF

# Make executable
chmod +x "$INSTALL_PATH"

log_success "Installation complete!"
echo ""
log_info "📁 Installed to: $INSTALL_PATH"
log_info "📁 Modules in: $MODULES_DIR"
echo ""

# Test the installation
log_info "🧪 Testing installation..."
if "$INSTALL_PATH" --help > /dev/null 2>&1; then
    log_success "Installation test passed!"
else
    log_error "Installation test failed - zzrenvcheck may not work correctly"
fi

# Check if directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    log_warn "⚠️  $INSTALL_DIR is not in your PATH"
    log_warn "Add this to your shell config file (~/.bashrc, ~/.zshrc):"
    log_warn "export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    log_info "Or run zzrenvcheck with full path: $INSTALL_PATH"
else
    echo ""
    log_success "🚀 zzrenvcheck is ready! Run '$COMMAND_NAME --help' to get started"
fi

echo ""
log_info "📖 Usage examples:"
log_info "   $COMMAND_NAME --fix --strict --verbose    # Full validation + auto-fix"
log_info "   $COMMAND_NAME --no-fix --strict           # Report issues only"
log_info "   $COMMAND_NAME --fix                       # Standard mode (skip tests/)"
echo ""
log_info "💡 For R-based workflows with richer output:"
log_info "   remotes::install_github(\"rgt47/zzrenvcheck\")"
log_info "   zzrenvcheck::check_packages()"
echo ""
log_info "🗑️  To uninstall:"
log_info "   rm $INSTALL_PATH"
log_info "   rm -rf $MODULES_DIR"
