# nasher
This is a command-line utility for managing a Neverwinter Nights script or 
module repository.

## Installation
``` console
$ git clone https://github.com/squattingmonk/nasher.nim.git nasher
$ cd nasher
$ nimble install
```

## Usage
Run `nasher --help` to see usage information. To get detailed usage information 
on a particular command, run `nasher command --help`, where `command` is the 
command you wish to learn about.

### Initializing a new project
``` console
# Create a nasher project in the current directory
$ nasher init

# Create a nasher project in directory foo
$ nasher init foo
```

This will create a `nasher.cfg` file in the project directory. You can alter 
the contents of this file to customize the paths to sources, add author 
information, etc.

### Listing builds
``` console
# List build names only
$ nasher list

# List build names, descriptions, target file, and source files
$ nasher list --verbose
```

This will list the builds available in the current project. The first build 
listed is treated as the default build.

### Compiling
``` console
# Compile all scripts in the default build
$ nasher compile

# Compile all scripts in the build "demo"
$ nasher compile demo
```

The compiled scripts are placed into `.nasher/build/`, where `build` is the 
name of the build compiled.

### Building
``` console
# Build the default build
$ nasher build

# Build "demo"
$ nasher build demo
```

This compiles scripts, converts json sources into their gff counterparts, and 
packs the resources into the target file. The resources are placed into 
`.nasher/build/`, where `build` is the name of the build. The target file is 
placed into the project root directory.

### Installing built files
``` console
# Install demo.mod to the NWN install directory
# default: "~/Documents/Neverwinter Nights/mod"
$ nasher install demo.mod

# Install demo.mod to /opt/nwn/mod
$ nasher install demo.mod /opt/nwn/mod
```

If the file to be installed already exists at the target location, you will be 
prompted to overwrite it. You can force answer the prompt by passing the 
`--yes`, `--no`, or `--newer` flags:

``` console
# Install and overwrite if present
$ nasher install demo.mod --yes

# Install but do not overwrite if already present
$ nasher install demo.mod --no

# Install, overwriting if newer than present file
$ nasher install demo.mod --newer
```

If you try to install a file that does not exist, nasher will instead try to 
build and install the target file. If multiple builds exist for the target 
file, you will be prompted to choose from them. If no build target of that name 
can be found, nasher will instead attempt to build a build of that name:

``` console
# Build and install the file for build demo
$ nasher install demo
```

### Cleaning up
``` console
# Remove all build directories
$ nasher clean

# Remove build directory for build "demo"
$ nasher clean demo

# Remove build directories and built targets for all builds
$ nasher clobber

# Remove build directories and built targets for build "demo"
$ nasher clobber demo
```

These commands can be used to ensure a clean build (i.e., free from unwanted 
files).

You can also pass the `--clean` and `--clobber` flags to the `build` and 
`install` commands when operating on a particular build:
- `--clean` will remove the associated directory *before* building
- `--clobber` will remove the associated directory and its built products 
  *after* building.

``` console
# Cleanly build demo
$ nasher build demo --clean

# Cleanly build demo, install the built target, then remove the build directory 
# and built target
$ nasher install demo --clean --clobber
```

### Unpacking a file
``` console
# Unpack "demo.mod" into src/
$ nasher unpack demo.mod

# Unpack demo.mod into current directory
$ nasher unpack demo.mod .

# Unpack demo.mod into demo/src/
# These directories will be created if they do not exist
$ nasher unpack demo.mod demo/src

# Unpack demo.mod into src/ but do not divide resource types
$ nasher unpack demo.mod --flat
```

This unpacks a `.mod`, `.erf`, or `.hak` file into the source tree (defaults to 
`src/`), converting the gff files into their json counterparts. If the `--flat` 
flag is not specified, the files will be sorted into directories based on their 
type (i.e., `module.ifo -> src/ifo/module.ifo.json`).

If the unpacked files would overwrite files already present in the source 
directory, you will be prompted to overwrite them. You can force-answer the 
prompts by passing the `--yes`, `--no`, or `--newer` flags.

You can initialize a project with the contents of a `.mod`, `.erf`, or `.hak` 
file by running:
``` console
# Initialize into foo using the contents of bar.mod as source files
# e.g., module.ifo -> foo/src/ifo/module.ifo.json
$ nasher init foo bar.mod

# As above, but do not divide resource types
# e.g., module.ifo -> foo/src/module.ifo.json
$ nasher init foo bar.mod --flat
```

This is equivalent to:
``` console
$ nasher init foo
$ cd foo
$ nasher unpack ../bar.mod

# Or, if --flat is passed...
$ nasher init foo
$ cd foo
$ nasher unpack ../bar.mod --flat
```

## Configuration
