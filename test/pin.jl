using Test

import PumasProductManager
import TOML

@testset "Pinning an environment with [sources]" begin
    mktempdir() do dir
        write(
            joinpath(dir, "Project.toml"),
            """
            [deps]
            Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
            Rmath = "79098fc4-a85e-5d69-aa6a-4863f24498fa"

            [sources]
            Rmath = {url = "https://github.com/PumasAI/Rmath.jl.git", rev = "empty-0.9.0"}
            """,
        )
        PumasProductManager._pkg_instantiate_operations(dir, nothing, nothing)

        manifest = TOML.parsefile(joinpath(dir, "Manifest.toml"))["deps"]
        @test get(only(manifest["Random"]), "pinned", false)
        @test get(only(manifest["Rmath"]), "pinned", false)
        @test only(manifest["Rmath"])["repo-rev"] == "empty-0.9.0"

        project = TOML.parsefile(joinpath(dir, "Project.toml"))
        @test haskey(project["sources"], "Rmath")
    end
end
