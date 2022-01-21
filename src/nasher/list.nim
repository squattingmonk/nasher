from strutils import join
import utils/[cli, options, shared]

const
  helpList* = """
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
  if pkg.targets.len > 0:
    var hasRun = false
    for target in pkg.targets:
      if hasRun:
        stdout.write("\n")
      display("Target:", target.name, priority = HighPriority)
      display("Description:", target.description)
      display("File:", target.file)
      display("Includes:", target.includes.join("\n"))
      display("Excludes:", target.excludes.join("\n"))
      display("Filters:", target.filters.join("\n"))
      if isLogging(LowPriority):
        info("Source Files:", getSourceFiles(target.includes, target.excludes).join("\n"))

      for pattern, dir in target.rules.items:
        display("Rule:", pattern & " -> " & dir)
      hasRun = true
  else:
    fatal("No targets found. Please check your nasher.cfg.")
