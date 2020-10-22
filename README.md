# nasher

Nasher is a command-line utility written in [nim](https://nim-lang.org/) and designed to manipulate Neverwinter Nights modules by allowing quick and easy module operations (unpacking, converting, compiling, packing), incorporating git-based version control, and enabling team collaboration.  While similar to [nwn-devbase](https://github.com/jakkn/nwn-devbase), nasher has some key differences:
* nasher and the tools it uses are written in nim rather than Ruby, so they are much faster (handy for large projects) and can be distributed in binary form
* nasher supports non-module projects (including erfs, tlks, and haks)
* nasher supports multiple build targets (e.g., an installable erf and a demo module)
* nasher supports custom source tree layouts (e.g., dividing scripts into directories based on category)
* nasher can install built targets into the NWN installation directory
* nasher uses json rather than yaml for storing gff files

The purpose of this document is to get you started with a combination of nasher and git in order to start version controlling your NWN module and allow you to build new module files on-demand.  This guide is written for those with some programming and/or command-line experience.  If you are having issues using nasher after reading this guide, you can obtain help in several locations:
* Neverwinter Vault Discord Server ([invitation](https://discord.gg/pWVqMRX)) ([workflow-and-tools channel](https://discord.com/channels/255017439371329537/511127010962046986))
* NWNX Discord Server ([invitation](https://discord.gg/fNZp2ND)) ([general channel](https://discord.com/channels/382306806866771978/382306806866771980))
* [nasher GitHub issues](https://github.com/squattingmonk/nasher.nim/issues) 

This guide is current as of nasher release 0.12.3.

* [Installation Options](#installation-options)
    * [Releases](#releases) (beginner)
    * [Docker](#docker) (moderate)
    * [Native](#native) (advanced)
* [Configuration](#configuration)
    * [Basic Configuration](#basic-configuration)
    * [Configuration Keys](#keys)
    * [nasher.cfg](#nasher.cfg)
* [Commands](#commands)
    * [Global Arguments](#arguments)
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
* [Troubleshooting](#troubleshooting)

# Installation Options
##### [top](#nasher) | [install](#installation-options) | [configuration](#configuration) | [commands](#commands) | [errors](#errors) | [troubleshooting](#troubleshooting)
&nbsp;

## Releases
---
Compiled versions of nasher are available on the [nasher releases](https://github.com/squattingmonk/nasher.nim/releases) page.  Download the version for your OS and place a pointer to the location of the executable file in your PATH environmental variable.

Requirements
* [neverwinter.nim](https://github.com/niv/neverwinter.nim) >= 1.3.1
* [nwnsc](https://github.com/nwneetools/nwnsc/releases) >= 1.1.2

Best practices
* Keep the binaries for nasher, neverwinter.nim and nwnsc in the same location. 
* Do not keep binaries in your nasher project folder, or add them to .gitignore
* Do not publish binaries to your source control repository.  If you are collaborating, each team member should download and install the binaries individually.

## Docker
---
Docker can be used on most operating systems to run all nasher [commands](#commands).

Requirements
* [Docker](https://docs.docker.com/get-docker/)

Notes
* Docker commands are run with the same nomenclature as native nasher commands.  If you want to use Docker, anytime you see a native nasher command in this document, you can replace it with the Docker command:
    ```c
    // Native nasher
    $ nasher <command> <target> <options>

    // Docker equivalent
    $ docker run --rm -it -v ${pwd}:/nasher squattingmonk/nasher:latest <command> <target> <options>
    ```

Best practices
* Create batch/script files to run your most common nasher commands as the docker command line interface can be rather verbose.  An excellent example of this is in [The Frozen North](https://github.com/b5635/the-frozen-north) GitHub repository.

## Native
---
Native installation is considered advanced usage and requires installation of several tools and systems for nasher to work correctly.

Requirements
* [nim](https://nim-lang.org/) >= 1.2.0
* [neverwinter.nim](https://github.com/niv/neverwinter.nim) >= 1.3.1
* [nwnsc](https://github.com/nwneetools/nwnsc/releases) >= 1.1.2

Installation

Nimble is the nim package manage and is bundled with nim:
```c
// To install the latest tagged version
$ nimble install nasher

// To install the latest version from the master branch
$ nimble install nasher@#head

// To install a specific tagged version
$ nimble install nasher@#0.11.6
```

You can also build directly from nasher source code:
```
$ git clone https://github.com/squattingmonk/nasher.nim.git nasher
$ cd nasher
$ nimble install
```

Notes
* If you have nim regex 0.17.0 installed prior to installing nasher, you will have errors during execution.  Regress your installation to 0.16.2 to resolve these errors.

Best practices
* Use [choosenim](https://github.com/dom96/choosenim/releases) to install and manage nim

# Configuration
##### [top](#nasher) | [install](#installation-options) | [configuration](#configuration) | [commands](#commands) | [errors](#errors) | [troubleshooting](#troubleshooting)
&nbsp;

## Basic Configuration
nasher requires no additional configuration to run unpack operations.  However, to convert, compile and pack a module, you must first initialize a nasher project and configure nwnsc.  The `--nssFlags` sends specific flags to nwnsc on execution.

Intializing a nasher project creates a `nasher.cfg` and, optionally, prepares the folder for use as a git repository:
```c
// Initialize a nasher project with default configuration values
$ nasher init --default

// If you don't want a git repo intialized during nasher initialization
$ nasher init --default --vcs:none
```

Configure nwnsc:
```c
// Provide the path to nwn binary files to nasher
$ nasher config --nssFlags:"-n \"~/.local/share/Steam/steamapps/common/Neverwinter Nights\" -owkey"

// Provide the location of the nwnsc binary to nasher.
$ nasher config --nssCompiler:"C:\\Users\\<username>\\Neverwinter Nights\\nwnsc.exe"
```

Notes
* Use absolute paths when providing a path to the nwnsc `-n` argument in the `--nssFlags` configure value.
* Escape the path `(\")`in the `-n` argument in the `--nssFlags` configuration value if it has spaces.  Escaping is not required if the path does not contain spaces.
* The method for referencing the present working directory (pwd) is different in many command line clients.  `${pwd}` may not work for yours.  Google is your friend.
* Spaces in the path value assigned to `--nssCompiler` do not have to be escaped.

Best practices
* Do not include other configurable nwnsc flags, such as `-b` and `-i`.  Those flags can be passed to nwnsc per target through nasher.cfg.

`--nssFlags` and `--nssCompiler` are the minimum configuration values required to successfully accomplish a pack procedure with nasher.  There are many more configuration options available.

## Keys
---
Gets, sets, or unsets user-defined configuration options. These options can be local (package-specific) or global (across all packages). Regardless, they override default nasher settings.

Nasher uses three sources for configuration data.  A global `user.cfg` (stored  in %APPDATA%\nasher\user.cfg on Windows or in $XDG_CONFIG/nasher/user.cfg on Linux and Mac), a local `user.cfg` (stored in .nasher/user.cfg in the package root directory) and the command-line.  Command-line options take precedence over the local configuration values, and local configuration values take precedence over the global configuration values.  Local configuration files will be ignored by git unless the `-vsc:none` flag used on `nasher init`.

Available Configuration Keys:
|Key|Default|Description|
|---|---|---|
|userName|git user.name|The default name to add to the author section of new packages|
|userEmail|git user.email|The default email use for the author section of new packages|
|nssCompiler|project root path| The path to the script compiler|
|nssFlags|-loqey|The [flags](#nwnsc-flags) to send to nwnsc.exe for compiling scripts|
|nssChunks|500|The maximum number of scripts to process at one time|
|erfUtil|nwn_erf.exe|the path to the erf pack/unpack utility|
|erfFlags||Flags to pass to erfUtil|
|gffUtil|nwn_gff.exe|the path to the gff conversion utility|
|gffFlags||Flags to pass to gffUtil|
|gffFormat|json|the format to use to store gff files|
|tlkUtil|nwn_gff.exe|the path to the tlk conversion utility|
|tlkFlags||Flags to pass to tlkUtil|
|tlkFormat|json|the format to use to store tlk files|
|installDir|Win: `~/Documents/Neverwinter Nights`|NWN user directory where built files should be installed|
||Linux: `~.local/share/Neverwinter Nights`||
|gameBin||path to nwnmain binary (only needed if not using steam)|
|serverBin||path to the nwserver binary (only needed if not using steam)|
|vcs|git|version control system to use for new packages|
|removeUnusedAreas|true|if `true`, prevents area not present in sources files from being referenced in `module.ifo`|
|||set to `false` if there are module areas in a hak or override|
|useModuleFolder|true|whether to use a subdirectory in the `modules` folder to store unpacked module files|
|||only used by NWN:EE|
|modName||sets the "Mod_Name" value in module.ifo|
|modMinGameVersion||sets the "Mod_MinGameVersion in module.ifo|
|truncateFloats|4|maximum number of decimal places to allow after floats in gff files|
|||prevents unneeded file updates due to insignificant float value changes|

Command Line Options
|Argument|Description|
|---|---|
|`--global`|applies to all packages (default)|
|`--local`|applies to the current package only|
|`--get`|display the value of `<key>` (default if `<value>` not passed)|
|`--set`|set `<key>` to `<value>` (default when `<value>` passed)|
|`--unset`|deletes key/value pair for `<key>`|
|`--list`|lists all key/value pairs in the specified configuration file|

Usage:
```c
$ nasher config [options] --<key>:"<value>"
```
Examples
```c
$ nasher config --nssFlags:"-n /opts/nwn -owkey"
$ nasher config --local --nssCompiler:"C:\\Users\\<username>\\Desktop\\Git Repositories\\nwnsc.exe"
$ nasher config --installDir:"C:\\Users\\<username>\\Documents\\Neverwinter Nights"
```

## nasher.cfg
---

This section discusses the capabilities and limitations of the `nasher.cfg` file, which must reside in the project's root directory.

#### Components
**[Package]** - an optional section, [Package] provides a location to codify a project's author, description, name, version and url.  This data is currently not used by any current nasher commands, but that may change in the future.

|Key|Description|
|---|---|
|`name`|package/project name|
|`description`|package/project description; """triple quotes""" enables multi-line descriptions|
|`version`|package/project version|
|`author`|name/email of the author; this field is repeatable|
|`url`|web location where the package/project can be downloaded|
&nbsp;

**[Sources]** - an optional section, [Sources] describes the locations of all source files to be either included or excluded from a project.  This section uses [glob pattern](https://en.wikipedia.org/wiki/Glob_(programming)) matching to identify desired files.  If you do not include any sources in this section, you must include them in the [Target] section or nasher will not have any files to work with.

|Key|Description|
|---|---|
|`include`|glob pattern matching files to include; this key is repeatable|
|`exclude`|glob pattern matching files to exclude; this key is repeatable|
|`filter`|glob pattern matching files to be included for compilation, but excluded from the module file/folder; this key is repeatable|
|`flags`|command line arguments to send to NWNSC at compile-time; this key is repeatable|
|`modName`|optional, sets the module name in the `module.ifo` file|
|`modMinGameVersion`|optional, sets the module's minimum game version in the `module.ifo` file|
&nbsp;

**[Rules]** - an optional section, [Rules] defines a directory structure for extracted files.  During the unpacking processing, these rules will be evaluated, in order, to determine which location a specific file should be unpacked to.  [Rules] take the form `"pattern" = "path"`.  All paths are relative to the root folder.  These rules apply to any unpacked files that do not exist in the source tree (your `myModule` folder).  If there is no catch-all rule (`"*" = "path"`), indeterminate files will be placed in a file called `unknown` for future disposition.

**[Target]** - a required section, at least one [Target] must be specified.  This section provides a target name, description, output file name and source list.

|Key|Description|
|---|---|
|`name`|name of the target; must be unique among [Target]s|
|`file`|name of the file to be created including extension; a path can be included to save the packed file into a specific directory, otherwise the file will be packed in the project root folder|
|`description`|an optional field that describes the target|
|`include`|glob pattern matching files to include; this key is repeatable; if used, only files matching target `include` values will be used and the [Sources] section will be ignored|
|`exclude`|glob pattern matching fiels to exclude; this key is repeatable; if used, only files matching target `exclude` values will be used and the [Sources] section will be ignored|
|`filter`|glob pattern matching files to be included for compilation, but excluded from the final target file; this key is repeatable; if used, only files matching target `filter` values will be used and the [Sources] section will be ignored|
|`flags`|command line arguments to send to NWNSC at compile-time|
|`modName`|optional, sets the module name in the `module.ifo` file for this target|
|`modMinGameVersion`|optional, sets the module's minimum game version in the `module.ifo` file for this target|
|`[Rules]`|`"pattern" = "path"` entries, similar to the [Rules] section; these entries will only apply to this target|
&nbsp;

Notes
* The [Rules] sections are only referenced during an unpack operation.
* Path references in include, exclude and [Rules] can be absolute or relative.  If relative, the paths cannot extend above the nasher project root folder.  That is `<folder>/<folder>` is valid, `../<folder` is not.

Best practices
* If starting with a valid module file, unpack the module to the `src` folder and create your desired folder structure with your favor file explorer application.  It is rarely necessary to have anything more than a single entry in the [Rules] section (`"*" = "src"`).  When a module is packed with nasher, the source location of each file is noted and unpacked back to that location, so a detailed [Rules] section is not necessary.
* Make the [Sources] section as inclusive as possible and use target `exclude` statements to narrow down the included files
* If you want to put compiled scripts into the `development` folder (or any other folder) for testing purposes, you can pass the `-b` flag to nwnsc:
    ```ini
    [Target]
    name = "myMod"
    file = "myMod.mod"
    flags = "-b"
    flags = "C:\\Games\\Neverwinter Nights\\development"
    ```
* If you use nasher to build your haks, consider having a seprate repo or a subfolder containing all of your hak file content as a separate nasher project.  This allows you to build more detailed hak-only targets and build all of your haks at once with a `nasher install all` command.

## Sample nasher.cfg
---
```ini
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

# The first target is the default target.  If no target is specified, this target will be used
# This should normally be your most common operation, such as packing your module file
[Target]
name = "demo"
description = "A demo module showing the system in action"
file = "core_framework.mod"
modName = "Core Framework Demo Module"
modMinGameVersion = "1.69"

[Target]
name = "framework"
description = "An importable erf for use in new or existing modules"
file = "core_framework.erf"
exclude = "src/demo/**"
exclude = "**/test_*.nss"

# hak and tlk files can be packed just as a module file is.
# Filtering optional files, such as .nss, .gic, and .ndb, can greatly reduce packed module file size
[Target]
name = "scripts"
description = "A hak file containing compiled scripts"
file = "core_scripts.hak"
include = "src/**/*.nss"
filter = "*.nss"

[Target]
name = "tlk"
description = "Custom talk file for PW"
file = "myPWtlk.tlk"
include = "haks/tlk/**/*.json"
```

# Commands
##### [top](#nasher) | [install](#installation-options) | [configuration](#configuration) | [commands](#commands) | [errors](#errors) | [troubleshooting](#troubleshooting)
&nbsp;

## Arguments
You can use the following arguments with most nasher commands:
```
-h, --help      <-- displays help for nasher or a specific command
-v, --version   <-- displays the nasher version
    --debug     <-- enable debug logging
    --verbose   <-- increases the feedback verbosity, useful for debugging
    --quiet     <-- disable all logging except errors
    --no-color  <-- disable color output
```

## Config
Configuration options are set in two locations, a global `user.cfg` and a local `user.cfg`.  To see which options, if any, are in each:
```c
$ nasher config --list            <-- global
$ nasher config --local --list    <-- local
```

Notes
* All configuration values that are set without using the `--local` argument will be considered global.

Best practices
* Set global values, such as `--nssFlags` and `--nssCompiler` as global configuration options.  Set package/project-specific values, such as `--modName` or `useModuleFolder`, with the `--local` argument.

## Init

See [basic configuration](#basic-configuration)

## List
Lists all available targets as defined in [nasher.cfg](#nasher.cfg).
```c
// List all target names, descriptions and details
$ nasher list

// List only target names
$ nasher list --quiet
```

## Unpack
Unpacks a file into the project source tree for the given target.

If a target is not specified, the first target found in nasher.cfg is used. If a file is not specified, Nasher will search for the target's file in the NWN install directory.

Each extracted file is checked against the target's source tree (as defined in the [Target] section of the package config). If the file only exists in one location, it is copied there, overwriting the existing file. If the file exists in multiple folders, you will be prompted to select where it should be copied.

If the extracted file does not exist in the source tree already, it is checked against each pattern listed in the [Rules] section of the package config. If a match is found, the file is copied to that location.

If, after checking the source tree and rules, a suitable location has not been found, the file is copied into a folder in the project root called `"unknown"` so you can manually move it later.

If an unpacked source would overwrite an existing source, its `sha1` checksum is checked against that from the last pack/unpack operation. If the sum is different, the file has changed. If the source file has not been updated since the last pack or unpack, the source file will be overwritten by the unpacked file. Otherwise you will be prompted to overwrite the source file. The default answer is to keep the existing source file.

Command Line Options
|Argument|Description|
|---|---|
|`--file`|the file to unpack into the target's source tree|
|`--yes`|automatically answers yes to all prompts|
|`--no`|automatically answers no to all prompts|
|`--default`|automatically accepts the default answer for all prompts|

Usage
```c
$ nasher unpack [options] [<target> [<file>]]
```

Examples
```c
$ nasher unpack myNWNServer --file:myModule.mod
```

## Convert
Converts all JSON sources for `<target>` into their GFF counterparts. If not supplied, `<target>` will default to the first target found in the package file.  The input and output files are placed in `.nasher/cache/<target>`.  Multiple `<target>`s may be specified, separated by spaces.  `<target>` may be the name of the target in `nasher.cfg`, a filename or a directory.

Command Line Options
|Argument|Description|
|---|---|
|`--clean`|clears the cache before packing|
|`--modName`|sets the "Mod_Name" value in module.ifo|
|`--modMinGameVersion`|sets the "Mod_MinGameVersion" value in module.ifo|

Usage
```c
$ nasher convert [options] [<target>...]
```

Examples
```c
$ nasher convert                                   <-- converts using first target in nasher.cfg
$ nasher convert default                           <-- converts using target named "default" in nasher.cfg
$ nasher convert --file:<path>                     <-- converts a specified directory using the default target in nasher.cfg
$ nasher convert <target> --file:<path>/<filename> <-- converts a specific file using the target in nasher.cfg
```

## Compile
Compiles all nss sources for `<target>`. If `<target>` is not supplied, the first target supplied by the config files will be compiled. The input and output files are placed in `.nasher/cache/<target>`.  NWNSC.exe is used as the compiler and compilation errors will be displayed with reference to filename, line number and general error description.  Default behavior is to place all compiled `.ncs` files into the cache folder associated with the specified target.  Will only compile `.nss` files that contain either a `void main()` or `int StartingConditional()` function as the rest are assumed to be includes.

Command Line Options
|Argument|Description|
|---|---|
|`--clean`|clears the cache before packing|
|`-f`, `--file`|compiles specific file, multiple files can be specified|
|`--modName`|sets the "Mod_Name" value in module.ifo|
|`--modMinGameVersion`|sets the "Mod_MinGameVersion" value in module.ifo|

Usage
```c
$ nasher compile [options] [<target>...]
```

Examples
```c
$ nasher compile                                   <-- compiles using first target in nasher.cfg
$ nasher convert default                           <-- compiles using target named "default" in nasher.cfg
$ nasher convert --file:<path>                     <-- compiles a specified directory using the default target in nasher.cfg
$ nasher convert <target> --file:<path>/<filename> <-- compiles a specific file using the target in nasher.cfg
```

## Pack
[Converts](#convert), [compiles](#compile), and packs all sources for `<target>`. If `<target>` is not supplied, the first target supplied by the config files will be packed. The assembled files are placed in `$PKG_ROOT/.nasher/cache/<target>`, but the packed file is placed in `$PKG_ROOT`.

If the packed file would overwrite an existing file, you will be prompted to overwrite the file. The newly packaged file will have a modification time equal to the modification time of the newest source file. If the packed file is older than the existing file, the default is to keep the existing file.

Command Line Options
|Argument|Description|
|---|---|
|`--clean`|clears the cache before packing|
|`--yes`|automatically answers yes to all prompts|
|`--no`|automatically answers no to all prompts|
|`--default`|automatically accepts the default answer for all prompts|
|`--modName`|sets the "Mod_Name" value in module.ifo|
|`--modMinGameVersion`|sets the "Mod_MinGameVersion" value in module.ifo|

Usage
```c
$ nasher pack [options] [<target>...]
```

Examples
```c
$ nasher pack                  <-- packs using first target in nasher.cfg
$ nasher pack <target> --yes   <-- packs using <target> in nasher.cfg and answers all prompt `yes`
```

## Install
[Converts](#convert), [compiles](#compile), and [packs](#pack) all sources for `<target>`, then installs the packed file into the NWN installation directory. If `<target>` is not supplied, the first target found in the package will be packed and installed.

If the file to be installed would overwrite an existing file, you will be prompted to overwrite it. The default answer is to keep the newer file.  If the `useModuleFolder` configuration setting is TRUE or not set, a folder containing all converted and compiled files will be installed into the same directory as the module (`.mod`) file.

Command Line Options
|Argument|Description|
|---|---|
|`--clean`|clears the cache before packing|
|`--yes`|automatically answers yes to all prompts|
|`--no`|automatically answers no to all prompts|
|`--default`|automatically accepts the default answer for all prompts|
|`--modName`|sets the "Mod_Name" value in module.ifo|
|`--modMinGameVersion`|sets the "Mod_MinGameVersion" value in module.ifo|

Usage
```c
$ nasher install [options] [<target>...]
```

Examples
```c
$ nasher install                  <-- installs using first target in nasher.cfg
$ nasher install <target> --yes   <-- installs using <target> in nasher.cfg and answers all prompt `yes`

// Special case for Docker usage -- with install and launch commands, docker requires access to the NWN
// documents folder
$ docker run --rm -it -v ${pwd}:/nasher -v /usr/home/Neverwinter Nights:/nasher/install squattingmonk/nasher:latest install <target> --yes
--> The first volume assigns the nasher project folder (source files)
--> The second volume assigns the documents folder
```

## Launch
[Converts](#convert), [compiles](#compile), [packs](#pack) and [installs](#install) all sources for <target>, installs the packed file into the NWN installation directory, then launches NWN and loads the module. This command is only valid for module targets.

Command Line Options
|Argument|Description|
|---|---|
|`--gameBin`|path to the nwnmain binary file|
|`--serverBin`|path to the nwserver binary file|
|`--clean`|clears the cache before packing|
|`--yes`|automatically answers yes to all prompts|
|`--no`|automatically answers no to all prompts|
|`--default`|automatically accepts the default answer for all prompts|
|`--modName`|sets the "Mod_Name" value in module.ifo|
|`--modMinGameVersion`|sets the "Mod_MinGameVersion" value in module.ifo|

Usage
```c
$ nasher (serve|play|test) [options] [<target>...]
```

Examples
```
$ nasher serve <target>  <-- installs <target> and starts nwserver
$ nasher play <target>   <-- installs <target>, starts NWN and loads the module
$ nasher test <target>   <-- installs <target>, starts NWN, loads the module and uses the first characater
```

# Errors
##### [top](#nasher) | [install](#installation-options) | [configuration](#configuration) | [commands](#commands) | [errors](#errors) | [troubleshooting](#troubleshooting)
&nbsp;

`"No source files found for target"` - Caused by improper sourcing (`include = `) in either the [Sources] or [Target] section of `nasher.cfg`.  Check your [configuration file](#nasher.cfg).

`"This is not a nasher repository. Please run init"` - Caused by running any nasher command, except `nasher config --global` before running [`nasher init`](#configuration) in the project folder.  Caused by incorrectly referencing the present working directory in the `docker run` command.  The reference can be CLI-specific.  For example, ubuntu/linux wants to see `$(pwd)` while PowerShell requires `${pwd}`.  Lookup the appropriate reference for your CLI.  `%cd%` only works for Windows `cmd.exe`.

`"The following areas do not have matching .git files and will not be accessible in the toolset"` - When the area list is built during the conversion process, nasher matches the list of .are files with .git files.  This warning will list any .are files that do not have matching .git files.

`"This module does not have a valid starting area!"` - A module cannot be packed/installed without a valid starting area.  Either extract a valid starting area into the nasher project folder or manually edit (never recommended!) your `module.ifo` file at the `Mod_Entry_Area` setting.

`"this answer cannot be blank. Aborting..."` - Answer to prompt required, but not provided.

`"not a valid choice. Aborting..."` - User selected an invalid multiple-choice answer.

`"Could not create {outFile}. Is the destination writeable?"` - raised is a destination folder for file conversion does not have write permissions.  Also raised if there is an error converting the file to `.json` format.  If you permissions are set correctly, try using 64-bit versions of minGW and nim.

# Troubleshooting
##### [top](#nasher) | [install](#installation-options) | [configuration](#configuration) | [commands](#commands) | [errors](#errors) | [troubleshooting](#troubleshooting)
&nbsp;

**Can nasher `<anything you want here>`?**  Probably.

**Can I use absolute or relative paths?**  Yes.

**Does nasher strip the module ID?**  Yes.

**I really need nasher to do something it doesn't, can you add this function?**  You can ask.  nasher is actively maintained and new features are constantly added.  If your request is a feature that fits within the design criteria for nasher, it can likely be added.  [Add an issue](https://github.com/squattingmonk/nasher.nim/issues) on the [nasher github site](https://github.com/squattingmonk/nasher.nim) and it will be addressed shortly.

**I thought using nasher was supposed to be easy, why is it so difficult?** You're probably doing it wrong.  Read through this document for the command you're trying to use and see if you can self-help.  As a rule of thumb, if you're doing more work after installing nasher than you did before, you're likely missing some key pieces of information and/or configuration that will make your life a lot easier.  If you can't self-help through this document, see the [help sources](#nasher) at the top of this document.
