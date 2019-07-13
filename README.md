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

### Initializing a new project
    # Create a nasher project in the current directory
    $ nasher init

    # Create a nasher project in directory foo
    $ nasher init foo

This will create a `nasher.cfg` file in the project directory. You can alter
the contents of this file to customize the paths to sources, add author
information, etc.

### Listing build targets
    # List target names only
    $ nasher list

    # List target names, descriptions, packed file, and source files
    $ nasher list --verbose

This will list the targets available in the current project. The first target
listed is treated as the default.

### Compiling
    # Compile all scripts for the default target
    $ nasher compile

    # Compile all scripts for the target "demo"
    $ nasher compile demo

The compiled scripts are placed into `.nasher/build/x`, where `x` is the name
of the target.

### Packing
    # Packing the default target
    $ nasher pack

    # Pack "demo"
    $ nasher pack demo

This compiles scripts, converts json sources into their gff counterparts, and
packs the resources into the target file. The resources are placed into
`.nasher/build/x`, where `x` is the name of the target. The packed file is
placed into the project root directory. If the file to be packed already exists
in the project root, you will be prompted to overwrite it. You can force answer
the prompt by passing the `--yes`, `--no`, or `--default` flags.

### Installing
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
is checked against a series of rules in the project config. If a rule is
matched, it will be placed in that directory. Otherwise, it is placed into the
directory `unknown` in the project root.

You can initialize a project with the contents of a `.mod`, `.erf`, or `.hak`
file by running:

    # Initialize into foo using the contents of bar.mod as source files
    $ nasher init foo bar.mod

This is equivalent to:

    $ nasher init foo
    $ cd foo
    $ nasher unpack ../bar.mod

