# PumasProductManager.jl

Julia package that installs and manages Pumas/DeepPumas product versions for end users.

## Commands

```bash
# Run tests (requires license keys)
julia --project=. -e 'using Pkg; Pkg.test()'

# Clean precompile files
julia --project=scripts scripts/clean_precompile_files.jl

# Test REPL commands: ] pumas list, ] pumas init Pumas@2.7.0 test-dir
julia --project=. -i -e 'using PumasProductManager'
```

## Key Files

- **src/PumasProductManager.jl** - Main module: `products_path()`, `init()`, `install()`
- **src/PkgREPL.jl** - Pkg REPL extension (`pumas list`, `pumas init`)
- **environments/** - One directory per product version, holding the Project.toml, Manifest.toml and PackageBundler.toml it installs from
- **test/runtests.jl** - Tests and supported product versions

## Key Concepts

- Installs a product by instantiating the manifest its environment ships, resolved against PumasPublicRegistry
- Pins all packages to exact versions to prevent accidental updates
- Creates juliaup channels (e.g., `+Pumas@2.7.0`) for easy access
- Passes the license key to the instantiate subprocess in `LICENSESPRING_KEY`, since bundled packages are decrypted as they precompile

## Gotchas

- **Compile-time execution**: `_ensure_public_registry()` and `_setup_ppm_channel()` run during precompilation. Changes require clearing precompile cache.
- **juliaup >= 1.18.0** required for channel aliases (`supports_channel_aliases()`)
- **Windows**: App Execution Aliases throw EACCES on stat - handled specially in `find_executables()`
- **Private registries**: PumasRegistry and JuliaHubRegistry overlap with PumasPublicRegistry, so loading the package errors until they are removed from the depot

## Testing

```bash
# Run single product (for CI matrix)
PPM_TEST_PRODUCT=Pumas@2.7.1 julia --project=. -e 'using Pkg; Pkg.test()'

# Skip precompilation in tests
JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e '...'
```

Tests create/cleanup juliaup channels. If tests fail mid-run, manual cleanup may be needed: `juliaup rm <channel>`

## Internal Functions

- `_resolve_license_key()` - Finds the key the bundle loader needs, or throws `MissingLicenseError`
- `_link_juliaup_channel()` - Creates juliaup channel aliases
- `_heal_juliaup_channels()` - Fixes broken/old-style channels on precompilation
- `resolve_julialauncher_path()` - Finds julia binary, handles Windows aliases
