import osproc, parseutils, sequtils, streams, strutils

import cli


proc parseCompilerOutput(line: var string): bool =
  ## Intercepts nwnsc's output and converts it into nasher's cli format. Returns
  ## whether any errors were detected. We have to do this here because nwnsc
  ## does not return consistent exit codes.
  var
    token: string
    parsed = line.parseUntil(token, ':') + 2

  case token
  of "Compiling":
    info("Compiling", line[parsed..^1])
  of "Error":
    error(line[parsed..^1])
  else:
    if token == line:
      discard
    else:
      var lines = line.split(':').mapIt(it.strip)
      if lines.contains("Error"):
        error(lines.filterIt(it != "Error").join("\n"))
        result = true
      elif lines.contains("Warning"):
        warning(lines.filterIt(it != "Warning").join("\n"))
      else:
        display(lines.join("\n"))

proc runCompiler*(cmd: string, args: openArray[string] = []): int =
  ## Runs the nwnsc compiler and returns its error code
  let
    params = args.filterIt(it.len > 0)
    options = {poUsePath, poStdErrToStdOut}

  debug("Executing", "$1 $2" % [cmd, params.join(" ")])
  var
    p = startProcess(cmd, args = params, options = options)
    s = p.outputStream
    line = ""

  while p.running:
    if s.readLine(line):
      if line.parseCompilerOutput:
        result = 1

  p.close
