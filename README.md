# nasher
This is a command-line utility for managing a Neverwinter Nights script or 
module repository.

## Installation
    $ git clone https://github.com/squattingmonk/nasher.nim.git nasher
    $ cd nasher
    $ nimble install

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

    # Unpack demo.mod into current directory
    $ nasher unpack demo.mod .

    # Unpack demo.mod into demo/src/
    # These directories will be created if they do not exist
    $ nasher unpack demo.mod demo/src

    # Unpack demo.mod into src/ but do not divide resource types
    $ nasher unpack demo.mod --flat

This unpacks a `.mod`, `.erf`, or `.hak` file into the source tree (defaults to 
`src/`), converting the gff files into their json counterparts. If the `--flat` 
flag is not specified, the files will be sorted into directories based on their 
type (i.e., `module.ifo -> src/ifo/module.ifo.json`).

If the unpacked files would overwrite files already present in the source 
directory, you will be prompted to overwrite them. You can force-answer the 
prompts by passing the `--yes`, `--no`, or `--newer` flags.

You can initialize a project with the contents of a `.mod`, `.erf`, or `.hak` 
file by running:

    # Initialize into foo using the contents of bar.mod as source files
    # e.g., module.ifo -> foo/src/ifo/module.ifo.json
    $ nasher init foo bar.mod

    # As above, but do not divide resource types
    # e.g., module.ifo -> foo/src/module.ifo.json
    $ nasher init foo bar.mod --flat

This is equivalent to:

    $ nasher init foo
    $ cd foo
    $ nasher unpack ../bar.mod

    # Or, if --flat is passed...
    $ nasher init foo
    $ cd foo
    $ nasher unpack ../bar.mod --flat

## Configuration
