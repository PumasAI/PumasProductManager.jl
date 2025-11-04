import PumasProductManager
using Test

@testset "PumasProductManager" begin
    # NOTE: update whenever new versions are released.
    expected_versions = [
        "DeepPumas@0.8.0",
        "DeepPumas@0.8.1",
        "Pumas@2.6.0",
        "Pumas@2.6.1",
        "Pumas@2.7.0",
        "Pumas@2.7.1",
    ]

    @testset "Version listing" begin
        io = IOBuffer()
        PumasProductManager.list(io)
        list = String(take!(io))

        for each in expected_versions
            @test contains(list, each)
        end
    end

    @testset "Non-empty directory initialization" begin
        mktempdir() do dir
            cd(dir) do
                # Test initialization in directory with existing files
                test_version = "Pumas@2.7.1"
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
                test_version = "Pumas@2.7.1"

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

    try
        mktempdir() do dir
            @testset "Installation" begin
                cd(dir) do
                    withenv("JULIA_PKG_PRECOMPILE_AUTO" => "1") do
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
