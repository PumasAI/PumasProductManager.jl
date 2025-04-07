module PumasProductManager

# Imports:

import Artifacts: @artifact_str
import Pkg
import Scratch
import TOML

# Implmentation:

function products_path()
    ppr = artifact"PumasProductRegistry"

    # Stores the artifacts in a scratch space. It does not change its path
    # between artifact updates. This allows the resolved manifest files to
    # remain valid between updates, otherwise paths to the old artifacts are
    # embedded in manifest files and would become invalid after PPM updates.

    scratch = Scratch.@get_scratch!("ppr")
    path = joinpath(scratch, "path") # Tracks the previous artifact path.
    data = joinpath(scratch, "data") # Contains the copied artifacts.

    if isfile(path)
        if read(path, String) == ppr
            # This is the fast path.
        else
            # When the path is different then we remove the previous content
            # any copy it over again. Additionally, we remove any clones that
            # are in the depots that reference the path, which forces recloning
            # for any manifests that are re-resolved.
            if isdir(data)
                rm(data; force = true, recursive = true)
                _rm_stale_clones(data)
            end
            _copy_contents(ppr, data)
            write(path, ppr)
        end
    else
        # Otherwise copy the content and track the artifact path.
        _copy_contents(ppr, data)
        write(path, ppr)
    end

    return data
end

function _rm_stale_clones(url_prefix::String)
    for each in DEPOT_PATH
        clones = joinpath(each, "clones")
        if isdir(clones)
            for repo in readdir(clones; join = true)
                config = joinpath(repo, "config")
                if isfile(config)
                    contents = read(config, String)
                    if contains(contents, url_prefix)
                        try
                            rm(repo; force = true, recursive = true)
                        catch error
                            @info "failed to remove clone" repo error
                        end
                    end
                end
            end
        end
    end
end

function _copy_contents(from::String, to::String)
    for (root, _, files) in walkdir(from)
        for file in files
            src = joinpath(root, file)
            content = read(src, String)
            relfile = relpath(src, from)
            dst = joinpath(to, relfile)
            mkpath(dirname(dst))
            write(dst, content)
        end
    end
end

# Run it at compile time so that the data copying is already done by the time
# the user runs it when listing or initializing products.
products_path()

function products()
    environment_path = joinpath(products_path(), "environments")
    return readdir(environment_path)
end

function product_metadata()
    ids = products()
    return map(ids) do id
        name, version = split(id, "@"; limit = 2)
        return name, VersionNumber(version)
    end
end

function list(io = stdout)
    for (name, version) in sort(product_metadata())
        println(io, "$name@$version") # TODO: better formatting.
    end
end

has_juliaup() = success(`juliaup --version`)

function init(product::String, path::Union{String,Nothing} = nothing)
    product in products() || error("invalid product: $product")

    # We require `juliaup` to be able to install multiple products that may
    # need different Julia versions.
    if !has_juliaup()
        error(
            "`juliaup` is required to initialize a new product. Ensure that you have it installed and available in your system PATH.",
        )
    end

    # Global environments are created by default.
    if isnothing(path)
        @info "initializing product as a global environment `@$product`."
        path = joinpath(first(DEPOT_PATH), "environments", product)
    end

    # Validate that the path either does not exist, or at least does not
    # contain a Project.toml or Manifest.toml file.
    path = normpath(isabspath(path) ? path : abspath(path))
    if isfile(path)
        error("path `$path` is a file.")
    elseif isdir(path)
        isfile(joinpath(path, "Project.toml")) &&
            error("path `$path` already contains a `Project.toml` file.")
        isfile(joinpath(path, "Manifest.toml")) &&
            error("path `$path` already contains a `Manifest.toml` file.")
    else
        mkpath(path)
    end
    @info "creating new `$product` project at `$path`."

    install(product, path)
end

