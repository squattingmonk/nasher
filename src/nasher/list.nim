from strutils import join, capitalizeAscii
import utils/shared

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

proc displayField(field, val: string) =
  display(capitalizeAscii(field) & ":", val)

proc list* =
  let targets = parsePackageFile(getPackageFile())
  if targets.len == 0:
    fatal("No targets found. Please check your nasher.cfg.")

  var hasRun = false
  for target in targets.filter("all"):
    if hasRun:
      stdout.write("\n")
    display("Target:", target.name, priority = HighPriority)
    for field, val in fieldPairs(target[]):
      when val is string:
        if field != "name":
          displayField(field, val)
      elif val is seq[string]:
        displayField(field, val.join("\n"))
      else:
        discard

    if isLogging(LowPriority):
      info("Source Files:", getSourceFiles(target.includes, target.excludes).join("\n"))

    for pattern, dir in target.rules.items:
      display("Rule:", pattern & " -> " & dir)
    hasRun = true
