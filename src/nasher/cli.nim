import sequtils, strutils, terminal



type
  CLI = ref object
    showColor: bool
    logLevel: Priority

  DisplayType* = enum
    Error, Warning, Message, Success

  Priority* = enum
    Debug, Low, Medium, High

const
  colWidth = len("Initializing:")
  foregrounds:array[Error .. Success, ForegroundColor] =
    [fgRed, fgYellow, fgCyan, fgGreen]
  styles: array[Debug .. High, set[Style]] =
    [{styleDim}, {styleDim}, {}, {styleBright}]

var cli = CLI(showColor: stdout.isatty, logLevel: Medium)

proc setLogLevel*(level: Priority) =
  cli.logLevel = level

proc isLogging*(level: Priority): bool =
  cli.logLevel <= level

proc setShowColor*(val: bool) =
  cli.showColor = val

proc displayCategory(category: string, displayType: DisplayType, priority: Priority) =
  let
    offset = max(0, colWidth - category.len)
    text = "$#$# " % [spaces(offset), category]

  if cli.showColor:
    if priority != Debug:
      setForegroundColor(stdout, foregrounds[displayType])
    writeStyled(text, styles[priority])
    resetAttributes()
  else:
    stdout.write(text)

proc displayLine(category, line: string, displayType: DisplayType, priority: Priority) =
  displayCategory(category, displayType, priority)
  echo(line)

proc getMsgWidth: int =
  let maxWidth = if stdout.isatty: terminalWidth() else: 80
  result = maxWidth - colWidth - 1

proc display*(category, msg: string, displayType = Message, priority = Medium) =
  ## Displayes a message in the format "{category} {msg}" if the log level is at
  ## or below the given priority. The message is styled based on displayType.
  if priority < cli.logLevel:
    return

  # Word wrap each line so it fits in the terminal
  let lines =
    msg.splitLines.mapIt(it.wordWrap(getMsgWidth())).join("\n").splitLines

  var i = 0
  for line in lines:
    if line.len == 0: continue
    displayLine(if i == 0: category else: "...", line, displayType, priority)
    i.inc

proc display*(msg: string, displayType = Message, priority = Medium) =
  ## Convenience proc to display a message with no category
  display("", msg, displayType, priority)

proc debug*(category, msg: string) =
  ## Convenience proc for displaying debug messages
  display(category, msg, priority = Debug)

proc debug*(msg: string) =
  ## Convenience proc for displaying debug messages with a default category
  debug("Debug:", msg)

proc info*(category, msg: string) =
  ## Convenience proc for displaying low priority messages
  display(category, msg, priority = Low)

proc warning*(msg: string, priority: Priority = Medium) =
  ## Convenience proc for displaying warnings
  display("Warning:", msg, displayType = Warning, priority = priority)

proc error*(msg: string, quit = true) =
  ## Convenience proc for displaying errors
  display("Error:", msg, displayType = Error, priority = High)
  if quit:
    quit(QuitFailure)

proc success*(msg: string, priority: Priority = Medium) =
  display("Success:", msg, displayType = Success, priority = priority)