function install(env::AbstractString, dst::AbstractString; force::Bool = false)
    if force && isdir(dst)
        rm(dst; force = true, recursive = true)
    end
    mkpath(dst)
    isempty(readdir(dst)) || error("directory must be empty")

    # Find the repo paths to all the bundled deps required by this environment.
    # They are later passed to a `Pkg.add` call run in the environment's
    # `julia` to resolve and precompile them.
    env_dir = joinpath(products_path(), "environments", env)

    project_file = joinpath(env_dir, "Project.toml")
    project_toml = TOML.parsefile(project_file)
    project_deps = project_toml["deps"]

    manifest_file = joinpath(env_dir, "Manifest.toml")
    manifest_toml = TOML.parsefile(manifest_file)

    specs = _gather_package_specs(manifest_toml)

    # Use a temporary directory to stage the changes prior to moving them into
    # the destination directory.
    mktempdir() do dir
        for (root, _, files) in walkdir(env_dir)
            for file in files
                src = joinpath(root, file)
                content = read(src, String)
                relfile = relpath(src, env_dir)
                _dst = joinpath(dir, relfile)
                mkpath(dirname(_dst))
                write(_dst, content)
            end
        end

        config_file = joinpath(dir, "PackageBundler.toml")
        config_toml = TOML.parsefile(config_file)
        juliaup_config = get(Dict{String,Any}, config_toml, "juliaup")
        channel = get(juliaup_config, "channel", nothing)

        _pkg_add_operations(dir, specs, channel)
        _pin_package_versions(dir, project_deps)
        _link_juliaup_channel(env, juliaup_config, channel)

        @info "finalizing product initialization."
        cp(dir, dst; force = true)
    end
end

function _gather_package_specs(manifest_toml)
    @info "locating required packages."
    bundled_packages = Set(readdir(joinpath(products_path(), "packages")))
    specs = Dict{String,String}[]
    for (k, v) in manifest_toml["deps"]
        entry = only(v)
        if k in bundled_packages
            url = joinpath(products_path(), "packages", k)
            rev = string("v", entry["version"])
            push!(specs, Dict("url" => url, "rev" => rev))
        elseif haskey(entry, "repo-url")
            # It is a git rev package rather than a registered version.
            url = entry["repo-url"]
            rev = entry["repo-rev"]
            push!(specs, Dict("url" => url, "rev" => rev))
        end
    end
    return specs
end

function _pkg_add_operations(dir::String, specs, channel::String)
    # This runs `Pkg.add` on all the gathered `PackageSpec`s. It needs to
    # be done in the correct `julia` version as specified in the
    # environment's configuration.
    mktempdir() do tmp
        specs_file = joinpath(tmp, "specs.toml")
        open(specs_file, "w") do io
            TOML.print(io, Dict("specs" => specs))
        end

        isnothing(channel) || run(`juliaup add $channel`)
        bin = isnothing(channel) ? Base.julia_cmd()[1] : `julia $("+$channel")`

        install_jl = joinpath(tmp, "install.jl")
        open(install_jl, "w") do io
            println(
                io,
                """
                pushfirst!(LOAD_PATH, "@stdlib")
                import Pkg
                import TOML
                popfirst!(LOAD_PATH)

                specs_file = joinpath(@__DIR__, "specs.toml")
                specs_toml = TOML.parsefile(specs_file)
                specs = specs_toml["specs"]

                pkg_specs = map(specs) do each
                    Pkg.PackageSpec(; url = each["url"], rev = each["rev"])
                end

                Pkg.add(pkg_specs; preserve = Pkg.PRESERVE_ALL)
                Pkg.pin(; all_pkgs = true)
                """,
            )
        end
        @info "instantiating and precompiling product."
        run(`$bin --startup-file=no --project=$dir $install_jl`)
    end
end

