# Motivation Documents

This directory contains documents explaining the rationale for using
zzrenvcheck as a reproducibility tool.

## Documents

| Document | Description |
|----------|-------------|
| [reproducibility-crisis.md](reproducibility-crisis.md) | The R reproducibility crisis and why package validation matters |

## Key Points

### The Problem

- **62%** of research articles not reproducible due to dependency issues
- **80%** of R projects fail to reproduce after 6 months without management
- Complex dependency trees (single package can install 47+ dependencies)

### The Solution

zzrenvcheck ensures consistency between:

1. **Code** - What packages are actually used
2. **DESCRIPTION** - What packages are declared
3. **renv.lock** - What package versions are locked

### The Benefits

- **85-90% reduction** in dependency-related development time
- Cross-platform support (Windows/macOS/Linux)
- Auto-fix capability via CRAN/Bioconductor validation
- CI/CD integration for automated validation

## Related Documentation

- [Validation Quick Reference](../validation-quick-reference.md)
- [Validation Architecture](../validation-architecture.md)
- [README](../../README.md)
