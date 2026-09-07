using Test

import PumasProductManager

@testset "License keys" begin
    PPM = PumasProductManager

    @testset "product settings from the environment project" begin
        project = Dict(
            "preferences" => Dict(
                "PumasLicenseManager" =>
                    Dict("appName" => "DeepPumas", "product" => "deeppumas"),
            ),
        )
        settings = PPM._license_settings(project)
        @test settings.app_name == "DeepPumas"
        @test settings.product == "deeppumas"

        # Matches the defaults `PumasLicenseManager` itself falls back to.
        defaults = PPM._license_settings(Dict{String,Any}())
        @test defaults.app_name == "Pumas"
        @test defaults.product == "pumas"
    end

    @testset "file locations" begin
        cache = PPM._license_cache_file("deeppumas")
        @test contains(cache, "LicenseSpring")
        @test basename(dirname(cache)) == "deeppumas"
        @test basename(cache) == "License.key"
    end

    @testset "resolution order" begin
        mktempdir() do dir
            cache_file = joinpath(dir, "License.key")
            resolve(; kws...) = PPM._resolve_license_key(
                "Pumas",
                "pumas";
                prompt = false,
                cache_file,
                kws...,
            )

            withenv("LICENSESPRING_KEY" => nothing) do
                @test_throws PPM.MissingLicenseError resolve()
                @test resolve(license_key = "explicit") == "explicit"
            end

            withenv("LICENSESPRING_KEY" => "from-env") do
                @test resolve() == "from-env"
                @test resolve(license_key = "explicit") == "explicit"
            end

            # A blank key is the same as no key at all.
            withenv("LICENSESPRING_KEY" => "  ") do
                @test_throws PPM.MissingLicenseError resolve()
            end

            # An activated device has its key cached, so none needs supplying.
            withenv("LICENSESPRING_KEY" => nothing) do
                touch(cache_file)
                @test isnothing(resolve())
            end
        end
    end

    @testset "prompting" begin
        output = IOBuffer()
        key = PPM._prompt_license_key("DeepPumas", IOBuffer("  typed-key \n"), output)
        @test key == "typed-key"
        @test contains(String(take!(output)), "DeepPumas")
    end

    @testset "missing license error" begin
        message = sprint(showerror, PPM.MissingLicenseError("Pumas"))
        @test contains(message, "Pumas")
        @test contains(message, "license_key")
        @test contains(message, "LICENSESPRING_KEY")
    end
end
