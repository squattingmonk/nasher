# nasher
This is a command-line utility for managing a Neverwinter Nights script or
module repository.

## Contents

- [Description](#description)
- [Installation](#installation)
- [Requirements](#requirements)
- [Usage](#usage)
    - [Initializing a new package](#initializing-a-new-package)
    - [Listing build targets](#listing-build-targets)
    - [Building targets](#building-targets)
    - [Unpacking a file](#unpacking-a-file)
    - [Docker](#docker)
- [Configuration](#configuration)
- [Package Files](#package-files)
    - [Package Section](#package)
    - [Sources Section](#sources)
    - [Rules Section](#rules)
    - [Target Section](#target)

## Description
nasher is used to unpack an erf or module into a source tree, converting gff
files into json format. Since json is a text-based format, it can be checked
into git or another version-control system to track changes over time and make
it easier for multiple people to work on the same project simultaneously.
nasher can also rebuild the module or erf from those unpacked source files.

nasher is similar to [nwn-devbase](https://github.com/jakkn/nwn-devbase), but
it has some key differences:
1. nasher and the tools it uses are written in [nim](https://nim-lang.org)
   rather than Ruby, so they are much faster (handy for large projects) and can
   be distributed in binary form
2. nasher supports non-module projects (including erfs and haks)
3. nasher supports multiple build targets (e.g., an installable erf and a demo
   module)
4. nasher supports custom source tree layouts (e.g., dividing scripts into
   directories based on category)
5. nasher can install built targets into the NWN installation directory
6. nasher has not (yet) been tested on Windows (help wanted)
7. nasher does not (yet) provide a containerized Docker build
8. nasher does not provide tools for local testing with Docker
9. nasher uses json rather than yaml for storing gff files

## Installation
You can install nasher through `nimble`:

    nimble install nasher

Or by building from source:

    $ git clone https://github.com/squattingmonk/nasher.nim.git nasher
    $ cd nasher
    $ nimble install

If `nimble` has been configured correctly, the binary should be available on
your path.

## Requirements
- [nim](https://github.com/dom96/choosenim) >= 0.20.2
- [neverwinter.nim](https://github.com/niv/neverwinter.nim) >= 1.2.7
- [nwnsc](https://gitlab.com/glorwinger/nwnsc)

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

All of these commands accept multiple targets as parameters. In addition, you
can use the dummy target `all` to build all targets in the package.

    # Compile the "erf" and "demo" targets
    nasher compile erf demo

    # Compile all of the package's targets
    nasher compile all

The `convert`, `compile`, `pack`, and `install` commands are run in sequence.
If you want to install a target, you can just use the `install` command without
having to first use `convert`, `compile`, and `pack`.

All of these commands can delete the cache and trigger a clean build if passed
with `--clean`.

#### convert
Converts all json sources for the target to gff format. It also caches non-json
source files for later packaging (useful for non-erf or non-module targets).

#### compile
Compiles all script sources for the target.

#### pack
Packs the converted and compiled resources into the target file. The packed
file is placed into the package root directory. If the file to be packed
already exists in the package root, you will be prompted to overwrite it. You
can force answer the prompt by passing the `--yes`, `--no`, or `--default`
flags.

#### install
Installs the packed file into the appropriate folder in the NWN installation
path. If the file to be installed already exists at the target location, you
will be prompted to overwrite it. You can force answer the prompt by passing
the `--yes`, `--no`, or `--default` flags.

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

## Docker
[Docker](https://www.docker.com/products/docker-desktop)

### Example Usage
```
# Linux
docker run --rm -v ./:/nasher squattingmonk:nasher:latest

# Windows 
docker run --rm -v %cd%:/nasher squattingmonk:nasher:latest
```

### Init example
Because of docker limitations, we have to init the config file with default settings.
Example below:

```
# Linux
docker run --rm -v ./:/nasher squattingmonk:nasher:latest init --default

# Windows 
docker run --rm -v %cd%:/nasher squattingmonk:nasher:latest init --default
```

## Configuration
You can configure `nasher` using the `config` command (see `nasher config
--help` for detailed usage).

    # Set the default NWN installation path
    $ nasher config installDir "~/Documents/Neverwinter Nights"

Configuration options can also be passed to the commands directly using the
format `--option:value` or `--option:"value with spaces"`:

    # Compile with warnings on:
    $ nasher compile --nssFlags:"-loqey"

This syntax is also necessary in the `config` command when the value has words
beginning with a dash; otherwise these words are treated as options (a
limitation of the Nim parseopt module):

    # Incorrect
    $ nasher config nssFlags "-n /opts/nwn -owkey"

    # Correct
    $ nasher config --nssFlags:"-n /opts/nwn -owkey"

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
- `removeUnusedAreas`: whether to prevent areas not present in the source files
  from being referenced in `module.ifo`.
    - default: `true`
    - note: you will want to disable this if you have some areas that are
      present in a hak or override and not the module itself.

These options are meant to be separate from the package file (`nasher.cfg`)
since they may depend on the user.

## Package Files
A package file is a `nasher.cfg` file located in the package root. Package
files are used to specify the structure of the source tree and how to build
targets. Here is a sample package file:

``` ini
[Package]
name = "Core Framework"
description = "An extensible event management system for Neverwinter Nights"
version = "0.1.0"
author = "Squatting Monk <squattingmonk@gmail.com>"
url = "https://github.com/squattingmonk/nwn-core-framework"

[Sources]
include = "sm-utils/src/*.nss"
include = "src/**/*.{nss,json}"
exclude = "**/test_*.nss"

[Rules]
"hook_*.nss" = "src/Hooks"
"core_*" = "src/Framework"
"*" = "src"

[Target]
name = "default"
description = "An importable erf for use in new or existing modules"
file = "core_framework.erf"
exclude = "src/demo/**"
exclude = "**/test_*.nss"

[Target]
name = "demo"
description = "A demo module showing the system in action"
file = "core_framework.mod"
```

While you can write your own package file, the `init` command will create one
for you. It will show prompts for each section and provide useful defaults. If
you don't want to answer the prompts and just want to quickly initialize the
package, you can pass the `--default` flag when running `init`.

### Package
This section is optional. In the future, this information will be used to
publish packages for easy discovery and installation.

- `name`: a brief name for the package
- `description`: a description of the package. You can use `"""triple
  quotes"""` to enable multi-line descriptions.
- `version`: the package version
- `author`: the name and email of the package author. This field can be
  repeated if there are multiple authors; each author gets their own line.
- `url`: the location where the package can be downloaded

### Sources
This section is required. It describes the layout of the source tree. All paths
are relative to the package root.

- `include`: a glob pattern matching files to include (e.g.,
  `src/**/*.{nss,json}` to match all nss and json files in `src` and its
  subdirectories). This field can be repeated.
- `exclude`: a glob pattern matching files to exclude from sources. This field
  can be repeated.

When nasher looks for sources, it first finds all files that match any include
pattern and then filters out files that match any exclude pattern. In the
example package file, all nss and json files in `src` and its subdirectories
are included, except for those nss files that begin with `test_`.

### Rules
This section is optional. It tells nasher where to place extracted files that
do not already exist in the source tree. Rules take the form `"pattern" =
"path"`, where `pattern` is a glob pattern matching the filename and `path` is
the folder into which it should be placed. All paths are relative to the
package root.

When unpacking, nasher checks each extracted file against the source tree. If
the file does not exist in the source tree, it will be checked against each
rule. If `pattern` matches the filename, the file will be extracted to `path`.
If no pattern matches the filename, it will be placed into a directory called
`unknown` in the package root so the user can manually copy the file to the
proper place later.

In the example package file, nss files beginning with `hook_` are placed in
`src/Hooks`, all files beginning with `core_` are placed in `src/Core`, and all
other files are placed in `src`.

### Target
At least one target section is required. It is used to provide the name,
description, output file, and sources of each build target. This section can be
repeated, specifying a different target each time.

- `name`: the name of the target. This will be passed to the `convert`,
  `compile`, `pack`, and `install` commands. Each target must have a unique
  name.
- `file`: the name of the file that will be created, including the file
  extension.
- `description`: a description of the output file. This field is optional, but
  is recommended if your package has multiple build targets.
- `include`: a glob pattern matching source files to be used for this target.
  This field is optional. If supplied, this target will use only the supplied
  source files; otherwise, the target will use all source files included by the
  package. This field can be repeated.
- `exclude`: a glob pattern matching files to exclude from the sources for this
  target. This field is optional. If supplied, this target will exclude only
  those files that match the supplied patterns; otherwise, the target will
  exclude all files excluded by the package. This field can be repeated.

In the example package file, the `demo` target will use the package `include`
and `exclude` fields since it did not specify its own. However, the `default`
target excludes files in `src/demo` and its subdirectories; since it overrides
the package `exclude`, it needs to repeat the `exclude` line from the package
to avoid accidentally including nss files beginning with `test_`.
