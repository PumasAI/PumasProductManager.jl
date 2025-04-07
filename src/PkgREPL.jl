module PkgREPL

import ..PumasProductManager

import Markdown: @md_str
import Pkg

# Completions:

function complete_init(opts, partial, offset, index; hint::Bool = false)
    # First argument is the product name, next argument is the path.
    # TODO: maybe there's a better way to know this.
    items = if offset == length("pumas init  ")
        PumasProductManager.products()
    else
        # Scans the current partial completion for directories.
        cwd = pwd()
        start_dir = joinpath(cwd, dirname(partial))
        entries = [relpath(joinpath(start_dir, d), cwd) for d in readdir(start_dir)]
        [joinpath(each, "") for each in entries if isdir(joinpath(cwd, each))]
    end
    sort!(items)
    return filter!(startswith(partial), items)
end

# Spec definitions:

function _define_specs()
    list_spec = Pkg.REPLMode.CommandSpec(
        name = "list",
        short_name = "ls",
        api = PumasProductManager.list,
        arg_count = 0 => 0,
        description = "list available Pumas products",
        help = md"""
               ```plaintext
               pkg> pumas list
               ```

               List the available Pumas products and their versions.
               """,
    )
    init_spec = Pkg.REPLMode.CommandSpec(
        name = "init",
        api = PumasProductManager.init,
        arg_count = 1 => 2,
        should_splat = true,
        completions = complete_init,
        description = "initialize a new Pumas project",
        help = md"""
               ```plaintext
               pkg> pumas init <product> [<path>]
               ```

               Initialize a new Pumas product installation at the provided path.
               Use `.` for the current path. The path cannot contain a
               `Project.toml` or `Manifest.toml` file. When no path is provided
               then a global environment is created.

               After running `init` you can then start using the product via the
               custom `juliaup` channel that is added, for example:

               ```
               pkg> pumas init Pumas@2.6.0

               [...]

               julia> exit()

               $ julia +Pumas@2.6.0
               ```

               If you specified a `path` when initializing then use

               ```
               $ julia +Pumas@2.6.0 --project=.
               ```

               Should you want to set this custom channel as the default then
               you can use the `juliaup default` command to do this:

               ```
               $ juliaup default Pumas@2.6.0
               ```
               """,
    )
    return Dict("list" => list_spec, "ls" => list_spec, "init" => init_spec)
end

const SPECS = _define_specs()

function _init_specs(specs = _define_specs())
    Pkg.REPLMode.SPECS["pumas"] = specs
    copy!(Pkg.REPLMode.help.content, Pkg.REPLMode.gen_help().content)
    return nothing
end

function __init__()
    ccall(:jl_generating_output, Cint, ()) === Cint(1) && return
    _init_specs(SPECS)
end

end
