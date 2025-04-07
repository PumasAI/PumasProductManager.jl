import PumasProductManager
using Test

@testset "PumasProductManager" begin
    io = IOBuffer()
    PumasProductManager.list(io)
    list = String(take!(io))
    @test contains(list, "Pumas@2.6.1")
    try
        mktempdir() do dir
            cd(dir) do
                withenv("JULIA_PKG_PRECOMPILE_AUTO" => "0") do
                    PumasProductManager.init("Pumas@2.6.1", "pumas-2.6.1")
                end
            end
            status = readchomp(`juliaup st`)
            @test contains(status, "Pumas@2.6.1")

            contents = readdir(joinpath(dir, "pumas-2.6.1"))
            @test "Project.toml" in contents
            @test "Manifest.toml" in contents
        end
    finally
        @test success(`juliaup rm Pumas@2.6.1`)
        @test success(`juliaup rm PumasProductManager`)
    end
end
