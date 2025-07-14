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
            removals = ["PumasProductManager", "Pumas", "DeepPumas"]
            for each in removals
                path = joinpath(version, each)
                @info "Checking compiled directory" path
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
