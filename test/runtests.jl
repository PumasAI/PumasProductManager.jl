import PumasProductManager
import Pkg
using Test

@testset "PumasProductManager" begin
    # NOTE: update whenever new versions are released.
    expected_releases = ["DeepPumas@0.8.0", "DeepPumas@0.8.1", "Pumas@2.6.0", "Pumas@2.6.1"]
    expected_prereleases = ["Pumas@2.7.0-prerelease"]

    @testset "Version listing" begin
        # `PumasProductManager.list`
        for kwargs in ((;), (; all_products = false), (; all_products = true))
            io = IOBuffer()
            PumasProductManager.list(io; kwargs...)
            expected_versions = if get(kwargs, :all_products, false)
                sort(vcat(expected_releases, expected_prereleases))
            else
                expected_releases
            end
            @test collect(eachline(seekstart(io))) == expected_versions
        end

        # Pkg REPL mode
        mktemp() do f, io
            redirect_stdout(() -> Pkg.pkg"pumas ls", io)
            flush(io)
            @test collect(eachline(f)) == expected_releases
        end
        mktemp() do f, io
            redirect_stdout(() -> Pkg.pkg"pumas ls --all", io)
            flush(io)
            @test collect(eachline(f)) ==
                  sort(vcat(expected_releases, expected_prereleases))
        end
    end

    for each in vcat(expected_releases, expected_prereleases)
        try
            mktempdir() do dir
                @testset "Installation" begin
                    cd(dir) do
                        withenv("JULIA_PKG_PRECOMPILE_AUTO" => "1") do
                            PumasProductManager.init(each)
                            PumasProductManager.init(each, each)
                        end
                    end
                end

                status = readchomp(`juliaup st`)
                @test contains(status, each)

                dirs = [joinpath(DEPOT_PATH[1], "environments", each), joinpath(dir, each)]
                for folder in dirs
                    @test isfile(folder, "Project.toml")
                    @test isfile(folder, "Manifest.toml")
                end

                product, _ = split(each, "@"; limit = 2)
                file = joinpath(@__DIR__, "$product.jl")
                channel = "+$each"
                cmd = `julia $channel $file`
                @test contains(readchomp(cmd), ":success")
            end
        finally
            @test success(`juliaup rm $each`)
        end
    end

    @test success(`juliaup rm PumasProductManager`)
end
