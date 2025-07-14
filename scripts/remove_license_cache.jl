if get(ENV, "CI", "false") == "true"
    for each in readdir(Base.DEPOT_PATH[1], join = true)
        if endswith(each, "License.txt") && isfile(each)
            @info "License file found" each
            rm(each, force = true)
            @info "License file removed" each
        end
    end

    if Sys.islinux()
        dir = joinpath(homedir(), ".LicenseSpring")
        if isdir(dir)
            rm(dir, force = true, recursive = true)
            @info "LicenseSpring cache directory removed" dir
        else
            @warn "LicenseSpring cache directory not found" dir
        end
    elseif Sys.isapple()
        dir = joinpath(homedir(), "Library", "Application Support", "LicenseSpring")
        if isdir(dir)
            rm(dir, force = true, recursive = true)
            @info "LicenseSpring cache directory removed" dir
        else
            @warn "LicenseSpring cache directory not found" dir
        end
    elseif Sys.iswindows()
        dir = joinpath(homedir(), "AppData", "Local", "LicenseSpring")
        if isdir(dir)
            rm(dir, force = true, recursive = true)
            @info "LicenseSpring cache directory removed" dir
        else
            @warn "LicenseSpring cache directory not found" dir
        end
    else
        error("Unsupported OS")
    end
else
    @warn "This script is intended to be run only in CI"
end
