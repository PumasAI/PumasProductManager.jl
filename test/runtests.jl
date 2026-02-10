import JSON
import PumasProductManager
using Test

@testset "PumasProductManager" begin
    # NOTE: update whenever new versions are released.
    all_versions = [
        "DeepPumas@0.8.0",
        "DeepPumas@0.8.1",
        "DeepPumas@0.9.0",
        "Pumas@2.6.0",
        "Pumas@2.6.1",
        "Pumas@2.7.0",
        "Pumas@2.7.1",
        "Pumas@2.8.0",
    ]

    # Filter to single product when running in CI matrix
    test_product = get(ENV, "PPM_TEST_PRODUCT", nothing)
    expected_versions = if isnothing(test_product)
        all_versions
    else
        filter(v -> v == test_product, all_versions)
    end

    @testset "Version listing" begin
        io = IOBuffer()
        PumasProductManager.list(io)
        list = String(take!(io))

        for each in all_versions
            @test contains(list, each)
        end
    end

    @testset "Non-empty directory initialization" begin
        mktempdir() do dir
            cd(dir) do
                # Test initialization in directory with existing files
                test_version = "Pumas@2.8.0"
                test_dir = "test_non_empty"

                # Create directory with existing files
                mkpath(test_dir)
                existing_file = joinpath(test_dir, "existing_file.txt")
                write(existing_file, "This file should be preserved")
                existing_data = joinpath(test_dir, "data.csv")
                write(existing_data, "col1,col2\n1,2\n3,4")

                # Create subdirectory with files
                mkpath(joinpath(test_dir, "subdir"))
                subdir_file = joinpath(test_dir, "subdir", "nested.jl")
                write(subdir_file, "# Nested Julia file")

                # Initialize Pumas in non-empty directory
                withenv("JULIA_PKG_PRECOMPILE_AUTO" => "0") do
                    PumasProductManager.init(test_version, test_dir)
                end

                # Verify Pumas files were created
                @test isfile(joinpath(test_dir, "Project.toml"))
                @test isfile(joinpath(test_dir, "Manifest.toml"))
                @test isfile(joinpath(test_dir, "PackageBundler.toml"))

                # Verify existing files are preserved
                @test isfile(existing_file)
                @test read(existing_file, String) == "This file should be preserved"
                @test isfile(existing_data)
                @test read(existing_data, String) == "col1,col2\n1,2\n3,4"
                @test isfile(subdir_file)
                @test read(subdir_file, String) == "# Nested Julia file"

                # Clean up
                rm(test_dir; recursive=true, force=true)
                success(`juliaup rm $test_version`)
            end
        end
    end

    @testset "Error cases for existing Project/Manifest files" begin
        mktempdir() do dir
            cd(dir) do
                test_version = "Pumas@2.8.0"

                @testset "Error on existing Project.toml" begin
                    test_dir = "test_existing_project"
                    mkpath(test_dir)

                    # Create existing Project.toml and other files
                    project_file = joinpath(test_dir, "Project.toml")
                    project_content = "[deps]\nDataFrames = \"a93c6f00-e57d-5684-b7b6-d8193f3e46c0\""
                    write(project_file, project_content)

                    # Add another file to verify it's preserved
                    other_file = joinpath(test_dir, "existing.txt")
                    write(other_file, "should remain")

                    # Record initial state
                    initial_files = Set(readdir(test_dir))

                    # Should throw error
                    @test_throws ErrorException PumasProductManager.init(test_version, test_dir)

                    # Verify no new files were created
                    final_files = Set(readdir(test_dir))
                    @test initial_files == final_files

                    # Verify existing files are unchanged
                    @test read(project_file, String) == project_content
                    @test read(other_file, String) == "should remain"

                    # Verify Pumas files were NOT created
                    @test !isfile(joinpath(test_dir, "Manifest.toml"))
                    @test !isfile(joinpath(test_dir, "PackageBundler.toml"))

                    # Clean up
                    rm(test_dir; recursive=true, force=true)
                end

                @testset "Error on existing Manifest.toml" begin
                    test_dir = "test_existing_manifest"
                    mkpath(test_dir)

                    # Create existing Manifest.toml and other files
                    manifest_file = joinpath(test_dir, "Manifest.toml")
                    manifest_content = "# This file is machine-generated"
                    write(manifest_file, manifest_content)

                    # Add another file to verify it's preserved
                    data_file = joinpath(test_dir, "data.csv")
                    write(data_file, "a,b,c\n1,2,3")

                    # Record initial state
                    initial_files = Set(readdir(test_dir))

                    # Should throw error
                    @test_throws ErrorException PumasProductManager.init(test_version, test_dir)

                    # Verify no new files were created
                    final_files = Set(readdir(test_dir))
                    @test initial_files == final_files

                    # Verify existing files are unchanged
                    @test read(manifest_file, String) == manifest_content
                    @test read(data_file, String) == "a,b,c\n1,2,3"

                    # Verify Pumas files were NOT created
                    @test !isfile(joinpath(test_dir, "Project.toml"))
                    @test !isfile(joinpath(test_dir, "PackageBundler.toml"))

                    # Clean up
                    rm(test_dir; recursive=true, force=true)
                end

                @testset "Error on existing PackageBundler.toml" begin
                    test_dir = "test_existing_bundler"
                    mkpath(test_dir)

                    # Create existing PackageBundler.toml and other files
                    bundler_file = joinpath(test_dir, "PackageBundler.toml")
                    bundler_content = "[packages]\nstrip = [\"SomePackage\"]"
                    write(bundler_file, bundler_content)

                    # Add another file to verify it's preserved
                    readme_file = joinpath(test_dir, "README.md")
                    write(readme_file, "# My Project")

                    # Record initial state
                    initial_files = Set(readdir(test_dir))

                    # Should throw error
                    @test_throws ErrorException PumasProductManager.init(test_version, test_dir)

                    # Verify no new files were created
                    final_files = Set(readdir(test_dir))
                    @test initial_files == final_files

                    # Verify existing files are unchanged
                    @test read(bundler_file, String) == bundler_content
                    @test read(readme_file, String) == "# My Project"

                    # Verify Pumas files were NOT created
                    @test !isfile(joinpath(test_dir, "Project.toml"))
                    @test !isfile(joinpath(test_dir, "Manifest.toml"))

                    # Clean up
                    rm(test_dir; recursive=true, force=true)
                end

                @testset "Error when path is a file" begin
                    test_file = "test_file.txt"
                    file_content = "original content"
                    write(test_file, file_content)

                    # Record initial directory state
                    initial_files = Set(readdir("."))

                    # Should throw error
                    @test_throws ErrorException PumasProductManager.init(test_version, test_file)

                    # Verify no new files were created in current directory
                    final_files = Set(readdir("."))
                    @test initial_files == final_files

                    # Verify the file is unchanged
                    @test isfile(test_file)
                    @test read(test_file, String) == file_content

                    # Verify no Pumas files were created in current directory
                    @test !isfile("Project.toml")
                    @test !isfile("Manifest.toml")
                    @test !isfile("PackageBundler.toml")

                    # Clean up
                    rm(test_file; force=true)
                end
            end
        end
    end

    @testset "juliaup channel aliases" begin
        mktempdir() do depot
            withenv("JULIAUP_DEPOT_PATH" => depot) do
                PPM = PumasProductManager

                # Install Julia versions needed by tests (API only shows channels
                # whose target Julia is installed in the depot)
                run(`juliaup add 1.10`)
                run(`juliaup add 1.11`)

                @testset "version detection" begin
                    v = PPM.juliaup_version()
                    @test v isa VersionNumber
                    @test v >= v"1.18.0"  # CI should have modern juliaup
                    @test PPM.supports_channel_aliases() == true
                end

                @testset "juliaup_config" begin
                    config = PPM.juliaup_config()
                    @test config isa AbstractDict
                    @test haskey(config, "DefaultChannel")
                    @test haskey(config, "OtherChannels")
                    @test config["OtherChannels"] isa Vector
                end

                @testset "_link_juliaup_channel with explicit channel" begin
                    juliaup_cfg = Dict("extra_args" => String[])
                    PPM._link_juliaup_channel("TestPumas", juliaup_cfg, "1.11")

                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "TestPumas", config["OtherChannels"]))
                    # Pre-1.19.4: "alias-to-X", 1.19.4+: resolved binary path
                    @test startswith(ch["File"], "alias-to-") || isfile(ch["File"])
                    @test ch["Args"] == ["--project=@TestPumas"]

                    run(`juliaup rm TestPumas`)
                end

                @testset "_link_juliaup_channel with extra_args" begin
                    juliaup_cfg = Dict("extra_args" => ["-i", "-e", "println(1)"])
                    PPM._link_juliaup_channel("TestPumas2", juliaup_cfg, "1.10")

                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "TestPumas2", config["OtherChannels"]))
                    @test startswith(ch["File"], "alias-to-") || isfile(ch["File"])
                    @test ch["Args"] == ["--project=@TestPumas2", "-i", "-e", "println(1)"]

                    run(`juliaup rm TestPumas2`)
                end

                @testset "_link_juliaup_channel without channel uses default" begin
                    run(`juliaup add 1.11`)
                    run(`juliaup default 1.11`)

                    juliaup_cfg = Dict("extra_args" => String[])
                    jc = PPM.juliaup_config()
                    PPM._link_juliaup_channel("TestPumasDefault", juliaup_cfg, nothing; jc)

                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "TestPumasDefault", config["OtherChannels"]))
                    @test startswith(ch["File"], "alias-to-") || isfile(ch["File"])
                    @test ch["Args"] == ["--project=@TestPumasDefault"]

                    run(`juliaup rm TestPumasDefault`)
                end

                @testset "healing: migrate old-style (binary path + +channel)" begin
                    run(`juliaup add 1.10`)
                    julia_path = PPM.resolve_julialauncher_path()
                    run(`juliaup link TestPumasHeal $julia_path -- +1.10 --project=@TestPumasHeal`)

                    # Verify it's old-style
                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "TestPumasHeal", config["OtherChannels"]))
                    @test !startswith(ch["File"], "alias-to-")
                    @test ch["Args"] == ["+1.10", "--project=@TestPumasHeal"]

                    # Run healing
                    PPM._heal_juliaup_channels(config)

                    # Verify migrated: +channel removed from args, valid File
                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "TestPumasHeal", config["OtherChannels"]))
                    @test startswith(ch["File"], "alias-to-") || isfile(ch["File"])
                    @test ch["Args"] == ["--project=@TestPumasHeal"]

                    run(`juliaup rm TestPumasHeal`)
                end

                @testset "healing: bare julia (no +channel in args)" begin
                    # Set up default channel first
                    run(`juliaup add 1.11`)
                    run(`juliaup default 1.11`)

                    # Create a valid channel first, then corrupt it to have bare "julia"
                    julia_path = PPM.resolve_julialauncher_path()
                    run(`juliaup link TestPumasBare $julia_path -- --project=@TestPumasBare`)

                    # Modify juliaup.json to replace the path with bare "julia"
                    juliaup_json = joinpath(depot, "juliaup", "juliaup.json")
                    file_config = JSON.parsefile(juliaup_json; dicttype=Dict{String,Any})
                    bare_julia = Sys.iswindows() ? "julia.exe" : "julia"
                    file_config["InstalledChannels"]["TestPumasBare"]["Command"] = bare_julia
                    open(juliaup_json, "w") do io
                        JSON.print(io, file_config)
                    end

                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "TestPumasBare", config["OtherChannels"]))
                    @test ch["File"] in ("julia", "julia.exe")
                    @test ch["Args"] == ["--project=@TestPumasBare"]

                    # Run healing - uses default channel since no +channel in args
                    PPM._heal_juliaup_channels(config)

                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "TestPumasBare", config["OtherChannels"]))
                    @test startswith(ch["File"], "alias-to-") || isfile(ch["File"])
                    @test ch["Args"] == ["--project=@TestPumasBare"]

                    run(`juliaup rm TestPumasBare`)
                end

                @testset "healing: already valid channel is skipped" begin
                    juliaup_cfg = Dict("extra_args" => String[])
                    PPM._link_juliaup_channel("TestPumasAlias", juliaup_cfg, "1.11")

                    config_before = PPM.juliaup_config()
                    ch_before = only(filter(c -> c["Name"] == "TestPumasAlias", config_before["OtherChannels"]))
                    # Pre-1.19.4: "alias-to-X", 1.19.4+: resolved binary path
                    @test startswith(ch_before["File"], "alias-to-") || isfile(ch_before["File"])
                    @test isempty(ch_before["Args"]) || !startswith(first(ch_before["Args"]), "+")

                    # Healing should be a no-op
                    PPM._heal_juliaup_channels(config_before)

                    config_after = PPM.juliaup_config()
                    ch_after = only(filter(c -> c["Name"] == "TestPumasAlias", config_after["OtherChannels"]))
                    @test ch_after == ch_before

                    run(`juliaup rm TestPumasAlias`)
                end

                @testset "healing: non-Pumas channels are ignored" begin
                    run(`juliaup link MyOtherChannel +1.11 -- --project=@MyOther`)

                    config = PPM.juliaup_config()
                    ch_before = only(filter(c -> c["Name"] == "MyOtherChannel", config["OtherChannels"]))

                    PPM._heal_juliaup_channels(config)

                    config = PPM.juliaup_config()
                    ch_after = only(filter(c -> c["Name"] == "MyOtherChannel", config["OtherChannels"]))
                    @test ch_after == ch_before  # Unchanged

                    run(`juliaup rm MyOtherChannel`)
                end

                @testset "healing: DeepPumas channels are healed" begin
                    run(`juliaup add 1.11`)
                    julia_path = PPM.resolve_julialauncher_path()
                    run(`juliaup link DeepPumas@0.9.0 $julia_path -- +1.11 --project=@DeepPumas@0.9.0`)

                    config = PPM.juliaup_config()
                    PPM._heal_juliaup_channels(config)

                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "DeepPumas@0.9.0", config["OtherChannels"]))
                    @test startswith(ch["File"], "alias-to-") || isfile(ch["File"])
                    @test ch["Args"] == ["--project=@DeepPumas@0.9.0"]  # +channel removed

                    run(`juliaup rm DeepPumas@0.9.0`)
                end

                @testset "healing: default channel with old-style format" begin
                    run(`juliaup add 1.10`)
                    julia_path = PPM.resolve_julialauncher_path()
                    run(`juliaup link TestPumasHealDflt $julia_path -- +1.10 --project=@TestPumasHealDflt`)

                    # Set as juliaup default
                    run(`juliaup default TestPumasHealDflt`)
                    config = PPM.juliaup_config()
                    @test config["DefaultChannel"]["Name"] == "TestPumasHealDflt"

                    # Heal while it's the default
                    PPM._heal_juliaup_channels(config)

                    # Verify healed and still the default
                    config = PPM.juliaup_config()
                    @test config["DefaultChannel"]["Name"] == "TestPumasHealDflt"
                    default = config["DefaultChannel"]
                    @test startswith(default["File"], "alias-to-") || isfile(default["File"])
                    @test default["Args"] == ["--project=@TestPumasHealDflt"]

                    # Clean up
                    run(`juliaup default 1.11`)
                    run(`juliaup rm TestPumasHealDflt`)
                end

                @testset "_link_juliaup_channel when channel is juliaup default" begin
                    juliaup_cfg = Dict("extra_args" => String[])
                    PPM._link_juliaup_channel("TestPumasDflt", juliaup_cfg, "1.11")

                    # Set as juliaup default
                    run(`juliaup default TestPumasDflt`)
                    config = PPM.juliaup_config()
                    @test config["DefaultChannel"]["Name"] == "TestPumasDflt"

                    # Re-link while it's the default
                    PPM._link_juliaup_channel("TestPumasDflt", juliaup_cfg, "1.11"; jc = config)

                    # Verify re-linked and still the default
                    config = PPM.juliaup_config()
                    @test config["DefaultChannel"]["Name"] == "TestPumasDflt"
                    default = config["DefaultChannel"]
                    @test startswith(default["File"], "alias-to-") || isfile(default["File"])

                    # Clean up
                    run(`juliaup default 1.11`)
                    run(`juliaup rm TestPumasDflt`)
                end

                @testset "_find_temp_default skips Pumas channels" begin
                    jc = Dict(
                        "DefaultChannel" => Dict("Name" => "Pumas@2.7.0"),
                        "OtherChannels" => [
                            Dict("Name" => "Pumas@2.6.0"),
                            Dict("Name" => "DeepPumas@0.9.0"),
                            Dict("Name" => "1.11"),
                        ],
                    )
                    @test PPM._find_temp_default("Pumas@2.7.0", jc) == "1.11"
                end

                @testset "_setup_ppm_channel integration" begin
                    run(ignorestatus(`juliaup rm PumasProductManager`))
                    run(`juliaup add 1.11`)
                    run(`juliaup default 1.11`)

                    PPM._setup_ppm_channel()

                    config = PPM.juliaup_config()
                    ch = only(filter(c -> c["Name"] == "PumasProductManager", config["OtherChannels"]))
                    @test startswith(ch["File"], "alias-to-") || isfile(ch["File"])
                    @test ch["Args"] == ["--project=@PumasProductManager", "-i", "-e", "import PumasProductManager"]

                    run(`juliaup rm PumasProductManager`)
                end
            end
        end
    end

    try
        mktempdir() do dir
            @testset "Installation" begin
                cd(dir) do
                    withenv("JULIA_PKG_PRECOMPILE_AUTO" => "0") do
                        for each in expected_versions
                            PumasProductManager.init(each)
                            PumasProductManager.init(each, each)
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
                    product, _ = split(each, "@"; limit=2)
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
