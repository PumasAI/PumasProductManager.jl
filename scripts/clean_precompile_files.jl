import TOML

# Every package a product environment installs is bundled, and a bundled
# package decrypts its source during precompilation. That decryption is what
# activates the license, so a cache entry surviving from an earlier run skips
# the activation and leaves the product with no license to check against.
function precompile_removals()
    packages = Set(["PumasProductManager", "Pumas", "DeepPumas"])
    environments = joinpath(@__DIR__, "..", "environments")
    for env in readdir(environments, join = true)
        project_file = joinpath(env, "Project.toml")
        isfile(project_file) || continue
        project = TOML.parsefile(project_file)
        union!(packages, keys(get(Dict{String,Any}, project, "deps")))
    end
    return sort!(collect(packages))
end

const REMOVALS = precompile_removals()

for depot in DEPOT_PATH
    clones = joinpath(depot, "clones")
    if isdir(clones)
        try
            rm(clones, force = true, recursive = true)
            @info "Removed clones directory" clones
        catch e
            @warn "Failed to remove clones directory" clones e
        end
    end

    compiled = joinpath(depot, "compiled")
    if isdir(compiled)
        for version in readdir(compiled, join = true)
            for each in REMOVALS
                path = joinpath(version, each)
                if isdir(path)
                    try
                        rm(path, force = true, recursive = true)
                        @info "Removed compiled directory" path
                    catch e
                        @warn "Failed to remove compiled directory" path e
                    end
                end
            end
        end
    else
        @warn "Compiled directory not found" compiled
    end

    environments = joinpath(depot, "environments")
    if isdir(environments)
        for env in readdir(environments, join = true)
            @info "Checking environment directory" env
            candidates = ["PumasProductManager", "Pumas", "DeepPumas"]
            if any(startswith(env, candidate) for candidate in candidates)
                try
                    rm(env, force = true, recursive = true)
                    @info "Removed environment directory" env
                catch e
                    @warn "Failed to remove environment directory" env e
                end
            end
        end
    else
        @warn "Environments directory not found" environments
    end
end
