import PumasProductManager
using Test

@testset "PumasProductManager" begin
    # NOTE: update whenever new versions are released.
    expected_versions = [
        "DeepPumas@0.8.0",
        "DeepPumas@0.8.1",
        "Pumas@2.6.0",
        "Pumas@2.6.1",
        "Pumas@2.7.0-prerelease",
    ]

    @testset "Version listing" begin
        io = IOBuffer()
        PumasProductManager.list(io)
        list = String(take!(io))

        for each in expected_versions
            @test contains(list, each)
        end
    end

    try
        mktempdir() do dir
            @testset "Installation" begin
                cd(dir) do
                    withenv("JULIA_PKG_PRECOMPILE_AUTO" => "1") do
                        for each in expected_versions
                            PumasProductManager.init([each]; precompile = true)
                            PumasProductManager.init([each, each]; precompile = true)
                        end
                    end
                end

                status = readchomp(`juliaup st`)
                for each in expected_versions
                    @test contains(status, each)
                end

                for each in expected_versions
                    dirs =
                        [joinpath(DEPOT_PATH[1], "environments", each), joinpath(dir, each)]
                    for folder in dirs
                        contents = readdir(folder)
                        @test "Project.toml" in contents
                        @test "Manifest.toml" in contents
                    end
                end

                for each in expected_versions
                    product, _ = split(each, "@"; limit = 2)
                    file = joinpath(@__DIR__, "$product.jl")
                    channel = "+$each"
                    cmd = `julia $channel $file`
                    @test contains(readchomp(cmd), ":success")
                end
            end
        end
    finally
        for each in expected_versions
            @test success(`juliaup rm $each`)
        end
        @test success(`juliaup rm PumasProductManager`)
    end
end
