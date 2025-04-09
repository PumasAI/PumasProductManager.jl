# PumasProductManager

This is the Pumas product manager package. Use it to install any version of
Pumas or DeepPumas. Currently supported versions of products are:

- `Pumas@2.6.0`
- `Pumas@2.6.1`
- `DeepPumas@0.8.0`
- `DeepPumas@0.8.1`

> [!IMPORTANT]
>
> Support requests should be sent to support@pumas.ai rather than this GitHub
> repository. In your support request please state that you are installing your
> product via this repository rather than Pumas Desktop.

## Installation

Install `julia` via https://julialang.org/downloads/#install_julia and make
sure that the first option is chosen, which installs the `juliaup` version
manager. This is essential for the product manager to work.

Next run the following command in a terminal window to install the product manager package:

```
julia --project=@PumasProductManager -i -e 'import Pkg; Pkg.add(url="https://github.com/PumasAI/PumasProductManager.jl"); import PumasProductManager'
```

This will start up `julia` with the product manager installed and available.
Now enter Julia's package manager by pressing `]` and run the following command:

```plaintext
pkg> pumas list
DeepPumas@0.8.0
DeepPumas@0.8.1
Pumas@2.6.0
Pumas@2.6.1
```

Then initialize any of the listed products to install them, for example:

```plaintext
pkg> pumas init Pumas@2.6.1
```

This will download and install all the required packages for Pumas 2.6.1 and
then precompile them. Once completed you can restart Julia with this newly
installed version of Pumas with the following:

```plaintext
$ julia +Pumas@2.6.1

julia> using Pumas
```

## VSCode Configuration

This section covers the changes that previous Pumas Desktop users, as well as
new users, will need to make.

Start VSCode and then open the "command palette" with `Ctrl+Shift+P` (or with
`Cmd+Shift+P` on macOS). Type in "Open User Settings (JSON)" and select the top
result, which will open an editor window with your user configuration.

Find, or add, the line that starts with `"julia.executablePath"` and change it
to the `julia +Pumas@2.6.1`, or whichever version you installed in the previous
section that you would like to use as your default.

Find, or add, the line that starts with `"julia.additionalArgs"` and remove any
Pumas-specific values from it.

Find, or add, the line that starts with `julia.environmentPath` and set it to
`"~/.julia/environments/Pumas@2.6.1"`, or whichever version you installed in
the previous section.

Find the lines that start with `"QUARTO_JULIA_PROJECT"`, `"QUARTO_JULIA"`, and
`"QUARTONOTEBOOKRUNNER_EXEFLAGS"`. Remove these lines.

> [!IMPORTANT]
>
> This file is a JSON file, so make sure that while removing or editing lines
> you do not leave any trailing `,` in `{}`s or `[]`s.

> [!NOTE]
>
> This is your User settings file, it is global. For each project that you
> start you can have a local `.vscode/settings.json` file that overrides the
> User settings. This is called Workspace settings. It is useful if you need to
> run several different versions of Pumas products in different projects.
> See [the official VSCode documentation](https://code.visualstudio.com/docs/configure/settings#_workspace-settings)
> for details on using Workspace settings. Adjust the product versions that you
> have set in your User settings within your Workspace settings.

## Managing products

All of the `pumas` commands described below require `PumasProductManager` to
be loaded into the `julia` process. Do that with

```plaintext
$ julia +PumasProductManager
```

All available commands can be accessed via the normal Julia Package Manager,
which is entered by pressing `]` in the Julia REPL. All PumasProductManager
commands start with `pumas`. Tab completion is available for all `pumas`
commands, similar to the Julia package manager.

Prefixing a command with `?` will display the help for that command.

### `list`ing available products

To view the available products that can be installed use the `pumas list` command.

```plaintext
pkg> pumas list
DeepPumas@0.8.0
DeepPumas@0.8.1
Pumas@2.6.0
Pumas@2.6.1
```

### `init`ializing products

To install a specific version of a product use the `pumas init` command.

```plaintext
pkg> pumas init <product> [<path>]
```

Tab completion is available for the product name as well as paths.

This Initializes a new Pumas product installation at the provided path. Use `.`
for the current path. The path cannot contain a `Project.toml` or
`Manifest.toml` file already. When no path is provided then a global
environment is created.

After running `init` you can then start using the product via the
custom `juliaup` channel that is added, for example:

```plaintext
pkg> pumas init Pumas@2.6.1

[output skipped...]

julia> exit()

$ julia +Pumas@2.6.1

julia> using Pumas
```

If you specified a `path` when initializing then specify that with the
`--project` flag:

```plaintext
pkg> pumas init Pumas@2.6.1 my-project

[output skipped...]

julia> exit()

$ julia +Pumas@2.6.1 --project=my-project

julia> using Pumas
```

Should you want to set this custom channel as the default then you can use the
normal `juliaup default` command to do this:

```plaintext
$ juliaup default Pumas@2.6.1
```

### Updating the Pumas product manager

If you wish to check for new product versions then use the following:

```plaintext
$ julia +PumasProductManager

pkg> update

julia> exit()

$ julia +PumasProductManager

pkg> pumas list
```

To update an existing product installation to a newer version remove the
existing `Project.toml` and `Manifest.toml` files and then run the `init`
command again and specify the new version you would like to use.

### Adding packages to initialized environments

The provided Julia environments include a limited set of extra Julia packages
that you can use in conjunction with the Pumas products. You can add more
packages to a particular environment using the normal package manager `add`
operation.

```plaintext
julia +Pumas@2.6.1

pkg> add --preserve=all ExtraPackage
```

If Julia's package manager throws an error related to incompatible versions of
packages then that means that `ExtraPackage` is not compatible with this
particular version of Pumas and cannot be added.

Should you need to update a version of a package that you manaually installed
then just run the same `add --preserve=all` command again and the package will
be updated. Do not run `update` directly, since all Pumas-provided packages are
intended to be fixed to a specific version.

### Uninstalling

Just remove the directory that contains the `Project.toml` and `Manifest.toml`
files.

If you really need to clean up space you can also run `Pkg.jl`'s `Pkg.gc()`
function as well if you wish to clean up any unused artifacts. This is usually
not needed though.

To uninstall the product manager itself. Just remove the global environment that
it was installed into, usually `@PumasProductManager` if the default installation
procedure was followed. The path can be found by running the following:

```plaintext
$ julia +PumasProductManager

pkg> status
```

which will print out the path to the environment that the product manager was
installed into.

If you wish to uninstall `julia` itself please refer to the `juliaup`
documentation itself for details.

## Usage with Quarto

If you've set your `juliaup` default channel to a specific product version then
using it in a Quarto notebook should require no special setup. Just include
`engine: julia` in your frontmatter to select the right engine.

Should you have not set a default channel then you can specify the channel and
project using the notebook's frontmatter as follows:

````qmd
---
engine: julia
julia:
   exeflags: ["+Pumas@2.6.0"]
---

```{julia}
using Pumas
```
````

