#!/usr/bin/env bash
set -euo pipefail
##############################################################################
# ZZCOLLAB VALIDATION MODULE
##############################################################################
# Package dependency validation (pure shell, no R required)
# Validates R packages in code are declared in DESCRIPTION and locked in renv.lock
#
# Can run standalone: ./validation.sh [options]
# Or as module: require_module "validation"
#
# DEPENDENCIES: core.sh (logging, utilities)
##############################################################################

# Bootstrap when run standalone (not sourced via require_module)
if [[ -z "${ZZCOLLAB_CORE_LOADED:-}" ]]; then
    # Determine zzcollab home from this script's location
    _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$_script_dir" == */modules ]]; then
        ZZCOLLAB_HOME="${_script_dir%/modules}"
    elif [[ -d "$HOME/.zzcollab" ]]; then
        ZZCOLLAB_HOME="$HOME/.zzcollab"
    else
        echo "Error: Cannot determine ZZCOLLAB_HOME" >&2
        exit 1
    fi
    export ZZCOLLAB_HOME
    export ZZCOLLAB_LIB_DIR="$ZZCOLLAB_HOME/lib"
    export ZZCOLLAB_MODULES_DIR="$ZZCOLLAB_HOME/modules"

    # Source core library directly
    source "$ZZCOLLAB_LIB_DIR/core.sh"
    unset _script_dir
else
    # Already loaded via require_module - just verify core is loaded
    require_module "core"
fi

#==============================================================================
# CONFIGURATION
#==============================================================================

BASE_PACKAGES=(base utils stats graphics grDevices methods datasets tools grid parallel)

PLACEHOLDER_PACKAGES=(
    package pkg mypackage myproject yourpackage project data result output input
    test example sample demo template local any all none NULL foo bar baz qux zzcollab
)

readonly CURRENT_PACKAGE="${CURRENT_PACKAGE:-$(grep '^Package:' DESCRIPTION 2>/dev/null | sed 's/^Package:[[:space:]]*//' || echo '')}"
[[ -n "$CURRENT_PACKAGE" ]] && PLACEHOLDER_PACKAGES+=("$CURRENT_PACKAGE")

STANDARD_DIRS=("." "R" "scripts" "analysis")
STRICT_DIRS=("." "R" "scripts" "analysis" "tests" "vignettes" "inst")
SKIP_FILES=("*/README.Rmd" "*/README.md" "*/CLAUDE.md" "*/examples/*" "*/renv/*" "*/.git/*")
FILE_EXTENSIONS=("R" "Rmd" "qmd" "Rnw")

#==============================================================================
# HELPERS
#==============================================================================

verify_description_file() {
    local desc_file="${1:-DESCRIPTION}" require_write="${2:-false}"
    [[ -f "$desc_file" ]] || { log_error "DESCRIPTION not found: $desc_file"; return 1; }
    [[ "$require_write" != "true" ]] || [[ -w "$desc_file" ]] || { log_error "DESCRIPTION not writable"; return 1; }
}

