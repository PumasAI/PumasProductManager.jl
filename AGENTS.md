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
- **Artifacts.toml** - PumasProductRegistry artifact definition
- **test/runtests.jl** - Tests and supported product versions

## Key Concepts

- Uses scratch spaces (`Scratch.@get_scratch!`) for stable artifact storage
- Pins all packages to exact versions to prevent accidental updates
- Creates juliaup channels (e.g., `+Pumas@2.7.0`) for easy access
- Requires `--preserve=all` when adding packages to product environments

## Gotchas

- **Compile-time execution**: `products_path()` and `_setup_ppm_channel()` run during precompilation. Changes require clearing precompile cache.
- **juliaup >= 1.18.0** required for channel aliases (`supports_channel_aliases()`)
- **Windows**: App Execution Aliases throw EACCES on stat - handled specially in `find_executables()`
- **Stale clones**: When artifact path changes, git clones in depot are auto-removed via `_rm_stale_clones()`

## Testing

```bash
# Run single product (for CI matrix)
PPM_TEST_PRODUCT=Pumas@2.7.1 julia --project=. -e 'using Pkg; Pkg.test()'

# Skip precompilation in tests
JULIA_PKG_PRECOMPILE_AUTO=0 julia --project=. -e '...'
```

Tests create/cleanup juliaup channels. If tests fail mid-run, manual cleanup may be needed: `juliaup rm <channel>`

## Internal Functions

- `_gather_package_specs()` - Finds bundled packages from manifest for installation
- `_link_juliaup_channel()` - Creates juliaup channel aliases
- `_heal_juliaup_channels()` - Fixes broken/old-style channels on precompilation
- `resolve_julialauncher_path()` - Finds julia binary, handles Windows aliases

## Local Registry Override

Test with locally-built registries using Julia's artifact override mechanism.

1. Download `PumasProductRegistry.zip` from CI build artifacts

2. Extract:
   ```bash
   unzip PumasProductRegistry.zip -d /tmp/registry
   cd /tmp/registry && tar -xzf PumasProductRegistry.tar.gz
   ```

3. Create `~/.julia/artifacts/Overrides.toml`:
   ```toml
   [aef49cb6-75a8-4add-8242-3d3875347889]
   PumasProductRegistry = "/tmp/registry"
   ```

4. Clear precompile cache: `rm -rf ~/.julia/compiled/v1.*/PumasProductManager`

5. Test: `julia --project=. -e 'using PumasProductManager; PumasProductManager.list()'`

To remove: delete the section from Overrides.toml or set value to empty string.
