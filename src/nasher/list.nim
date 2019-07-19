from strutils import join
import utils/[cli, config, shared]

const
  helpList = """
  Usage:
    nasher list [options]

  Description:
    For each target, lists the name, description, source files, and final
    filename of all build targets. These names can be passed to the compile or
    pack commands.
    
  Global Options:
    -h, --help     Display help for nasher or one of its commands
    -v, --version  Display version information

  Logging:
    --debug        Enable debug logging
    --verbose      Enable additional messages about normal operation
    --quiet        Disable all logging except errors
    --no-color     Disable color output (automatic if not a tty)
  """

proc list*(opts: Options, pkg: PackageRef) =
  if opts.getBoolOrDefault("help"):
    help(helpList)

  if not loadPackageFile(pkg, getPackageFile()):
    fatal("This is not a nasher project. Please run nasher init.")

  if pkg.targets.len > 0:
    var hasRun = false
    for target in pkg.targets:
      if hasRun:
        stdout.write("\n")
      display("Target:", target.name, priority = HighPriority)
      display("Description:", target.description)
      display("File:", target.file)
      display("Sources:", target.sources.join("\n"))
      hasRun = true
  else:
    fatal("No targets found. Please check your nasher.cfg.")