format_r_package_vector() {
    local pkgs=("$@")
    [[ ${#pkgs[@]} -eq 0 ]] && { echo "c()"; return; }
    local result="c(\"${pkgs[0]}\""
    for ((i=1; i<${#pkgs[@]}; i++)); do result+=", \"${pkgs[i]}\""; done
    echo "$result)"
}

#==============================================================================
# REMOTE VALIDATION
#==============================================================================

fetch_cran_package_info() {
    curl -sf "https://crandb.r-pkg.org/$1" 2>/dev/null
}

validate_package_on_cran() {
    fetch_cran_package_info "$1" >/dev/null 2>&1
}

validate_package_on_bioconductor() {
    curl -sf "https://www.bioconductor.org/packages/json/3.17/$1" >/dev/null 2>&1
}

validate_package_on_github() {
    [[ "$1" =~ "/" ]] || return 1
    local resp
    resp=$(curl -sf "https://api.github.com/repos/$1" 2>/dev/null)
    [[ -n "$resp" && ! "$resp" =~ "Not Found" ]]
}

is_installable_package() {
    local pkg="$1"
    validate_package_on_cran "$pkg" && { log_debug "  $pkg (CRAN)"; return 0; }
    validate_package_on_bioconductor "$pkg" && { log_debug "  $pkg (Bioc)"; return 0; }
    validate_package_on_github "$pkg" && { log_debug "  $pkg (GitHub)"; return 0; }
    log_debug "  $pkg (not found)"
    return 1
}

#==============================================================================
# DESCRIPTION MODIFICATION
#==============================================================================

add_package_to_description() {
    local pkg="$1" desc_file="DESCRIPTION"
    verify_description_file "$desc_file" true || return 1

    # Check if package already exists (avoid duplicates)
    if grep -qE "^[[:space:]]*${pkg}[,[:space:]]*$|^[[:space:]]*${pkg}$" "$desc_file"; then
        log_info "$pkg already in DESCRIPTION"
        return 0
    fi

    local temp_desc; temp_desc=$(mktemp)
    cp "$desc_file" "$temp_desc"

    awk -v pkg="$pkg" '
    BEGIN { in_imports=0; added=0; found=0 }
    /^Imports:/ { found=1; in_imports=1; print; next }
    in_imports && /^[A-Z]/ {
        if (!added && last != "") {
            if (last !~ /,$/) last = last ","
            print last
        }
        if (!added) { print "    " pkg ","; added=1 }
        in_imports=0; print; next
    }
    in_imports { if (last != "") print last; last=$0; next }
    { print }
    END {
        if (in_imports && !added) {
            if (last != "") { if (last !~ /,$/) last = last ","; print last }
            print "    " pkg; added=1
        }
        if (!found && !added) { print "Imports:"; print "    " pkg }
    }
    ' "$temp_desc" > "$desc_file" && rm "$temp_desc" && log_success "Added $pkg to DESCRIPTION" || {
        mv "$temp_desc" "$desc_file"; log_error "Failed to update DESCRIPTION"; return 1
    }
}

remove_unused_packages_from_description() {
    local strict_mode="${1:-false}"
    verify_description_file "DESCRIPTION" true || return 1

    local dirs=("${STANDARD_DIRS[@]}")
    [[ "$strict_mode" == "true" ]] && dirs=("${STRICT_DIRS[@]}")

    local code_packages_raw; mapfile -t code_packages_raw < <(extract_code_packages "${dirs[@]}")
    local code_packages; mapfile -t code_packages < <(clean_packages "${code_packages_raw[@]}")
    local desc_packages=(); while IFS= read -r p; do desc_packages+=("$p"); done < <(parse_description_imports)

    local unused=()
    for pkg in "${desc_packages[@]}"; do
        [[ -z "$pkg" || "$pkg" == "renv" ]] && continue
        local found=false
        for cp in "${code_packages[@]}"; do [[ "$pkg" == "$cp" ]] && { found=true; break; }; done
        [[ "$found" == false ]] && unused+=("$pkg")
    done

    [[ ${#unused[@]} -eq 0 ]] && return 0

    log_info "Removing ${#unused[@]} unused packages from DESCRIPTION"
    local pattern=""
    for p in "${unused[@]}"; do
        [[ -z "$pattern" ]] && pattern="$p" || pattern="$pattern|$p"
    done

    local tmp; tmp=$(mktemp)
    awk -v pattern="^[[:space:]]*(${pattern})[[:space:],]*\$" '
    /^Imports:/ { in_imports=1; print; next }
    in_imports { if (/^[A-Z]/) { in_imports=0; print; next }; if ($0 !~ pattern) print; next }
    { print }
    ' DESCRIPTION > "$tmp" && mv "$tmp" DESCRIPTION
    log_success "Removed unused packages"
}

#==============================================================================
# RENV.LOCK MODIFICATION
#==============================================================================

add_package_to_renv_lock() {
    local pkg="$1" renv_lock="renv.lock"
    [[ -f "$renv_lock" ]] || { log_error "renv.lock not found"; return 1; }

    local pkg_info; pkg_info=$(fetch_cran_package_info "$pkg")
    [[ -z "$pkg_info" ]] && { log_error "Failed to fetch $pkg from CRAN"; return 1; }

    local version; version=$(echo "$pkg_info" | jq -r '.Version // empty' 2>/dev/null)
    [[ -z "$version" ]] && { log_error "Could not get version for $pkg"; return 1; }

    local entry; entry=$(jq -n --arg p "$pkg" --arg v "$version" \
        '{Package:$p, Version:$v, Source:"Repository", Repository:"CRAN"}')

    local tmp; tmp=$(mktemp)
    jq --argjson e "$entry" --arg p "$pkg" '.Packages[$p] = $e' "$renv_lock" > "$tmp" && \
        mv "$tmp" "$renv_lock" && log_success "Added $pkg ($version) to renv.lock" || {
        rm -f "$tmp"; log_error "Failed to update renv.lock"; return 1
    }
}

update_renv_version_from_docker() {
    local base_image="$1" renv_lock="renv.lock"
    [[ -z "$base_image" ]] && { log_error "Docker image not specified"; return 1; }
    [[ -f "$renv_lock" ]] || return 0
    command -v jq &>/dev/null || return 0

    local ver; ver=$(docker run --rm "$base_image" R --slave -e "cat(as.character(packageVersion('renv')))" 2>/dev/null)
    [[ -z "$ver" ]] && return 0

    local tmp; tmp=$(mktemp)
    jq --arg v "$ver" '.Packages.renv.Version=$v | .Packages.renv.Source="Repository" | .Packages.renv.Repository="CRAN"' \
        "$renv_lock" > "$tmp" && mv "$tmp" "$renv_lock" && log_success "Updated renv to $ver"
}

# shellcheck disable=SC2120
create_renv_lock() {
    local r_ver="${1:-4.5.1}" cran="${2:-https://cloud.r-project.org}"
    command -v jq &>/dev/null || { log_error "jq required"; return 1; }
    jq -n --arg r "$r_ver" --arg c "$cran" \
        '{R:{Version:$r,Repositories:[{Name:"CRAN",URL:$c}]},Packages:{}}' > renv.lock && \
        log_success "Created renv.lock (R $r_ver)"
}

remove_unused_packages_from_renv_lock() {
    local strict_mode="${1:-false}"
    local renv_lock="renv.lock"
    [[ -f "$renv_lock" ]] || { log_error "renv.lock not found"; return 1; }
    command -v jq &>/dev/null || { log_error "jq required"; return 1; }

    local dirs=("${STANDARD_DIRS[@]}")
    [[ "$strict_mode" == "true" ]] && dirs=("${STRICT_DIRS[@]}")

    local code_packages_raw; mapfile -t code_packages_raw < <(extract_code_packages "${dirs[@]}")
    local code_packages; mapfile -t code_packages < <(clean_packages "${code_packages_raw[@]}")
    local renv_packages; mapfile -t renv_packages < <(parse_renv_lock)

    local code_str=" ${code_packages[*]} "
    local unused=()
    for pkg in "${renv_packages[@]}"; do
        [[ -z "$pkg" || "$pkg" == "renv" ]] && continue
        [[ "$code_str" != *" $pkg "* ]] && unused+=("$pkg")
    done

    [[ ${#unused[@]} -eq 0 ]] && return 0

    log_info "Removing ${#unused[@]} unused packages from renv.lock"

    local tmp; tmp=$(mktemp)
    local jq_filter='.'
    for p in "${unused[@]}"; do
        jq_filter="$jq_filter | del(.Packages[\"$p\"])"
    done

    if jq "$jq_filter" "$renv_lock" > "$tmp" && mv "$tmp" "$renv_lock"; then
        log_success "Removed ${#unused[@]} unused packages from renv.lock"
    else
        rm -f "$tmp"
        log_error "Failed to update renv.lock"
        return 1
    fi
}

#==============================================================================
# CODE SCANNING
#==============================================================================

extract_code_packages() {
    local dirs=("$@")
    local find_pattern="" exclude=""
    for ext in "${FILE_EXTENSIONS[@]}"; do
        [[ -n "$find_pattern" ]] && find_pattern="$find_pattern -o"
        find_pattern="$find_pattern -name \"*.$ext\""
    done
    for skip in "${SKIP_FILES[@]}"; do exclude="$exclude ! -path '$skip'"; done

    while IFS= read -r file; do
        [[ -f "$file" ]] || continue
        grep -v '^[[:space:]]*#' "$file" 2>/dev/null | grep -E '(library|require)[[:space:]]*\(' 2>/dev/null | \
            sed -E 's/.*(library|require)[[:space:]]*\([[:space:]]*["\047]?([a-zA-Z][a-zA-Z0-9.]*)["\047]?[[:space:]]*\).*/\2/' || true
        grep -v '^[[:space:]]*#' "$file" 2>/dev/null | grep -oE '[a-zA-Z][a-zA-Z0-9.]*::' 2>/dev/null | sed 's/:://' || true
        grep -E "#'[[:space:]]*@importFrom[[:space:]]+[a-zA-Z]" "$file" 2>/dev/null | \
            sed -E 's/.*@importFrom[[:space:]]+([a-zA-Z0-9.]+).*/\1/' || true
        grep -E "#'[[:space:]]*@import[[:space:]]+[a-zA-Z]" "$file" 2>/dev/null | \
            sed -E 's/.*@import[[:space:]]+([a-zA-Z0-9.]+).*/\1/' || true
    done < <(eval "find ${dirs[*]} -type f \( $find_pattern \) $exclude 2>/dev/null")
}

clean_packages() {
    local pkgs=("$@") cleaned=()
    local base_str=" ${BASE_PACKAGES[*]} " placeholder_str=" ${PLACEHOLDER_PACKAGES[*]} "

    for pkg in "${pkgs[@]}"; do
        [[ -z "$pkg" || ${#pkg} -lt 3 ]] && continue
        [[ "$base_str" == *" $pkg "* ]] && continue
        [[ "$placeholder_str" == *" $pkg "* ]] && continue
        case "$pkg" in my|your|his|her|our|their|the|this|that) continue;; esac
        case "$pkg" in file|dir|path|name|value|object|function|method|class) continue;; esac
        [[ "$pkg" =~ ^[a-zA-Z][a-zA-Z0-9.]*$ && ! "$pkg" =~ ^\. && ! "$pkg" =~ \.$ ]] && cleaned+=("$pkg")
    done
    printf '%s\n' "${cleaned[@]}" | sort -u
}

#==============================================================================
# DESCRIPTION/RENV PARSING
#==============================================================================

parse_description_field() {
    local field="$1"
    [[ -f "DESCRIPTION" ]] || return 0
    awk -v f="$field" '
    BEGIN { in_field=0; content="" }
    $0 ~ "^"f":" { in_field=1; content=$0; next }
    in_field && /^[[:space:]]/ { content=content " " $0; next }
    in_field && /^[A-Z]/ { in_field=0 }
    END {
        if (content) {
            gsub("^"f":[[:space:]]*", "", content)
            gsub(/\([^)]*\)/, "", content)
            gsub(/[[:space:]]+/, " ", content)
            gsub(/,/, "\n", content)
            print content
        }
    }
    ' DESCRIPTION | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u
}

parse_description_imports() { parse_description_field "Imports"; }
parse_description_suggests() { parse_description_field "Suggests"; }

parse_renv_lock() {
    command -v jq &>/dev/null || { log_warn "jq not found"; return 0; }
    [[ -f "renv.lock" ]] || { create_renv_lock || return 1; }
    jq -r '.Packages | keys[]' renv.lock 2>/dev/null | grep -v '^$' | sort -u || true
}

#==============================================================================
# VALIDATION LOGIC
#==============================================================================

compute_union_packages() {
    local -n code_ref="code_packages" desc_ref="desc_imports" renv_ref="renv_packages"
    local all=() base_str=" ${BASE_PACKAGES[*]} "

    for p in "${code_ref[@]}"; do [[ -n "$p" ]] && all+=("$p"); done
    for p in "${desc_ref[@]}"; do
        [[ -z "$p" ]] && continue
        local found=false; for e in "${all[@]}"; do [[ "$p" == "$e" ]] && { found=true; break; }; done
        [[ "$found" == false ]] && all+=("$p")
    done
    for p in "${renv_ref[@]}"; do
        [[ -z "$p" || "$base_str" == *" $p "* ]] && continue
        local found=false; for e in "${all[@]}"; do [[ "$p" == "$e" ]] && { found=true; break; }; done
        [[ "$found" == false ]] && all+=("$p")
    done
    printf '%s\n' "${all[@]}"
}

find_missing_from_description() {
    local -n all_ref="$1" desc_ref="$2"
    local desc_str=" ${desc_ref[*]} "
    for p in "${all_ref[@]}"; do
        [[ -n "$p" && "$desc_str" != *" $p "* ]] && echo "$p"
    done
}

find_missing_from_lock() {
    local -n all_ref="$1" renv_ref="$2"
    local renv_str=" ${renv_ref[*]} " base_str=" ${BASE_PACKAGES[*]} "
    for p in "${all_ref[@]}"; do
        [[ -z "$p" || "$base_str" == *" $p "* ]] && continue
        [[ "$renv_str" != *" $p "* ]] && echo "$p"
    done
}

report_and_fix_missing_description() {
    local -n missing_ref="$1"
    local verbose="$2" auto_fix="$3"
    local filtered=()
    for p in "${missing_ref[@]}"; do [[ -n "$p" ]] && filtered+=("$p"); done
    [[ ${#filtered[@]} -eq 0 ]] && return 0

    log_error "Found ${#filtered[@]} packages missing from DESCRIPTION"
    [[ "$verbose" == "true" || "$auto_fix" == "true" ]] && { echo ""; printf '  - %s\n' "${filtered[@]}"; echo ""; }

    if [[ "$auto_fix" == "true" ]]; then
        local failed=()
        for p in "${filtered[@]}"; do add_package_to_description "$p" || failed+=("$p"); done
        [[ ${#failed[@]} -eq 0 ]] && { log_success "All packages added to DESCRIPTION"; return 0; }
        log_error "Failed: ${failed[*]}"; return 1
    fi
    echo "Fix: zzcollab validate --fix"; return 1
}

report_and_fix_missing_lock() {
    local -n missing_ref="$1"
    local verbose="$2" auto_fix="$3"
    local filtered=()
    for p in "${missing_ref[@]}"; do [[ -n "$p" ]] && filtered+=("$p"); done
    [[ ${#filtered[@]} -eq 0 ]] && return 0

    log_info "Validating ${#filtered[@]} packages..."
    local installable=() non_installable=()
    for p in "${filtered[@]}"; do
        is_installable_package "$p" && installable+=("$p") || non_installable+=("$p")
    done

    [[ ${#installable[@]} -gt 0 ]] && log_error "Found ${#installable[@]} installable packages missing from renv.lock"
    [[ ${#non_installable[@]} -gt 0 ]] && log_warn "Found ${#non_installable[@]} non-installable packages (skipped)"

    if [[ "$verbose" == "true" || "$auto_fix" == "true" ]]; then
        [[ ${#installable[@]} -gt 0 ]] && { echo ""; echo "Installable:"; printf '  - %s\n' "${installable[@]}"; }
        [[ ${#non_installable[@]} -gt 0 ]] && { echo ""; echo "Non-installable:"; printf '  - %s\n' "${non_installable[@]}"; }
        echo ""
    fi

    if [[ "$auto_fix" == "true" && ${#installable[@]} -gt 0 ]]; then
        local failed=()
        for p in "${installable[@]}"; do add_package_to_renv_lock "$p" || failed+=("$p"); done
        [[ ${#failed[@]} -eq 0 ]] && { log_success "All installable packages added to renv.lock"; } || \
            { log_error "Failed: ${failed[*]}"; }
    elif [[ ${#installable[@]} -gt 0 ]]; then
        echo "Fix: zzcollab validate --fix"
    fi

    [[ ${#non_installable[@]} -gt 0 ]] && {
        echo ""; echo "Non-installable packages need manual installation:"
        echo "  GitHub: remotes::install_github('owner/repo')"
        echo "  Bioc: BiocManager::install('pkg')"
        echo "  Then: renv::snapshot()"
    }

    [[ ${#installable[@]} -eq 0 ]] && return 0
    [[ "$auto_fix" != "true" ]] && return 1
    [[ ${#failed[@]} -eq 0 ]]
}

validate_package_environment() {
    local strict="${1:-false}" auto_fix="${2:-false}" verbose="${3:-false}"
    log_info "Validating package dependencies..."

    local dirs=("${STANDARD_DIRS[@]}")
    [[ "$strict" == "true" ]] && { dirs=("${STRICT_DIRS[@]}"); log_info "Strict mode"; }

    local code_packages_raw; mapfile -t code_packages_raw < <(extract_code_packages "${dirs[@]}")
    local code_packages; mapfile -t code_packages < <(clean_packages "${code_packages_raw[@]}")
    local desc_imports; mapfile -t desc_imports < <(parse_description_imports)
    local renv_packages; mapfile -t renv_packages < <(parse_renv_lock)

    log_info "Found ${#code_packages[@]} in code, ${#desc_imports[@]} in DESCRIPTION, ${#renv_packages[@]} in renv.lock"

    local all_packages; mapfile -t all_packages < <(compute_union_packages)
    local missing_from_desc; mapfile -t missing_from_desc < <(find_missing_from_description all_packages desc_imports)
    local missing_from_lock; mapfile -t missing_from_lock < <(find_missing_from_lock all_packages renv_packages)

    report_and_fix_missing_description missing_from_desc "$verbose" "$auto_fix" || return 1
    report_and_fix_missing_lock missing_from_lock "$verbose" "$auto_fix" || return 1

    log_success "All packages properly declared"
}

sync_packages_to_code() {
    local strict="${1:-true}" verbose="${2:-false}"
    log_info "Syncing DESCRIPTION and renv.lock to code (code is source of truth)..."

    local dirs=("${STANDARD_DIRS[@]}")
    [[ "$strict" == "true" ]] && dirs=("${STRICT_DIRS[@]}")

    local code_packages_raw; mapfile -t code_packages_raw < <(extract_code_packages "${dirs[@]}")
    local code_packages; mapfile -t code_packages < <(clean_packages "${code_packages_raw[@]}")
    local desc_imports; mapfile -t desc_imports < <(parse_description_imports)
    local renv_packages; mapfile -t renv_packages < <(parse_renv_lock)

    log_info "Found ${#code_packages[@]} packages in code"
    [[ "$verbose" == "true" ]] && { echo "  Code packages:"; printf '    %s\n' "${code_packages[@]}"; echo ""; }

    local code_str=" ${code_packages[*]} "
    local desc_str=" ${desc_imports[*]} "

    local to_add_desc=() to_remove_desc=() to_add_lock=() to_remove_lock=()

    for pkg in "${code_packages[@]}"; do
        [[ -z "$pkg" ]] && continue
        [[ "$desc_str" != *" $pkg "* ]] && to_add_desc+=("$pkg")
    done

    for pkg in "${desc_imports[@]}"; do
        [[ -z "$pkg" || "$pkg" == "renv" ]] && continue
        [[ "$code_str" != *" $pkg "* ]] && to_remove_desc+=("$pkg")
    done

    for pkg in "${code_packages[@]}"; do
        [[ -z "$pkg" ]] && continue
        local found=false
        for rp in "${renv_packages[@]}"; do [[ "$pkg" == "$rp" ]] && { found=true; break; }; done
        [[ "$found" == false ]] && to_add_lock+=("$pkg")
    done

    for pkg in "${renv_packages[@]}"; do
        [[ -z "$pkg" || "$pkg" == "renv" ]] && continue
        [[ "$code_str" != *" $pkg "* ]] && to_remove_lock+=("$pkg")
    done

    [[ ${#to_add_desc[@]} -gt 0 ]] && log_info "Adding ${#to_add_desc[@]} packages to DESCRIPTION"
    for pkg in "${to_add_desc[@]}"; do add_package_to_description "$pkg"; done

    [[ ${#to_remove_desc[@]} -gt 0 ]] && log_info "Removing ${#to_remove_desc[@]} packages from DESCRIPTION"
    if [[ ${#to_remove_desc[@]} -gt 0 ]]; then
        local pattern=""
        for p in "${to_remove_desc[@]}"; do
            [[ -z "$pattern" ]] && pattern="$p" || pattern="$pattern|$p"
        done
        local tmp; tmp=$(mktemp)
        awk -v pattern="^[[:space:]]*(${pattern})[[:space:],]*\$" '
        /^Imports:/ { in_imports=1; print; next }
        in_imports { if (/^[A-Z]/) { in_imports=0; print; next }; if ($0 !~ pattern) print; next }
        { print }
        ' DESCRIPTION > "$tmp" && mv "$tmp" DESCRIPTION
        log_success "Removed ${#to_remove_desc[@]} unused packages from DESCRIPTION"
    fi

    [[ ${#to_add_lock[@]} -gt 0 ]] && log_info "Adding ${#to_add_lock[@]} packages to renv.lock"
    for pkg in "${to_add_lock[@]}"; do add_package_to_renv_lock "$pkg" 2>/dev/null || log_warn "Could not add $pkg to renv.lock (not on CRAN?)"; done

    [[ ${#to_remove_lock[@]} -gt 0 ]] && log_info "Removing ${#to_remove_lock[@]} packages from renv.lock"
    if [[ ${#to_remove_lock[@]} -gt 0 ]]; then
        local tmp; tmp=$(mktemp)
        local jq_filter='.'
        for p in "${to_remove_lock[@]}"; do
            jq_filter="$jq_filter | del(.Packages[\"$p\"])"
        done
        if jq "$jq_filter" renv.lock > "$tmp" && mv "$tmp" renv.lock; then
            log_success "Removed ${#to_remove_lock[@]} unused packages from renv.lock"
        else
            rm -f "$tmp"
            log_error "Failed to update renv.lock"
        fi
    fi

    log_success "Sync complete: DESCRIPTION and renv.lock now match code"
}

validate_and_report() {
    local strict="${1:-true}" auto_fix="${2:-true}" verbose="${3:-false}" cleanup="${4:-false}"

    if [[ "$cleanup" == "true" ]]; then
        sync_packages_to_code "$strict" "$verbose"
        return $?
    fi

    if validate_package_environment "$strict" "$auto_fix" "$verbose"; then
        log_success "Validation passed"
        return 0
    fi
    log_error "Validation failed"; return 1
}

#==============================================================================
# SYSTEM DEPS
#==============================================================================

detect_missing_system_deps() {
    local dockerfile="${1:-./Dockerfile}"
    source "${SCRIPT_DIR}/system_deps_map.sh" 2>/dev/null || { log_warn "system_deps_map.sh not found"; return 0; }
    [[ -f "$dockerfile" ]] || { log_warn "Dockerfile not found"; return 0; }

    local all_pkgs; all_pkgs=$(extract_code_packages | sort -u)
    [[ -z "$all_pkgs" ]] && return 0

    local missing_build=() missing_runtime=() pkgs_missing=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        local bdeps; bdeps=$(get_package_build_deps "$pkg")
        [[ -z "$bdeps" ]] && continue

        local has_missing=false
        for d in $bdeps; do grep -q "$d" "$dockerfile" || { missing_build+=("$d"); has_missing=true; }; done
        for d in $(get_package_runtime_deps "$pkg"); do grep -q "$d" "$dockerfile" || missing_runtime+=("$d"); done
        [[ "$has_missing" == true ]] && pkgs_missing+=("$pkg")
    done <<< "$all_pkgs"

    [[ ${#pkgs_missing[@]} -eq 0 ]] && { log_success "All system deps present"; return 0; }

    log_warn "Missing system dependencies:"
    for p in "${pkgs_missing[@]}"; do
        echo "  $p: build=$(get_package_build_deps "$p") runtime=$(get_package_runtime_deps "$p")"
    done
    echo ""
    echo "Add to Dockerfile and rebuild: make docker-build"
    return 1
}

#==============================================================================
# CLI
#==============================================================================

main() {
    local strict=true auto_fix=true verbose=false cleanup=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --strict) strict=true; shift;;
            --no-strict) strict=false; shift;;
            --fix) auto_fix=true; shift;;
            --no-fix) auto_fix=false; shift;;
            --verbose|-v) verbose=true; shift;;
            --cleanup-unused) cleanup=true; shift;;
            --system-deps) detect_missing_system_deps "${2:-.}/Dockerfile"; shift 2;;
            --help|-h)
                cat <<'EOF'
Usage: validation.sh [OPTIONS]

Validate R package dependencies (no R required on host).

OPTIONS:
    --strict           Scan all dirs including tests/vignettes [default]
    --no-strict        Scan only R/scripts/analysis
    --fix              Auto-add missing packages [default]
    --no-fix           Report only
    --cleanup-unused   Sync DESCRIPTION and renv.lock to code (code is source
                       of truth). Adds missing packages, removes unused ones.
    --system-deps      Check Dockerfile for system deps
    --verbose, -v      Show package lists
    --help, -h         Show help

EXAMPLES:
    validation.sh                  # Full validation with auto-fix
    validation.sh --no-fix -v      # Report only, verbose
    validation.sh --cleanup-unused # Sync to code, remove unused packages
    validation.sh --system-deps    # Check system dependencies
EOF
                exit 0;;
            *) log_error "Unknown: $1"; exit 1;;
        esac
    done

    validate_and_report "$strict" "$auto_fix" "$verbose" "$cleanup"
}

#=============================================================================
# MODULE LOADED
#=============================================================================

readonly ZZCOLLAB_VALIDATION_LOADED=true

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
