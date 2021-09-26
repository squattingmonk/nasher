# nasher changelog

## 0.15.2: September 26, 2021

Fixed an issue that prevented nasher from reading the `modName` and
`modMinGameVersion` fields from `nasher.cfg`.

---

Details: https://github.com/squattingmonk/nasher/compare/0.15.1...0.15.2


## 0.15.1: June 25, 2021

- Corrected a copy-paste error in format checking that prevented nwnt files
  from being properly converted.
  ([#82](https://github.com/squattingmonk/nasher/pull/82))
- Fixed an issue that prevented `.ncs` files from being detected after
  compilation.
- Files are now properly installed to `$NWN_HOME` rather than `$NWN_ROOT`.
- Nasher now warns if it can't resolve the `$NWN_ROOT` environment variable
  rather than erroring out. This prevented the docker build from compiling.

---

Details: https://github.com/squattingmonk/nasher/compare/0.15.0...0.15.1


## 0.15.0: June 23, 2021

### Support for Beamdog and GOG installs
([#65](https://github.com/squattingmonk/nasher/pull/65))

nasher should now work without without additional configuration for those who
installed NWN using the Beamdog client, GOG, or non-default Steam locations.
The preferred way of setting the install location is to set the `$NWN_ROOT`
environment variable as this variable is also read by nwnsc and niv's tools. In
the case of nwnsc, it allows the user to run with the default `-l` flag instead
of having to set `--nssFlags:"-n '/path/to/nwn/data'"`.

When nwnsc is called with the `-l` flag, it first checks the `$NWN_ROOT`
environment variable to get the location of the NWN install. This value is also
checked by the neverwinter.nim tools. If the variable has not been set by the
user, nasher will check for Steam, Beamdog, and GOG installs and set the
`NWN_ROOT` variable accordingly. This means users should be able to just use
the default nwnsc flags `(-lowqey)` and it will find the NWN install without
issue.

Similarly, the `$NWN_HOME` directory is used for the path in which modules,
haks, etc. will be stored. If the `--installDir` flag was not passed, the
environment variable will be checked. If the environment variable was not set,
it will fall back to `~/Documents/Neverwinter Nights` or
`~/.local/share/Neverwinter Nights`, depending on the OS.

### `gffFlags` support re-enabled
([#75](https://github.com/squattingmonk/nasher/issues/75))

nasher returned to calling the `nwn_gff` binary when converting to and from
json. This re-enables the `--gffFlags` setting, allowing (among other things)
setting of alternate file encodings.

### Allowed `--key value` parameter syntax

nasher now allows options to be passed to nasher using the `--key value` syntax
rather than just `--key:value` and `--key=value`. The old way still works, but
this will be more familiar to terminal users.

### Executable scripts now checked after compilation
([#81](https://github.com/squattingmonk/nasher/pull/81))

Added a warning if compilation of an executable script does not yield a
matching `.ncs` file, This helps to prevent nasher from reporting successful
compilation in case of an uncaught nwnsc error. Thanks, @tinygiant98!

### Fixed duplicate choices in source list
([#79](https://github.com/squattingmonk/nasher/issues/79))

nasher no longer asks the user to choose a file when multiple targets match the
same file.

---

Details: https://github.com/squattingmonk/nasher/compare/0.14.2...0.15.0


## 0.14.2: December 29, 2020

Increased the required nwnt version to 1.3.0. This is required because previous
versions of nwnt ignored empty lists, leaving some files unable to be opened by
the toolset.

---

Details: https://github.com/squattingmonk/nasher/compare/0.14.1...0.14.2


## 0.14.1: December 21, 2020

Increased the required nim version to 1.4.0 to avoid conflict with nwnt.

---

Details: https://github.com/squattingmonk/nasher/compare/0.14.0...0.14.1


## 0.14.0: December 20, 2020

### Support for git branch-based workflow
([#54](https://github.com/squattingmonk/nasher.nim/pull/54))

You can now specify a git branch to use when packing or unpacking a target. You
can do this as a command-line parameter using `--branch:foo` or within your
`nasher.cfg` using the `branch` field. The `branch` field can be used by the
package or by targets. If a target does not have a branch specified, it will
use that of the package. If neither has a branch specified, nasher will use
whatever branch is currently checked out. The `--branch` command-line flag
overrides any setting in `nasher.cfg`.

Thanks to @tinygiant98 for his hard work on this feature.

### Support for NWNT format
([#60](https://github.com/squattingmonk/nasher.nim/pull/60))

Nasher now supports the [nwnt](https://github.com/WilliamDraco/nwnt) file
format. Based on nwn_gff from the neverwinter.nim tools, this output format
utilises the libraries of those tools for a custom output language instead of
json. The output language is designed to be similar to json that has been put
through [gron](https://github.com/tomnomnom/gron). A standalone conversion tool
is also available at the project page.

To enable, use `nasher config gffFormat nwnt` (remember `--local` to only affect
current package).

Thanks to @WilliamDraco for his hard work on this feature.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.13.0...0.14.0

## 0.13.0: November 07, 2020

### Display an error message when a resource filename is > 16 characters
([#59](https://github.com/squattingmonk/nasher.nim/issues/59))

When a file being packed into a module, erf, or hak is > 16 characters long
(not including the file extension), nasher will now emit an error and ask if
the user wants to continue packing.

### Ask which file to pack when mulitple copies exist
([#58](https://github.com/squattingmonk/nasher.nim/issues/58))

When the `convert` command finds multiple versions of the same source file
within the target's source directory, it will now ask which one the user wishes
to use.

This change also stops nasher from automatically making the source filenames
lowercase. Previously, if the user had both src/foo.nss and src/FOO.NSS in the
source tree, the latter would be renamed to the former, wiping out any
differences between the two. The converted file will still be lowercase, so the
user must choose which file to use in this case.

### Other fixes
- Passing relative paths to the `-nssCompiler`, `--gffUtil`, `--tlkUtil`, and
  `--erfUtil` flags now works correctly
  ([#55](https://github.com/squattingmonk/nasher.nim/issues/55))
- A help message is shown if an unknown command is passed. Previously, nasher
  would attempt to verify that required binaries were installed before checking
  if the command the user issued was valid. This caused a KeyError and
  prevented the help message from being shown.
- Bump required version of [niv's
  tools](https://github.com/niv/neverwinter.nim) to `1.4.0`. Previous versions
  would not compile on `nim >= 1.4.0`.
- Issues with [glob](https://github.com/citycide/glob) and [`regex
  0.17.0`](https://github.com/nitely/nim-regex) have been fixed upstream.
  Nasher no longer requires an old version of `regex` to work.
- The readme has been rewritten and is hopefully more welcoming to new users
  ([#53](https://github.com/squattingmonk/nasher.nim/pull/53)). Thanks,
  @tinygiant98!.
- The docker image is now being built against alpine rather than ubuntu. This
  should result in a faster build and smaller download for docker users.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.12.3...0.13.0


## 0.12.3: October 21, 2020

This release fixes problems with compilation of neverwinter.nim and the
outdated glob dependency in docker. It's an ugly temporary fix until the
upstream issues are resolved.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.12.2...0.12.3


## 0.12.2: October 20, 2020

### Use copy of cache directory to filter and pack
([#52](https://github.com/squattingmonk/nasher.nim/issues/52))

This fixes an issue caused by filtered files being removed from the cache
directory before packing. Now a copy of the directory is made, the filters are
applied, and the target file is made from that, leaving the cached content in
place.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.12.1...0.12.2


## 0.12.1: October 20, 2020

This change removes a spurious warning about missing `.gic` files that
overwhelmed the output on large modules.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.12.0...0.12.1


## 0.12.0: October 20, 2020

### Include directives and exec functions comments now ignored
([#48](https://github.com/squattingmonk/nasher.nim/issues/48))

Previously, include scripts that had executable functions inside of multi-line
comment blocks were erroneously marked as executable, causing unnecessary
recompilation since no `.ncs` file was generated after the last compile.

This also fixes a related error, where include directives inside
multi-line comments were erroneously detected.

### Add module name/version functionality
([#51](https://github.com/squattingmonk/nasher.nim/pull/51))

Thanks to tinygiant98 for this update. This update adds the ability to set a
module's name and the minimum game version required to run it.

You can set the module's name and minimum game version using the `modName` and
`modMinGameVersion` settings, respectively. They can be passed as fields under
a `[Package]` or `[Target]` section of `nasher.cfg` or as command-line flags.
If a target does not have a set module name or version, it will inherit from
the package. If neither is present, no changes will be made. A command-line
option will override any setting in the `nasher.cfg`.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.9...0.12.0


## 0.11.9: September 26, 2020

### Allow `install` and launch commands to work with docker
([#44](https://github.com/squattingmonk/nasher.nim/pull/44))
Added dummy folders to the docker volume to prevent permission issues when
trying to access the installation directory. This fixes
([#39](https://github.com/squattingmonk/nasher.nim/issues/39)). You can mount
your installation directory to the new `nasher/install` folder using the
following command:

```sh
docker run --rm -it -v ${pwd}:/nasher \
    -v /your/dir/here:/nasher/install squattingmonk/nasher:latest install
```

### Force "Bearing" on 180 degrees to be positive
([#41](https://github.com/squattingmonk/nasher.nim/issues/41))
This prevents additional diffs between +PI and -PI that refer to the same
bearing. This issue was fixed in a recent NWN:EE patch, but may be useful to
those running 1.69.

### Other fixes
- `.ndb` files are no longer deleted from the cache after compilation
- Improved error messages when converting between GFF and JSON fails

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.8...0.11.9


## 0.11.8: June 21, 2020

### Added option to compile single files
([#35](https://github.com/squattingmonk/nasher.nim/issues/35))

This update allows the `compile` command to specify a single script to compile
using the `--file` flag. This flag can take a semicolon-delimited list or it
can be repeated.

When used to compile a single file, the command will still operate on a target.
If no target is specified by the user, the default target is used. Thus, if the
script specified by the user is not in the source tree for the target, the
command will fail.

If only a filename is given, it uses the file from the cache. If a to a file is
given, it must point to a script within the target's source tree; the cached
version of the file will still be used, but this makes it easier to work with
the your shell's tab-completion.

### Other fixes

- The compiler binary check is only performed when running the `compile`,
  `pack`, `install`, `play`, `test`, and `serve` commands when the
  `--noCompile` flag is passed.
  ([#38](https://github.com/squattingmonk/nasher.nim/issues/38))
- Environment variables in server and game binary paths are now resolved
  correctly.
- Fixed an error that prevented the game and server binaries from being
  executed on Windows

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.7...0.11.8

## 0.11.7: June 05, 2020

Fixes scripts always being recompiled
([#37](https://github.com/squattingmonk/nasher.nim/issues/37))

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.6...0.11.7

## 0.11.6: May 31, 2020

### Allowed packing file to subdirectory
[(#23)](https://github.com/squattingmonk/nasher.nim/issues/23)

The user can now include path information in the file section of a
target to allow the target to be packed to a different location. For
example:

    [Target]
    name = "demo"
    file = "packed/demo.mod"

Behavior for files that include path information:

1. When packing: if the file contains path information, it will be
   relative to the project root.
2. When installing: any path portion of the file will be discarded and
   the file will be installed into $installDir/{erf,hak,modules,tlk}/ as
   appropriate.
3. When unpacking using a target: any path portion will be discarded and
   the file will be unpacked from $installDir/{erf,hak,modules,tlk}/ as
   appropriate.
4. When unpacking by explicitly passing a file: the path will be
   relelative directory names ative current working directory. Absolute paths are allowed here.

Using the example above, we would get the following:

    # Packs to ./packed/demo.mod
    $ nasher pack demo

    # Installs to $installDir/modules/demo.mod
    $ nasher install demo

    # Unpacks from $installDir/modules/demo.mod
    $ nasher unpack demo

    # Unpacks from ./packed/demo.mod
    $ nasher unpack demo packed/demo.mod

### Added per-target unpack rules

Any unrecognized key/value pair in the [Package] or [Target] sections
will be treated as an unpack rule of the form `"pattern" = "destination"`.
If a target does not have any unpack rules of its own, it will use the
package's rules, just like it can inherit the package's include,
exclude, and filter fields.

Note that the unpack rules are only used if the file cannot be found
among the target's sources.

### Truncate floats when unpacking gff files
[(#32)](https://github.com/squattingmonk/nasher.nim/issues/32)

You can use the `--truncateFloats` flag to set how many decimal places to
truncate floats to (default is `4`).

### Minor fixes
- Hyphens are now allowed in target names
- nasher now uses a manifest to track files that need to be reconverted in the
  cache, fixing [#20](https://github.com/squattingmonk/nasher.nim/issues/20).

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.4...0.11.6

## 0.11.5: May 20, 2020

Floats are now truncated to prevent insignificant changes from triggering file
updates in git (#32). You can control the number of decimal places to allow
with the new `--truncateFloats` flag; its default value is `4`.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.4...0.11.5

## 0.11.4: May 16, 2020

### Support unpacking from directories (#24)
You can now pass a directory to the unpack command just as you would a file.

### Process scripts in chunks (#31)
Scripts are now processed in chunks to limit the size of the command passed to
nwnsc. You can change the size of these chunks with the new `--nssChunks`
setting.

### `installDir` path expansion (#15)
Tildes and environment variables are now interpreted correctly in the `install`
and `unpack` commands.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.3...0.11.4

## 0.11.3: May 15, 2020

Added support for underscores in target names. Previously these would be
removed. Target names must still be lowercase (nasher will make them lowercase)
and may only have alphanumeric and underscores.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.2...0.11.3

## 0.11.2: May 11, 2020

### Added pre-pack file filtering (#22)

This adds support for removing files from the cache before packing. This
allows you to, for example, remove `.nss` files from a hak while leaving
the compiled `.ncs` files in place.

To filter files, use the `filter` key under either the package or the
target. This key, like the `include` and `exclude` keys, takes a pattern
to match and can be repeated multiple times to add as many filters as
necessary. If a target does not have its own filter, it will inherit the
package-level filter. Note that filter patterns will only yield files
directly from the cache and should not contain directory information.

    [Sources]
    include = "src/*.{nss,json}"
    filter = "test_*.{nss,ncs}"

    [Target]
    name = "hak"
    file = "myhak.hak"
    filter = "*.nss"            # Will filter out all nss files
    filter = "test_*.{nss,ncs}" # Must include since not inherited

    [Target]
    name = "module"
    file = "mymod.mod"
    # No filter, so inherits the package-level filter

### Module folders no longer deleted on install (#18)

Now instead of deleting the mod folder, installing only deletes files in the
install folder. It does not touch sub-directories, so if you keep your nasher
repo inside your module folder you are safe.

### Added $target variable for unpack rules (#25)

The `[Rules]` section can now reference the special variable `$target`
to get the name of the target currently being unpacked. For example, the
following rule would unpack any unknown files  for the `demo` target
into `src/demo`:

    [Rules]
    "*" = "src/$target"

This change only affects unpack rules and does not support include or
exclude rules.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.1...0.11.2


## 0.11.1: April 16, 2020

- The `config` and `list` commands now work even if you are missing some of the
  required binaries. Previously, this was preventing users from setting the
  path to the binaries using the `config` command (#16).
- Environment variables and tildes are now expanded in binary paths (#17)
- No longer uses regex to check included or executable scripts (#19)
- When an unhandled exception is thrown, nasher now gives a stack trace and a
  message to report the issue on GitHub.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.11.0...0.11.1

## 0.11.0: April 5, 2020

### tlk support
Build targets can now handle tlk files. These will be installed in the
`$installDir/tlk` directory. They are converted to json like gff files. This
feature requires that you have `nwn_tlk` installed (which comes with the
`neverwinter.nim` dependency).

tlk files cannot be included in erf, hak, or module files so they need their own
target to build. In addition, other targets need to know to avoid the tlk file:

```ini
[Target]
name = "module"
file = "my_module.mod"
include = "src/**/*.{nss,json}"
exclude = "**/*.tlk.json"

[Target]
name = "tlk"
file = "mycustomtlk.tlk"
include = "src/**/mycustomtlk.tlk.json"
```

Three new flags have been added:
- `tlkUtil`: the binary used to convert tlk files (default: `nwn_tlk`)
- `tlkFlags`: additional flags to pass to `nwn_tlk` (default: )
- `tlkFormat`: the format used to store tlk files (default: `json`)

### Minor changes
- Added a prompt to continue installing or launching a file when choosing not
  to overwrite an existing file.
- The `play`, `test`, and `serve` commands no longer error out when supplied
  when supplied with a non-module target. This means you can install multiple
  files and then launch the module (assuming the module is the last target
  supplied to the command). For example: `nasher test hak1 hak2 tlk module`
  will install two hak targets, a tlk target, and then install and test the
  module target.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.10.2...0.11.0

## 0.10.2: April 2, 2020
This is a small bugfix release that forces source filenames to be all lowercase.
This was an issue because modules unpacked from a directory may have uppercase
filenames or extensions. On case-sensitive OSes, this caused some files to be
duplicated or not detected at all.
- If you have files in your source tree with uppercase filenames, run `nasher
  pack all` (no need to install) to rename the files and update the cache.
  Things should work correctly next time you unpack.
- Directories with uppercase characters are okay.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.10.1...0.10.2

## 0.10.1: March 19, 2020

This fixes a KeyError that could be thrown when deleting a file while
unpacking.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.10.0...0.10.1

## 0.10.0: March 17, 2020

### Unpack files based on target

This update changes how unpacking is done. Now, instead of specifying a file
and having it extracted to the whole source tree, you specify a target and the
file is extracted to that target's source tree. If you do not manually specify
a file, the installed version of the target's file is unpacked. This makes the
workflow as follows:

1. Pack and install demo target: `nasher install demo`
2. Edit installed module in toolset
3. Unpack to get toolset changes: `nasher unpack demo`

This should streamline the workflow and get rid of annoying prompts when two
targets have different versions of the same file: only the intended target's
file is overwritten.

Note that you can still manually specify a file to unpack:

    $ nasher unpack demo demo.mod # or...
    $ nasher unpack --file:demo.mod

### Support for NWN:EE module folders

NWN:EE added module folders. These are subdirectories of the modules folder
that contain unpacked modules. They can be loaded in the toolset just like a
packed module. The new `--useModuleFolder` flag enables this feature.
- default when installing: `true`
- default when unpacking: `false` if explicitly given a file; else `true`

You can disable this setting with `nasher config`:

    $ nasher config useModuleFolder false

### Launch modules with nasher

This update added three commands:
- `play`: runs the `convert -> install` loop for a module target, then launches
  the module in-game
- `test`: as `play`, but launches in testing mode, selecting the first PC in
  the localvault (just like testing from the toolset)
- `serve`: as `play`, but launches the module using `nwserver`

nasher searches for the `nwmain` and `nwserver` binaries in the default Steam
locations for your OS. If it cannot find them, you can use new `--gameBin` and
`--serverBin` flags to point to them. These settings can be made permanent with
`nasher config`:

    $ nasher config gameBin /opt/nwn/nwmain-linux
    $ nasher config serverBin /opt/nwn/nwserver-linux

### Minor changes

- Debug mode now shows additional compiler info if `-q` is not in `--nssFlags`
- Added `--noConvert`, `--noPack`, and `--noInstall` flags to skip these steps
  in the `convert -> compile -> pack -> install -> launch` loop.
- Switched to JSON manifests for tracking checksums.
- Checksums are now updated during packing, so you'll know about any toolset
  changes the next time you unpack.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.9.6...0.10.0

## 0.9.6: February 19, 2020

### Allow file deletion on unpack

You can now remove unwanted files when unpacking before they are converted and
copied into the source tree. Do this with a rule that sets the output directory
to `/dev/null`. For example, the following rules remove any `ndb` files and
place everything else into `src`:

```ini
[Rules]
"*.ndb" = "/dev/null"
"*" = "src"
```

### Version stripped from areas when unpacking
The area version is a useless field that updates whenever the area is saved in
the toolset, regardless of whether anything has changed. Removing this field
keeps area files from updating unnecessarily.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.9.5...0.9.6

## 0.9.5: January 06, 2020

### Implement checksums for unpack (#4)

Previously, unpacked files would overwrite the source files if they were newer.
However, this could cause problems since the unpacked files were treated as
being the age of the module file they were extracted from. If you pack a file
and then edit it in the toolset, unpacking would overwrite any source code
changes you've made since then.

This version records checksums of the source files and module files on
unpacking. The next time the module is unpacked, each file will be compared to
the checksums to determine if the module or source files have been updated
since the last unpack and let the builder choose which file to keep when a
conflict is found.

### Minor changes
- Improved compilation speed with large numbers of scripts
- Improved docker documentation

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.9.4...0.9.5

## 0.9.4: November 06, 2019

### Add docker support
If you don't want to be bothered installing nim and `nwnsc`, you can run nasher
as a docker image. Refer to the readme for details.

### Minor changes
- nasher now checks to see if `nwnsc` and the `nwn_*` binaries are present
  before running and presents a helpful error message if not.
- Removed unused imports that caused warnings during installation
- Scripts that include an executable script that changed since the last pack
  are now recompiled (fixes #6).
- If compilation yields errors, a warning and prompt will be shown before
  continuing to pack.
- Fixed an infinite loop when encountering a compiler error in Windows.
- Choice prompts now present the user with numbered choices to make it easier
  to handle reading data through `stdin`.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.9.3...0.9.4

## 0.9.3: October 29, 2019

- Added the `--skipPkgInfo` flag. This allows the user to skip the extra
  package information like package name, author, etc. This information will be
  used eventually if I ever get around to adding in dependency management.
  Currently, it does nothing, so there's no harm in removing it.
- Blank author names are now allowed
- Choice prompts now work when not in a tty

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.9.2...0.9.3

## 0.9.2: October 21, 2019

- Fixed filenames with spaces causing external programs to error

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.9.1...0.9.2

## 0.9.1: October 14, 2019

- Fixed an error caused by using shell globs in Widows

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.9.0...0.9.1

## 0.9.0: October 13, 2019

- Added a prompt to delete files not present in a file being unpacked. This
  makes it easier to prevent files intentionally deleted in the toolset from
  being accidentally added back into the module.
- Added the `--removeDeleted` flag to force-answer the prompt. If true, files
  will always be deleted; if `false`, they will always be kept. If unset, the
  prompt will be show. This flag can be made persistent using `nasher config`.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.8.4...0.9.0

## 0.8.4: October 13, 2019

- Fixed `nasher.cfg` being loaded twice during unpacking.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.8.3...0.8.4

## 0.8.3: October 12, 2019

- File names with spaces now work correctly when unpacking

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.8.2...0.8.3

## 0.8.2: September 07, 2019

- Spaces in directories in the `--nssFlags` flag are now parsed correctly

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.8.1...0.8.2

## 0.8.1: September 07, 2019

- Allow spaces between flags in `--nssFlags` (e.g., allow `-l -q` rather than
  just `-lq`)

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.8.0...0.8.1

## 0.8.0: September 06, 2019

- Unused areas are now removed from `module.ifo` when packing the module. This
  can be disabled with `--removeUnusedAreas:false`.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.7.3...0.8.0

## 0.7.3: September 06, 2019

- Fixed pack failure with large file count (#1)

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.7.2...0.7.3

## 0.7.2: August 24, 2019

- Added package-level compiler flags. If a target does not have compiler flags
  declared, it will inherit them from the package, just like source lists.
- Improved debug messages for the `config` command

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.7.1...0.7.2

## 0.7.1: August 24, 2019

- Added the `--noCompile` flag. This flag allows the user to pack and install a
  file without compiling scripts. If the target file is a module, the scripts
  will have to be compiled in the toolset to work.
- Fixed a crash when project has no files

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.7.0...0.7.1

## 0.7.0: July 31, 2019

- The `convert`, `compile`, `pack`, and `install` commands now accept multiple
  target names as arguments. Each target will be processed in turn. In addition,
  `all` is now a keyword that matches all targets.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.6.1...0.7.0

## 0.6.1: July 29, 2019

- Automatically add `.exe` extension to Windows utilities

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.6.0...0.6.1

## 0.6.0: July 28, 2019

- `neverwinter.nim` utilities are now invoked as external tools. The following
  flags have been added:
    - `erfUtil`: the utility used to pack and unpack erf files
    - `erfFlags`: user-defined flags to pass to the erf utility
    - `gffUtil`: the utility used to convert gff files to/from json
    - `gffFlags`: user-defined flags to pass to the gff utility
    - `gffFormat`: the format in which to store gff files (currently supports
      json only)

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.5.0...0.6.0

## 0.5.0: July 27, 2019

- `compile` now only re-compiles scripts that have changed or that include
  scripts that have changed.
- `convert` no longer compiles scripts and `compile` no longer converts gffs
- compiled scripts are deleted from the cache if the source files are deleted

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.4.1...0.5.0

## 0.4.1: July 24, 2019

The user can now add patterns to exclude from sources for either packages or
targets. This can make it easier to filter out unwanted sources and can be
useful to avoid repetition in target definitions. For example, if the package
already specifies a list of files and a target wants all those files except a
few, the target can inherit the package's include list and exclude the few
files it wants.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.4.0...0.4.1

## 0.4.0: July 20, 2019

Added the `config` command. It can be used to get, set, or unset configuration
options. These can be either global options that apply to all packages
(default) or local options that apply only to a given package. These options
are separate from the package file and are not meant to be committed with the
package repository.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.3.0...0.4.0

## 0.3.0: July 19, 2019

This version brings a large-scale code refactor that will improve the speed and
simplicity of further development. The user-facing changes are listed below:

- Configuration options now come from two sources:
    - First, `$XDG_CONFIG_HOME/nasher/user.cfg` is loaded. Any option set here
      is added to the options table. These can represent user-defined defaults
      that override system defaults. Further documentation on these options
      will come soon.
    - Second, the command-line parameters are parsed. Other than commands, any
      parameters passed are added to the table. Positional arguments are
      converted to the appropriate option. These override user defaults.
- The files used to build each target are now cached. Only files that have
  changed since the last build will be re-converted. A clean build can be
  performed by passing `--clean`.
- Added a `convert` command which updates the cache and converts json sources to
  gff.
- `init` will now initialize the directory as a git repository if it was not one
  already.
  - This behavior can be overridden by passing `--vcs:none` as a command-line
    parameter or adding `vcs = "none"` to the user config.
  - the git repo will also contain a `.gitignore` file that will ignore the
    `.nasher` directory, erf, hak, and mod files.
- `list` now prints out all information about packages by default. If
  `--quiet` is passed, will print only the names. Previously, `list` showed
  only names unless called with `--verbose`.
- Choice prompts now choose the first option if the `--default` flag is passed.
  This allows the `init` command to create a package without user intervention
  if desired.

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.2.1...0.3.0

## 0.2.1: July 13, 2019

- You are now prompted before `unpack` overwrites newer files

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.2.0...0.2.1

## 0.2.0: July 12, 2019

### Per-package sources

Source file patterns can now be defined on a per-package basis. Package sources
should list all source files in the package. Targets with no sources will
default to the package sources.

### Unpack rules

`unpack` now places files into the source tree. The user can specify rules for
where to unpack files if they are not found in the source tree. Each rule has a
pattern and a destination. If the filename matches the pattern, it is copied to
the destination.

If the file is not found in the source tree and no matching rule is found, the
file will be placed in the `unkown` folder in the project root. You can then
copy it to the correct location manually.

The `init` command can generate rules to put all files into the `src/`
directory or into `src/$ext/`, where `$ext` is the file extension. It will also
allow the user to add custom rules.

### Minor changes
- The default email is only default for the first author of a package

---

Details: https://github.com/squattingmonk/nasher.nim/compare/0.1.0...0.2.0