function _pin_package_versions(dir::String, project_deps)
    manifest_file = joinpath(dir, "Manifest.toml")
    project_file = joinpath(dir, "Project.toml")

    manifest_toml = TOML.parsefile(manifest_file)
    project_toml = TOML.parsefile(project_file)

    # The `Pkg.add` step above has added all packages as direct
    # dependencies, but there are some bundled deps that are not direct
    # dependencies. This reverts them to indirect dependencies.
    project_toml["deps"] = project_deps

    weakdeps = Dict{String,Any}()
    compat = Dict{String,Any}()

    jversion = VersionNumber(manifest_toml["julia_version"])
    julia_version_mmp = "$(jversion.major).$(jversion.minor).$(jversion.patch)"

    for (k, v) in manifest_toml["deps"]
        # Pin the version based on what is currently in the manifest. When
        # a package has no version, ie. an unversioned stdlib then we use
        # the Julia version instead.
        version = VersionNumber(get(only(v), "version", julia_version_mmp))

        # Only the major.minor.patch version is used. Adding build numbers
        # tends to break the resolver.
        compat[k] = "= $(version.major).$(version.minor).$(version.patch)"

        # Only add the package to weakdeps if it's not already in the
        # project otherwise it breaks `Pkg.status()`.
        if !haskey(project_toml["deps"], k)
            weakdeps[k] = only(v)["uuid"]
        end
    end
    compat["julia"] = "= $julia_version_mmp"

    @info "pinning package versions."

    # Replaces all current compat bounds that come from the original
    # Project.toml with pinned versions based on the current manifest. This
    # stops users from accidentally updating these packages when they try
    # to add new packages as direct dependencies.
    project_toml["compat"] = compat

    # These are required to ensure that the compat bounds set above are
    # honoured by the resolver.
    project_toml["weakdeps"] = weakdeps

    project_sorter(key) = Pkg.Types.project_key_order(key), key

    open(project_file, "w") do io
        TOML.print(io, project_toml; sorted = true, by = project_sorter)
    end

    function _project_resolve_hash(toml::Dict)
        project = Pkg.Types.Project(toml)
        return Pkg.Types.project_resolve_hash(project)
    end
    manifest_toml["project_hash"] = _project_resolve_hash(project_toml)

    open(manifest_file, "w") do io
        TOML.print(io, manifest_toml; sorted = true, by = project_sorter)
    end
end

function _link_juliaup_channel(
    env::String,
    juliaup_config,
    channel::Union{String,Nothing} = nothing,
)
    if !has_juliaup()
        @error "could not find `juliaup` in the system PATH. Skipping custom channel creation."
    else
        @info "configuring custom `juliaup` channel `+$env`."
        juliaup_json = joinpath(dirname(dirname(Sys.BINDIR)), "juliaup.json")
        if !isfile(juliaup_json)
            @warn "Could not find `juliaup.json` config file. Skipping channel alias step."
        else
            if success(`juliaup rm $env`)
                @info "removing existing channel alias."
            end

            file = @__FILE__
            global_project = "@$env"
            extra_args = get(Vector{String}, juliaup_config, "extra_args")
            cmd =
                isnothing(channel) ?
                `juliaup link $env $file -- --project=$global_project $(extra_args)` :
                `juliaup link $env $file -- $("+$channel") --project=$global_project $(extra_args)`
            if !success(cmd)
                @warn "failing to run juliaup linking, rerunning with output."
                run(cmd)
            end

            juliaup_json_raw = read(juliaup_json, String)
            # `juliaup` will store the path with escaped `\`s in the json
            # configuration. To correctly replace them with the text "julia" on
            # Windows we need to match against the escaped version of the path.
            escaped_file = @static Sys.iswindows() ? replace(file, "\\" => "\\\\") : file
            write(juliaup_json, replace(juliaup_json_raw, escaped_file => "julia"))
        end
    end
end

function _setup_ppm_channel()
    juliaup_config = Dict("extra_args" => ["-i", "-e", "import PumasProductManager"])
    _link_juliaup_channel("PumasProductManager", juliaup_config)
end

# Run as part of precompilation. When we update the package via `Pkg.update()`
# and precompilation is retriggered then we want the channel config to be
# updated.
_setup_ppm_channel()

include("PkgREPL.jl")

end
