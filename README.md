# nasher
This is a command-line utility for managing a Neverwinter Nights script or
module repository.

## Requirements
- [nim](https://github.com/dom96/choosenim) >= 0.20.0
- [neverwinter.nim](https://github.com/niv/neverwinter.nim) >= 1.2.5
- [nwnsc](https://gitlab.com/glorwinger/nwnsc)

## Installation
You can install nasher through `nimble`:

    nimble install nasher

Or by building from source:

    $ git clone https://github.com/squattingmonk/nasher.nim.git nasher
    $ cd nasher
    $ nimble install

If `nimble` has been configured correctly, the binary should be available on
your path.

## Usage
Run `nasher --help` to see usage information. To get detailed usage information
on a particular command, run `nasher command --help`, where `command` is the
command you wish to learn about.

### Initializing a new package
    # Create a nasher package in the current directory
    $ nasher init

    # Create a nasher package in directory foo
    $ nasher init foo

This will create a `nasher.cfg` file in the package directory. You can alter
the contents of this file to customize the paths to sources, add author
information, etc.

The package directory will also be initialized as a git repository if it was
not already one. To avoid this behavior, pass `--vcs:none`.

### Listing build targets
    # List target names, descriptions, packed file, and source files
    $ nasher list

    # List target names only
    $ nasher list --quiet

This will list the targets available in the current package. The first target
listed is treated as the default.

### Building targets
When building a target, source files are cached into `.nasher/cache/x`, where
`x` is the name of the target. During later builds of this target, only the
source files that have changed will be rebuilt.

The `convert`, `compile`, `pack`, and `install` commands are run in sequence.
If you want to install a target, you can just use the `install` command without
having to first use `convert`, `compile`, and `pack`.

All of these commands can delete the cache and trigger a clean build if passed
with `--clean`.

#### Converting JSON to GFF
    # Convert all sources for the default target
    $ nasher convert

    # Convert all sources for the target "demo"
    $ nasher convert demo

#### Compiling
    # Compile all scripts for the default target
    $ nasher compile

    # Compile all scripts for the target "demo"
    $ nasher compile demo

#### Packing
    # Packing the default target
    $ nasher pack

    # Pack "demo"
    $ nasher pack demo

This compiles scripts, converts json sources into their gff counterparts, and
packs the resources into the target file. The packed file is placed into the
package root directory. If the file to be packed already exists in the package
root, you will be prompted to overwrite it. You can force answer the prompt by
passing the `--yes`, `--no`, or `--default` flags.

#### Installing
    # Install the packed file for the default target
    $ nasher install

    # Install the packed file for "demo"
    $ nasher install demo

This command packs the target file and then installs it to the appropriate
folder in the NWN installation path. If the file to be installed already exists
at the target location, you will be prompted to overwrite it. You can force
answer the prompt by passing the `--yes`, `--no`, or `--default` flags.

### Unpacking a file
    # Unpack "demo.mod" into src/
    $ nasher unpack demo.mod

This unpacks a `.mod`, `.erf`, or `.hak` file into the source tree. GFF files
are converted to JSON format. If a file does not exist in the source tree, it
is checked against a series of rules in the package config. If a rule is
matched, it will be placed in that directory. Otherwise, it is placed into the
directory `unknown` in the package root.

If an extracted file would overwrite a newer version, you will be prompted to
overwrite the file. You can force answer the prompt by passing the `--yes`,
`--no`, or `--default` flags.

You can initialize a package with the contents of a `.mod`, `.erf`, or `.hak`
file by running:

    # Initialize into foo using the contents of bar.mod as source files
    $ nasher init foo bar.mod

This is equivalent to:

    $ nasher init foo
    $ cd foo
    $ nasher unpack ../bar.mod

## Configuration
You can configure `nasher` using the `config` command (see `nasher config
--help` for detailed usage).

    # Set the default NWN installation path
    $ nasher config installDir "~/Documents/Neverwinter Nights"

Configuration options can also be passed to the commands directly using the
format `--option:value` or `--option:"value with spaces"`:

    # Compile with warnings on:
    $ nasher compile --nssFlags:"-loqey"

Currently, the following configuration options are available:
- `userName`: the default name to add to the author section of new packages
    - default: git user.name
- `userEmail`: the default email used for the author section
    - default: git user.email
- `nssCompiler`: the path to the script compiler
    - default (Posix): `nwnsc`
    - default (Windows): `nwnsc.exe`
- `nssFlags`: the default flags to use on packages
    - default: `-lowqey`
- `erfUtil`: the path to the erf pack/unpack utility
    - default (Posix): `nwn_erf`
    - default (Windows): `nwn_erf.exe`
- `gffUtil`: the path to the gff conversion utility
    - default (Posix): `nwn_gff`
    - default (Windows): `nwn_gff.exe`
- `installDir`: the NWN installation directory
    - default (Linux): `~/.local/share/Neverwinter Nights`
    - default (Windows and Mac): `~/Documents/Neverwinter Nights`
- `vcs`: the version control system to use when making new packages
    - default: `git`
    - supported: `none`, `git`

 These options are meant to be separate from the package file (`nasher.cfg`)
 since they may depend on the user.
