# nasher

nasher is a command-line tool for converting a Neverwinter Nights module, hak,
or erf file into text-based source files and vice versa. This allows git-based
version control and team collaboration.

* nasher and the tools it uses are written in [Nim](https://nim-lang.org). They
  are fast (handy for large projects) and can be distributed in binary form.
* nasher supports non-module projects (including erfs, tlks, and haks)
* nasher supports multiple build targets (e.g., an installable erf and a demo
  module) from the same code base.
* nasher supports custom source tree layouts (e.g., dividing scripts into
  directories based on category).
* nasher can install built targets into the NWN installation directory or
  launch them in-game.
* nasher uses json or [NWNT](https://github.com/WilliamDraco/NWNT) for its text
  file format.

This guide is current as of nasher release 0.21.x.

* [Installation Options](#installation-options)
    * [Binary Releases](#binary-releases)
    * [Nimble](#nimble)
    * [Docker](#docker)
* [Getting Started](#getting-started)
    * [First-Time Setup](#first-time-setup)
    * [Basic Workflow](#basic-workflow)
    * [Getting Help](#getting-help)
* [Configuration](#configuration)
    * [nasher.cfg](#nashercfg)
        * [`[package]`](#package)
        * [`[target]`](#target)
        * [`[*.sources]`](#sources)
        * [`[*.rules]`](#rules)
        * [`[*.variables]`](#variables)
        * [Source Trees](#source-trees)
        * [Tips](#tips)
* [Commands](#commands)
    * [config](#config)
    * [init](#init)
    * [list](#list)
    * [unpack](#unpack)
    * [convert](#convert)
    * [compile](#compile)
    * [pack](#pack)
    * [install](#install)
    * [launch](#launch)
* [Errors](#errors)
* [FAQs](#faqs)
* [Contributing](#contributing)
* [Changelog](#changelog)
* [License](#license)

## Installation Options

### Binary Releases

*Note: This is the easiest way to install, and is recommended for most users.*

#### Requirements

[Download](https://github.com/squattingmonk/nasher/releases) latest version
of nasher for your OS and place a pointer to the location of the executable
file in your [`PATH` environment variable](https://superuser.com/a/284351).

In addition, you will need the following tools:
* [neverwinter.nim](https://github.com/niv/neverwinter.nim/releases) >= 1.6.4
* [nwnt](https://github.com/WilliamDraco/NWNT) >= 1.3.3
* [nwnsc](https://github.com/nwneetools/nwnsc/releases) >= 1.1.3
* [git](https://git-scm.com/downloads)

#### Tips
* Keep the binaries for nasher, neverwinter.nim, and nwnsc in the same
  location.
* Do not keep binaries in your nasher project folder
* Do not publish binaries with your source control repository. If you are
  collaborating, each team member should download and install the binaries
  individually.

### Nimble

*Note: this method is harder to set up, but makes it easier to update.*

First, install the following:
* [nim](https://nim-lang.org) and it package manager `nimble`. The easy way to
  install is to use [choosenim](https://github.com/dom96/choosenim).
* [nwnsc](https://github.com/nwneetools/nwnsc) >= 1.1.3
* [git](https://git-scm.com/downloads)

*Note: when building nasher, nimble will download and install neverwinter.nim
automatically. You do not need to install it yourself.*

Now you can have nimble download and install nasher:
```console
$ # Install the latest tagged version (recommended)
$ nimble install nasher

$ # Install the latest version from the master branch
$ nimble install nasher@#head

$ # Install a specific tagged version
$ nimble install nasher@#0.17.4
```

Alternatively, you can clone the repo and build it yourself (handy if you want
to make changes and contribute to development):
```console
$ git clone https://github.com/squattingmonk/nasher.git
$ cd nasher
$ nimble install
```

### Docker

You can also run with [docker](https://docs.docker.com/get-docker/) if you want
to get fancy with containers, but most people should use the other routes.

Docker commands are run with the same nomenclature as native nasher commands.
If you want to use docker, any time you see a native nasher command in this
document, you can replace it with the docker command. So the following are
equivalent:
```console
$ nasher <command>
$ docker run --rm -it -v ${pwd}:/nasher nwntools/nasher:latest <command>
```

You can also create an alias in your `.bashrc` and just use `nasher <command>`:
```console
alias nasher='docker run --rm -it -v ${pwd}:/nasher nwntools/nasher:latest '
```

#### Tips
Create batch/script files to run your most common nasher commands since the
docker commands can be rather verbose. An excellent example of this is in [The
Frozen North](https://github.com/b5635/the-frozen-north) GitHub repository.

## Getting Started

### First-Time Setup
nasher will detect nwnsc and the neverwinter.nim tools if they are in your
`PATH`. You can also use nasher's `config` command to set the proper locations:
```console
$ # Set the path to nwnsc
$ nasher config nssCompiler "%USERPROFILE%/bin/nwnsc.exe"      # Windows
$ nasher config nssCompiler "~/.local/bin/nwnsc"               # Posix

$ # Set the path to nwn_erf
$ nasher config erfUtil "%USERPROFILE%/bin/nwn_erf.exe"        # Windows
$ nasher config erfUtil "~/.local/bin/nwn_erf"                 # Posix

$ # Set the path to nwn_gff
$ nasher config gffUtil "%USERPROFILE%/bin/nwn_gff.exe"        # Windows
$ nasher config gffUtil "~/.local/bin/nwn_gff"                 # Posix

$ # Set the path to nwn_tlk
$ nasher config tlkUtil "%USERPROFILE%/bin/nwn_tlk.exe"        # Windows
$ nasher config tlkUtil "~/.local/bin/nwn_tlk"                 # Posix
```
nasher will also detect NWN if it was installed by Steam, Beamdog, or GOG. If
you are having issues getting nasher to recognize your NWN install, you can set
the `NWN_ROOT` environment variable to the path. Similarly, the `NWN_HOME`
environment variable should point to the local of your NWN user directory
(i.e., where to install modules, haks, etc.). For example:
```bash
# In your .bashrc
export NWN_ROOT="$HOME/.local/share/Steam/steamapps/common/Neverwinter Nights"
export NWN_HOME="$HOME/Documents/Neverwinter Nights"
```
Further information on configuration can be found [below](#configuration).

### Basic Workflow

1. Initialize your directory as a nasher project and follow the prompts:
   ```console
   $ nasher init myproject
   $ cd myproject
   ```
   When the prompt asks for your target's filename, make sure you put the
   filename of the module you want to use for the project (e.g.,
   `mymodule.mod`)
2. Unpack your module: `nasher unpack`
3. Edit the source files as needed
4. Pack and install the module: `nasher install`
5. Test the module in-game
6. Make changes in the toolset
7. Unpack the changes back into your nasher project: `nasher unpack`

Repeat steps 3-7 until you are satisfied with your changes, then commit the
files in git and push to your remote repo:
```console
$ git commit -am "My commit message"
$ git push origin master
```

Now share the repo with your team. They can download the repo and build your
module from the source files:
```console
$ git clone https://github.com/myusername/myproject
$ cd myproject
$ nasher install
```

### Getting Help

You can get help for nasher or one of its commands using the `--help` flag:
```console
$ nasher --help       # General help
$ nasher init --help  # Command-specific help
```

If you're still stuck, you can get assistance in several locations:
* Neverwinter Vault Discord Server ([invitation](https://discord.gg/pWVqMRX))
  ([workflow-and-tools
  channel](https://discord.com/channels/255017439371329537/511127010962046986))
* NWNX Discord Server ([invitation](https://discord.gg/fNZp2ND)) ([general
  channel](https://discord.com/channels/382306806866771978/382306806866771980))
* [nasher GitHub issues](https://github.com/squattingmonk/nasher/issues)

## Configuration

Nasher can be configured for user-specific settings with the [`config`](#config)
command. Configuration keys can be set on a global, per-package, or per-command
basis. See the [keys](#keys) section for available settings.

### nasher.cfg

A nasher package must have a `nasher.cfg` file in the package root directory.
This file contains package-specific settings that should be the same across all
instances of the package. It does not vary for different users.

Here is a basic `nasher.cfg` that will serve for simple projects:

```toml
[package]
  [package.sources]
  include = "src/**/*.{nss,json}"

  [package.rules]
  "*" = "src"

[target]
name = "default"
file = "demo.mod"
description = ""
```

Here is a larger one showing more features that nasher supports:

```toml
[package]
name = "Core Framework"
description = "An extensible event management system for Neverwinter Nights"
version = "0.1.0"
author = "Squatting Monk <squattingmonk@gmail.com>"
url = "https://github.com/squattingmonk/nwn-core-framework"

# This key is inherited by targets that don't define it themselves. It uses a
# variable to refer to the target's name, which is resolved for each target
# (e.g., the target "scripts" will have the file "scripts.hak").
file = "$target.hak"

  # You can define your own variables to reference in other keys
  [package.variables]
  sm-utils = "../sm-utils/src"

  [package.sources]
  include = "${sm-utils}/*.nss" # This variable is expanded
  include = "src/**/*.{nss,json}"
  exclude = "**/test_*.nss"

  [package.rules]
  "hook_*.nss" = "src/Hooks"
  "core_*" = "src/Framework"
  "*" = "src"

# The first target is the default target and will be used by most commands when
# no target has been explicitly passed. This should normally be your most
# common operation, such as packing your module file.
[target]
name = "demo"
description = "A demo module showing the system in action"
file = "core_framework.mod"
modName = "Core Framework Demo Module"
modMinGameVersion = "1.69"

# erf, hak, and tlk files can be packed just like a module file.
[target]
name = "framework"
description = "An importable erf for use in new or existing modules"
file = "core_framework.erf"

  [target.sources]
  exclude = "src/demo/**"
  exclude = "**/test_*.nss"

# These targets are members of the "haks" group. You can build them all with one
# command using "nasher pack haks". They all inherit the package-level "file"
# key.
[target]
name = "scripts"
group = "haks"
description = "A hak file containing compiled scripts"

  # Filtering optional files, such as .nss, .gic, and .ndb, can greatly reduce
  # packed file size
  [target.sources]
  include = "src/**/*.nss"
  filter = "*.nss"

[target]
name = "blueprints"
group = "haks"
description = "A hak file containing blueprints"

  [target.sources]
  include = "src/blueprints/*.json"

[target]
name = "tlk"
description = "Custom talk file for PW"
file = "myPWtlk.tlk"

  [target.sources]
  include = "src/tlk/*.json"
```

While you can write your own package file, the [`init`](#init) command will
create one for you. It will show prompts for each section and provide useful
defaults. If you don't want to answer the prompts and just want to quickly
initialize the package, you can pass the `--default` flag when running `init`.

#### `[package]`

This section provides a places to note the package's author, description, name,
version, and url. This data is currently not used by any nasher commands, but
that may change in the future. You can skip it with the `--skipPkgInfo` flag.

| Field         | Repeatable | Description                                                          |
| ---           | ---        | ---                                                                  |
| `name`        | no         | package name                                                         |
| `description` | no         | package description; """triple quotes for multi-line descriptions""" |
| `version`     | no         | package version                                                      |
| `url`         | no         | web location where the package can be downloaded                     |
| `author`      | yes        | name/email of the author                                             |

Some fields, while optional, are inherited from the package by
[targets](#target) if set in this section:

| Field               | Repeatable | Description                                                               |
| ---                 | ---        | ---                                                                       |
| `file`              | no         | filename including extension be created; can optionally include path info |
| `group`             | yes        | a group a target may belong to; used to build multiple targets at once    |
| `flags`             | yes        | command line arguments to send to nwnsc at compile-time                   |
| `branch`            | no         | the git branch to use for source files                                    |
| `modName`           | no         | the name to give a module target file                                     |
| `modMinGameVersion` | no         | the minimum game version to run a module target file                      |
| `modDescription`    | no         | the description for a module target file                                  |

Normally, the first target specified in `nasher.cfg` will be the default.
However, you can manually specify the target to use as the default in the
`[package]` section:

| Field     | Repeatable | Description                    |
| ---       | ---        | ---                            |
| `default` | no         | the name of the default target |

#### `[target]`

At least one target must be specified. This section provides a target name,
description, and output filename. Many of these fields will be inherited if they
are not set for this target. Normally, missing values are inherited from the
`[package]` section. However, you can instead inherit from another target using
the `parent` key. Its value is the name of another target. The parent target
must be specified before the child target.

| Field               | Repeatable | Inherited | Description                                                                         |
| ---                 | ---        | ---       | ---                                                                                 |
| `name`              | no         | no        | name of the target; must be unique among targets                                    |
| `default`           | no         | no        | whether the target should be the default (true/false)                               |
| `description`       | no         | no        | an optional field that describes the target                                         |
| `parent`            | no         | no        | a target to inherit missing values from (if missing, will inherit from `[package]`) |
| `file`              | no         | yes       | filename including extension be created; can optionally include path info           |
| `group`             | yes        | yes       | a group this target belongs to; used to build multiple targets at once              |
| `flags`             | yes        | yes       | command line arguments to send to nwnsc at compile-time                             |
| `branch`            | no         | yes       | the git branch to use for source files                                              |
| `modName`           | no         | yes       | the name to give a module target file                                               |
| `modMinGameVersion` | no         | yes       | the minimum game version to run a module target file                                |
| `modDescription`    | no         | yes       | the description for a module target file                                            |

#### `[*.sources]`

The sources subsection tells nasher the locations of the source files needed for
a target. It can be set at the package level (i.e., `[package.rules]`) or at the
target level (i.e., `[target.rules]`). If a target is missing one of these
fields, it will be inherited from the package or parent.

All of these fields are repeatable.

| Field     | Description                                                         |
| ---       | ---                                                                 |
| `include` | glob pattern matching files to include                              |
| `exclude` | glob pattern matching files to exclude                              |
| `filter`  | glob pattern matching cached files to be excluded after compilation |

Refer to the [source trees](#source-trees) section to understand how these
fields are used by targets.

#### `[*.rules]`

When you [`unpack`](#unpack) a file, nasher searches the source tree to find
where to put it each of its source files. If the file is not found in the source
tree, it uses the rules in this section.

Rules take the form `"pattern" = "path"`. `pattern` is a glob pattern matching
a filename. `path` is a directory path in which to place the file. All paths
are relative to the package root (i.e., the directory where your `nasher.cfg` is
located).

A file is compared to the each rule's `pattern`; if it matches, the file is
placed into the rule's `path` and the next file is evaluated. Files that fail
to match any rule's pattern are placed into a directory called `unknown` in the
project root for you to sort manually. To avoid this, use a catch-all rule
(`"*" = "path"`) at the end to match any files that did not match other rules.

[Targets](#target) can define their own `[target.rules]` section. If they don't
they will inherit from their parent target (if set) or the `[package.rules]`
section.

#### `[*.variables]`

You can define variables that can be referenced in any target field except for
`name`. You can set variables in the `[package.variables]` section (to apply to
all targets) or the `[target.variables]` section (to apply to a single target).
Child targets may also inherit variables from parent targets. The key is the
variable name, while the value is what it should resolve to. The target
variables table is merged with the inherited variables table to allow missing
keys to be inherited.

If a variable referenced is not found, nasher will also check the environment
variables. If a variable is not found in the table or the environment, an error
is thrown.

Variables can be referenced using the syntax `$variable` or `${variable}`. The
latter syntax allows variables to include non-alphanumeric characters or to be
adjacent to alphanumeric characters that are not part of the variable name
(e.g., `${foo}bar`).

One variable is available by default: `$target` resolves to the name of the
current target. This allows some neat things:

```toml
# This package has two targets, "foo" and "bar", that yield a file
# named "foo.hak" and "bar.hak", respectively using the source files
# in "src/foo" and "src/bar" respectively.
[package]
file = "$target.hak"

  [package.sources]
  include = "src/$target/*"

[target]
name = "foo"

[target]
name = "bar"
```

This feature can also be used to easily reference out-of-tree projects:

```toml
[package]

  [package.variables]
  sm-utils = "../sm-utils/src" # Can be used by any target or rule

  [package.sources]
  include = "${sm-utils}/*.{nss,json}" # include files in sm-utils
  include = "src/**/*.{nss,json}"

  [package.rules]
  "util_*" = "${sm-utils}" # Unpack util files to sm-utils
  "*" = "src/$target" # Unpack unknown file to target's source dir

[target]
name = "demo"
file = "core_framework.mod"

[target]
name = "utils"
file = "sm_utils.erf"

  [target.sources]
  include = "${sm-utils}/*.{nss,json}" # include only files in sm-utils
```

Since nasher checks environment variables, you can place user-specific
information in an environment variable. For example, if you want to include a
file in a target using an absolute path, you could place it directly in the
`nasher.cfg`, but this would not be useful for other users of your project:

```toml
[target]
name = "mymodule"
file = "my_module.mod"

  [target.sources]
  include = "src/*.{nss,json}"
  include = "/home/squattingmonk/.local/src/nwscript/utils/util_i_color.nss"
```

This makes collaboration difficult, since other users of this project would have
to edit the `nasher.cfg` to change the location of the file to where it is on
their system. Instead, you can use an environment variable:

```toml
[target]
name = "mymodule"
file = "my_module.mod"

  [target.sources]
  include = "src/*.{nss,json}"
  include = "${SM_UTILS}/util_i_color.nss"
```

```bash
export SM_UTILS=/home/squattingmonk/.local/src/nwscript/utils
```

Other users can then set the environment variable to the location of their
choice without changing the `nasher.cfg`.

#### Source Trees

A target's source tree is built from the `include`, `exclude`, and `filter`
fields. Remember, each of these are inherited from the `[package.sources]`
section if not specified in the `[target.sources]` section.

nasher uses [glob pattern](https://en.wikipedia.org/wiki/Glob_(programming))
matching to identify desired files (e.g., `src/**/*.{nss,json}` matches all
`.nss` or `.json` files in subdirectories of `src`).

1. The `include` patterns are expanded to a source file list.
2. Each of these files is checked against each `exclude` pattern; matches are
   removed from the list.

Pack operations ([`convert`](#convert), [`compile`](#compile), [`pack`](#pack),
[`install`](#install), and [launch](#launch)) commands use the source tree as
follows:

1. The `convert` and `compile` commands process the source files and output to a
   cache directory.
2. Before the `pack` command is run, each cached file is checked against each
   `filter` pattern; matches are excluded from the final packaged file. Note
   that filters should not have any path information since they are compared to
   files in the cache, not the source tree.

[`unpack`](#unpack) uses the source tree as follows:

1. The source tree is converted to a mapping of binary files to source paths
   (e.g., `module.ifo => src/module.ifo.json`).
2. The target file is unpacked into a cache directory.
3. Each file in the cache directory is checked against the map; matching files
   are copied the corresponding source path.
4. The remaining files' names are compared to the target's [rules](#rules);
   matching files are moved to the corresponding source path. Note that rule
   patterns should not have any path information since they are compared to
   files in the cache, not the source tree.
5. Files not caught by the rules are placed in the `unknown` folder in the
   package directory.

#### Tips

* [Rules](#rules) are only referenced during an [`unpack`](#unpack) operation.
* If starting with a valid module file, unpack the module to the `src` folder
  and create your desired folder structure with your favorite file explorer. It
  is rarely necessary to have much more than a single entry in the `[*.rules]`
  section (`"*" = "src"`). When a module is packed with nasher, the source
  location of each file is noted and unpacked back to that location, so a
  detailed `[*.rules]` section is usually not necessary.
* Make the [`[package.sources]`](#sources) section as inclusive as possible and
  use the `[target.sources]` `exclude` field to narrow down the included files
  needed by the target.
* Use target groups to build multiple targets at once. For example, make all of
  your hak targets members of the `haks` group, then run `nasher pack haks` to
  build only the hak files.

## Commands

The syntax for nasher operation is `nasher <command> [options] [<argument>...]`.

You can use the following options with most nasher commands:

| Option         | Description                                        |
| ---            | ---                                                |
| `-h`, `--help` | displays help for nasher or a specific command     |
| `--yes`        | automatically answer yes to all prompts            |
| `--no`         | automatically answer no to all prompts             |
| `--default`    | automatically accept the default answer to prompts |
| `--verbose`    | increases the feedback verbosity                   |
| `--debug`      | enable debug logging (implies `--verbose`)         |
| `--quiet`      | disable all logging except errors                  |
| `--no-color`   | disable color output                               |

### config

    nasher config [options] [<key> [<value>]]
    nasher config [options] --<key>[:"<value>"]

Gets, sets, or unsets user-defined configuration options. These options can be
local (package-specific) or global (across all packages). Regardless, they
override default nasher settings.

Global configuration is stored in `%APPDATA%\nasher\user.cfg` on Windows or in
`$XDG_CONFIG/nasher/user.cfg` on Linux and Mac. These values apply to all
packages.

Local (package-level) configuration is stored in `.nasher/user.cfg` in the
package root directory. Any values defined here take precedence over those in
the global config file. This file will be ignored by git.

Global and local configuration options can be overridden on a per-command basis
by passing the key/value pair as an option to the command.

#### Options

| Option     | Description                                                     |
| ---        | ---                                                             |
| `--global` | Apply to all packages (default)                                 |
| `--local`  | Apply to the current package only                               |
| `--get`    | Get the value of `<key>` (default when `<value>` is not passed) |
| `--set`    | Set `<key>` to `<value>` (default when `<value>` is passed)     |
| `--unset`  | Delete the key/value pair for `<key>`                           |
| `--list`   | Lists all key/value pairs in the config file                    |

#### Keys

- `userName`: the default name to add to the author section of new packages
    - default: git user.name
- `userEmail`: the default email used for the author section
    - default: git user.email
- `nssCompiler`: the path to the script compiler
    - default (Posix): `nwnsc`
    - default (Windows): `nwnsc.exe`
- `nssFlags`: the default flags to use on packages
    - default: `-lowqey`
    - note: since nwnsc can read the `NWN_ROOT` environment variable to find
      your NWN install, it is preferable to use that rather than passing the
      location through `nssFlags`. If `NWN_ROOT` is set (or if nasher can find
      your NWN install without it), nwnsc should work fine using the default
      values of `-lowqey`.
- `nssChunks`: the maximum number of scripts to process with one call to nwnsc
    - default: `500`
    - note: set this to a lower number if you run into errors about command
      lengths being too long.
- `erfUtil`: the path to the erf pack/unpack utility
    - default (Posix): `nwn_erf`
    - default (Windows): `nwn_erf.exe`
- `erfFlags`: additional flags to pass to the erf utility
    - default: ""
- `gffUtil`: the path to the gff conversion utility
    - default (Posix): `nwn_gff`
    - default (Windows): `nwn_gff.exe`
- `gffFlags`: additional flags to pass to the gff utility
    - default: ""
- `gffFormat`: the format to use to store gff files
    - default: `json`
    - supported: `json, nwnt`
- `tlkUtil`: the path to the tlk conversion utility
    - default (Posix): `nwn_gff`
    - default (Windows): `nwn_gff.exe`
- `tlkFlags`: additional flags to pass to the tlk utility
    - default: ""
- `tlkFormat`: the format to use to store tlk files
    - default: `json`
    - supported: `json`
- `installDir`: the NWN user directory where built files should be installed
    - default (Linux): `~/.local/share/Neverwinter Nights`
    - default (Windows and Mac): `~/Documents/Neverwinter Nights`
    - note: It is recommended  you use the `NWN_HOME` environment variable
      instead as this can be read by other programs. If `NWN_HOME` is not set,
      nasher will use the value from this flag to populate it.
- `gameBin`: the path to the nwmain binary
    - note: nasher should be able to find the binary without setting this.
      Setting the `NWN_ROOT` environment variable to the location of your NWN
      install makes this setting obsolete for most users.
- `serverBin`: the path to the nwserver binary (if not using default Steam path)
    - note: nasher should be able to find the binary without setting this.
      Setting the `NWN_ROOT` environment variable to the location of your NWN
      install makes this setting obsolete for most users.
- `vcs`: the version control system to use when making new packages
    - default: `git`
    - supported: `none`, `git`
- `removeUnusedAreas`: whether to prevent areas not present in the source files
  from being referenced in `module.ifo`.
    - default: `true`
    - note: you will want to disable this if you have some areas that are
      present in a hak or override and not the module itself.
- `useModuleFolder`: whether to use a subdirectory of the `modules` folder to
  store unpacked module files. This feature is useful only for NWN:EE users.
    - default: `true` during install; `true` during unpacking unless explicitly
      specifying a file to unpack
- `truncateFloats`: the max number of decimal places to allow after floats in
  gff files. Use this to prevent unneeded updates to files due to insignificant
  float value changes.
  - default: `4`
  - supported: `1` - `32`
- `modName`: the name for any module file to be generated by the target. This
  is independent of the filename. Only relevant when `convert` will be called.
  - default: ""
- `modMinGameVersion`: the minimum game version that can run any module file
  generated by the target. Only relevant when `convert` will be called.
  - default: ""
  - note: if blank, the version in the `module.ifo` file will be unchanged.
- `modDescription`: the description for a module file generated by a target.
  Only relevant when `convert` will be called.
  - default: ""
  - note: If blank, the description in the `module.ifo` file will be unchanged.
- `onMultipleSources`: an action to perform when multiple source files of the
  same name are found for a target.
  - default: `choose`
  - supported: `choose` (choose manually), `default` (accept the first choice),
    `error` (abort with an error message)
  - note: this option currently only applies for the `convert`, `compile`,
    `pack`, `install`, `play`, `test`, and `serve` commands. The `unpack`
    command still makes you choose where to unpack a file if multiple options
    are found.
- `abortOnCompileError`: whether to automatically abort packing, installing, or
   testing a target if `nwnsc` encounters errors.
   - default: `false`
   - supported: `true`, `false`
- `packUnchanged`: whether to force packing a file if the source files have not
  changed since the last pack.
  - default: `false`
  - supported:  `true`, `false`

#### Examples

```console
$ # Set the path to nwnsc
$ nasher config nssCompiler ~/.local/bin/nwnsc

$ # Get the path to nwnsc
$ nasher config nssCompiler
~/.local/bin/nwnsc

$ # Unset the path to nwnsc
$ nasher config --unset nssCompiler

$ # List all options set in the config files
$ nasher config --list          # global
$ nasher config --list --local  # local
```

#### Tips
* The `--` operator causes all following arguments to be treated as positional
  arguments, even if they look like options. This is useful when setting config
  keys to values starting with `-`: `nasher config -- nssFlags "-n /opt/nwn"`
* Keys like `nssCompiler` and `installDir` work best as global options
* Keys like `modName` or `useModuleFolder` work best as local options
* `user.cfg` files are intentionally ignored by git. Do not include them in
  your commits, since other users may require different values than those that
  work on your machine
* Some gotchas to watch out for when setting `--nssFlags`:
    * Quote paths with spaces when passing to `-n`.
    * Do not include other configurable nwnsc flags, such as `-b` and `-i`.
      Those flags can be passed to nwnsc per target through nasher.cfg.
    * It's better to use the `NWN_ROOT` environment variable with the default
      `-lowqey` value rather than the `-n /path/to/NWN/install` method. This
      ensures that nasher, nwnsc, and the neverwinter.nim tools are always
      using the same NWN install location.

### init

    nasher init [options] [<dir> [<file>]]

Creates a new nasher package, launching a dialog to generate a
[nasher.cfg](#nashercfg) file and initializing the new package as a git
directory.

#### Options

| Flag            | Description                                          |
| ---             | ---                                                  |
| `--default`     | skip the package generation dialog and manually edit |
| `--vcs:none`    | do not initialize as a git repository                |
| `--file:<file>` | unpack the contents of `<file>` into the new package |

#### Examples

```console
$ # Create a new nasher package in the current directory
$ nasher init

$ # Create a new nasher package in the directory foo
$ nasher init foo

$ # Create a new nasher package from a module file
$ nasher init foo --file:"~/Documents/Neverwinter Nights/modules/foobar.mod"
```

### list

    nasher list [options] [<target>...]

Lists all named `<target>`s defined the in [nasher.cfg](#nashercfg) along with
their descriptions, source file patterns, and the name of the file that will be
generated. If a target is not passed, will list all targets. The first listed
target is the default for other commands.

#### Options

| Flag        | Description               |
| ---         | ---                       |
| `--quiet`   | list only target names    |
| `--verbose` | list source files as well |

### unpack

    nasher unpack [options] [<target> [<file>]]

Unpacks a file into the project source tree for the given target.

If a target is not specified, nasher will use the first target found in the
[nasher.cfg](#nashercfg) file. If a file is not specified, nasher will search
for the target's file in the NWN install directory.

Each extracted file is checked against the target's source tree (as defined in
the `[Target]` section of the nasher.cfg). If the file only exists in one
location, it is copied there, overwriting the existing file. If the file exists
in multiple folders, you will be prompted to select where it should be copied.

If the extracted file does not exist in the source tree already, it is checked
against each pattern listed in the `[Rules]` section of the nasher.cfg. If a
match is found, the file is copied to that location.

If, after checking the source tree and rules, a suitable location has not been
found, the file is copied into a folder in the project root called `unknown` so
you can manually move it later.

If an unpacked source would overwrite an existing source, its `sha1` checksum
is checked against that from the last pack/unpack operation. If the sum is
different, the file has changed. If the source file has not been updated since
the last pack or unpack, the source file will be overwritten by the unpacked
file. Otherwise you will be prompted to overwrite the source file. The default
answer is to keep the existing source file.

#### Options

| Flag                    | Description                                                       |
| --                      | ---                                                               |
| `--file`                | the file or directory to unpack into the target's source tree     |
| `--removeDeleted`       | remove source files not present in the file being unpacked        |
| `--removeDeleted:false` | do not remove source files not present in the file being unpacked |

#### Examples

```console
$ # Unpack the default target's installed file
$ nasher unpack

$ # Unpack the target foo's installed file
$ nasher unpack foo

$ # Unpack the file myModule.mod using the myNWNServer target
$ nasher unpack myNWNServer --file:myModule.mod
```

### convert

    nasher convert [options] [(all | <target>...)]

Converts all JSON sources for `<target>` into their GFF counterparts. The
output files are placed in `.nasher/cache/<target>`.

If not supplied, `<target>` will default to the first target defined in the
package's [`nasher.cfg`](#nashercfg). The dummy target `all` runs the command
on all defined targets in a loop. You can also specify multiple targets by
separating them with spaces.

*Note*: this command is called by [`pack`](#pack), so you don't need to run it
separately unless you want to convert files without compiling and packing.

#### Options

| Argument                        | Description                                                        |
| ---                             | ---                                                                |
| `--clean`                       | clears the cache before packing                                    |
| `--modName:<name>`              | sets the `Mod_Name` value in `module.ifo` to `<name>`              |
| `--modMinGameVersion:<version>` | sets the `Mod_MinGameVersion` value in `module.ifo` to `<version>` |
| `--modDescription:<desc>`       | sets the `Mod_Description` value in `module.ifo` to `<desc>`       |

#### Examples

```console
$ # Convert the first target in nasher.cfg
$ nasher convert

$ # Convert the "demo" target
$ nasher convert demo

$ # Convert the "demo" and "testing" targets
$ nasher convert demo test
```

### compile

    nasher compile [options] [(all | <target>...)]

Compiles all nss sources for `<target>`. The input and output files are placed
in `.nasher/cache/<target>`. nwnsc is used as the compiler and compilation
errors will be displayed with reference to filename, line number, and general
error description.

If not supplied, `<target>` will default to the first target defined in the
package's [`nasher.cfg`](#nashercfg). The dummy target `all` runs the command
on all defined targets in a loop. You can also specify multiple targets by
separating them with spaces.

nasher will only recompile scripts that have changed since the target was last
compiled or that include scripts that have changed since the last compile
(chained includes are followed). This behavior can be overridden with the
`--clean` flag.

A single file can be compiled with the `--file:<file>` flag. `<file>` can be a
full path to a script, in which case the script must be within the target's
source tree. Alternatively, you can pass just a filename, in which case the
version of the script matched by the target's source rules will be used.

*Note*: this command is called by [`pack`](#pack), so you don't need to run it
separately unless you want to compile scripts files without packing.

#### Options

| Argument       | Description                             |
| ---            | ---                                     |
| `--clean`      | clears the cache before packing         |
| `-f`, `--file` | compiles specific file; can be repeated |

#### Examples

```console
$ # Compile the first target in nasher.cfg
$ nasher compile

$ # Compile the "demo" target
$ nasher compile demo

$ # Compile a single file used by the default target (by full path)
$ nasher compile --file:src/nss/myfile.nss

$ # Compile a single file used by a particular target (by filename)
$ nasher compile demo --file:myfile.nss
```

### pack

    nasher pack [options] [(all | <target>...)]

[Converts](#convert), [compiles](#compile), and packs all sources for
`<target>` into a module, hak, erf, or tlk. The component files are placed in
`.nasher/cache/<target>`, but the packed file is placed in the package root.

If not supplied, `<target>` will default to the first target defined in the
package's [`nasher.cfg`](#nashercfg). The dummy target `all` runs the command
on all defined targets in a loop. You can also specify multiple targets by
separatng them with spaces.

If the packed file would overwrite an existing file, you will be prompted to
overwrite the file. The newly packaged file will have a modification time equal
to the modification time of the newest source file. If the packed file is older
than the existing file, the default is to keep the existing file.

*Note*: this command is called by [`install`](#install), so you don't need to
run it separately unless you want to pack files without installing.

#### Options

| Argument                        | Description                                                        |
| ---                             | ---                                                                |
| `--clean`                       | clears the cache before packing                                    |
| `--file:<file>`                 | specify the location for the output file                           |
| `--noConvert`                   | do not convert updated json files                                  |
| `--noCompile`                   | do not recompile updated scripts                                   |
| `--modName:<name>`              | sets the `Mod_Name` value in `module.ifo` to `<name>`              |
| `--modMinGameVersion:<version>` | sets the `Mod_MinGameVersion` value in `module.ifo` to `<version>` |
| `--modDescription:<desc>`       | sets the `Mod_Description` value in `module.ifo` to `<desc>`       |
| `--abortOnCompileError`         | abort packing if errors encountered during compilation             |
| `--packUnchanged`               | continue packing a file if there are no changed files included     |

#### Examples

```console
$ # Pack the first target in nasher.cfg
$ nasher pack

$ # Clear the cache and convert, compile and pack the "demo" target
$ nasher pack demo --clean

$ # Pack the "module" target into "modules/mymodule.mod", setting its name to
$ # "My Module" and its minimum support game version to 1.69
$ nasher pack module --file:"modules/mymodule.mod" --modName:"My Module" --modMinGameVersion:1.69
```

### install

    nasher install [options] [(all | <target>...)]

[Converts](#convert), [compiles](#compile), and [packs](#pack) all sources for
`<target>`, then installs the packed file into the NWN installation directory.

If not supplied, `<target>` will default to the first target defined in the
package's [`nasher.cfg`](#nashercfg). The dummy target `all` runs the command
on all defined targets in a loop. You can also specify multiple targets by
separatng them with spaces.

If the file to be installed would overwrite an existing file, you will be
prompted to overwrite it. The default answer is to keep the newer file. If the
`useModuleFolder` configuration setting is TRUE or not set, a folder containing
all converted and compiled files will be installed into the same directory as
the module (`.mod`) file.

#### Options

| Argument                        | Description                                                        |
| ---                             | ---                                                                |
| `--clean`                       | clears the cache before packing                                    |
| `--noConvert`                   | do not convert updated json files                                  |
| `--noCompile`                   | do not recompile updated scripts                                   |
| `--noPack`                      | do not re-pack the file (implies `--noConvert` and `--noCompile`)  |
| `--file:<file>`                 | specify the file to install                                        |
| `--installDir:<dir>`            | the location of the NWN user directory                             |
| `--modName:<name>`              | sets the `Mod_Name` value in `module.ifo` to `<name>`              |
| `--modMinGameVersion:<version>` | sets the `Mod_MinGameVersion` value in `module.ifo` to `<version>` |
| `--modDescription:<desc>`       | sets the `Mod_Description` value in `module.ifo` to `<desc>`       |
| `--abortOnCompileError`         | abort installation if errors encountered during compilation        |
| `--packUnchanged`               | continue packing a file if there are no changed files included     |

#### Examples
```console
$ # Install the first target in nasher.cfg
$ nasher install

$ # Install the "demo" target to /opt/nwn without re-packing
$ nasher install demo --installDir:"/opt/nwn" --noPack

$ # Special case for Docker usage. When issuing the install and launch commands,
$ # docker requires access to the NWN documents folder, so we attach two volumes:
$ # - the first volume assigns the nasher project folder (source files)
$ # - the second volume assigns the NWN user directory
$ docker run --rm -it -v ${pwd}:/nasher -v "~/Documents/Neverwinter Nights":/nasher/install nwntools/nasher:latest install <target> --yes
```

### launch

    nasher (serve|play|test) [options] [<target>...]

[Converts](#convert), [compiles](#compile), [packs](#pack) and
[installs](#install) all sources for `<target>`, installs the packed file into
the NWN installation directory, then launches NWN and loads the module. This
command is only valid for module targets.

#### Options

| Argument                        | Description                                                        |
| ---                             | ---                                                                |
| `--clean`                       | clears the cache before packing                                    |
| `--noConvert`                   | do not convert updated json files                                  |
| `--noCompile`                   | do not recompile updated scripts                                   |
| `--noPack`                      | do not re-pack the file (implies `--noConvert` and `--noCompile`)  |
| `--file:<file>`                 | specify the file to install                                        |
| `--installDir:<dir>`            | the location of the NWN user directory                             |
| `--modName:<name>`              | sets the `Mod_Name` value in `module.ifo` to `<name>`              |
| `--modMinGameVersion:<version>` | sets the `Mod_MinGameVersion` value in `module.ifo` to `<version>` |
| `--modDescription:<desc>`       | sets the `Mod_Description` value in `module.ifo` to `<desc>`       |
| `--abortOnCompileError`         | abort launching if errors encountered during compilation           |
| `--packUnchanged`               | continue packing a file if there are no changed files included     |
| `--gameBin:<path>`              | path to the `nwmain` binary file                                   |
| `--serverBin:<path>`            | path to the `nwserver` binary file                                 |

#### Examples

```console
$ # Install the first target in nasher.cfg and launch with nwserver
$ nasher serve

$ # Install the "demo" and play in-game
$ nasher play demo

$ # Install the "demo" target and play using the first character in the localvault
$ nasher test demo
```

## Errors

* **`"No source files found for target"`** \
  Caused by improper sourcing (`include = `) in either the `[*.sources]` or
  `[target]` section in your [`nasher.cfg`](#nashercfg).

* **`"This is not a nasher repository. Please run init"`** \
  Caused by running any nasher command except `nasher config --global` before
  running [`nasher init`](#init) in the project folder.

  Caused by incorrectly referencing the present working directory in the
  `docker run` command. The reference can be CLI-specific. For example, Bash
  wants to see `$(pwd)` while PowerShell requires `${pwd}`. Look up the
  appropriate reference for your shell. `%cd%` only works for Windows
  `cmd.exe`.

* **`"The following areas do not have matching .git files and will not be
  accessible in the toolset"`** \
  When the area list is built during the conversion process, nasher matches the
  list of `.are` files with `.git` files. This warning will list any `.are`
  files that do not have matching `.git` files.

* **`"This module does not have a valid starting area!"`** \
  A module cannot be packed/installed without a valid starting area. Either
  extract a valid starting area into the nasher project folder or manually edit
  your `module.ifo.json` file's `Mod_Entry_Area` key to reference an existing
  area.

* **`"this answer cannot be blank. Aborting..."`** \
  Answer to prompt required, but not provided.

* **`"not a valid choice. Aborting..."`** \
  User selected an invalid multiple-choice answer.

* **`"Could not create {outFile}. Is the destination writeable?"`** \
  Raised if a destination folder for file conversion does not have write
  permissions. Can also be raised if there is another error converting the file
  to `.json` format. If your permissions are set correctly, the problem is
  likely a json source file with invalid syntax.

## FAQs

* **Can I use absolute or relative paths?** \
  Yes.

* **I really need nasher to do something it doesn't. Can you add this
  feature?** \
  nasher is actively maintained and new features are constantly added. If your
  request fits within the scope for nasher, it can likely be added. File an
  [issue](https://github.com/squattingmonk/nasher/issues) and it will be
  addressed shortly.

* **I thought using nasher was supposed to be easy, why is it so difficult?** \
  Getting used to a command-line workflow can be a little daunting if you're
  used to GUI programs. However, as a rule of thumb, if you're doing more work
  after installing nasher than you did before, you're likely missing some key
  piece of information and/or configuration that will make your life a lot
  easier. If you can't find your answers by re-reading this document, see the
  [Getting Help](#getting-help) section.

## Contributing

Bug fixes and new features are greatly appreciated! Here's how to get started:
1. Fork the repo: `gh repo fork squattingmonk/nasher && cd nasher`
2. Create your feature branch: `git checkout -b feature/fooBar`
3. Commit your changes: `git commit -am 'Add some fooBar'`
4. Create a new pull request: `gh pr create`

You can also file bug reports and feature requests on the [issues
page](https://github.com/squattingmonk/nasher/issues).

## Changelog

You can see the changes between versions in the [changelog](CHANGELOG.md).

## License

nasher is fully open-source and released under the [MIT License](LICENSE).
