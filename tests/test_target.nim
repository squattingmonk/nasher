import unittest
from strutils import contains
import nasher/utils/target

template checkErrorMsg(msg: string, body: untyped) =
  ## Runs `body` and checks that any raised exception message contains `msg`.
  try:
    body
  except:
    check msg in getCurrentExceptionMsg()
    raise

suite "Target type":
  test "Target equivalence":
    check:
      Target() == Target()
      Target(name: "foo") == Target(name: "foo")
      Target(name: "foo", file: "bar") == Target(name: "foo", file: "bar")

    check:
      Target(name: "foo") != Target()
      Target(name: "foo") != Target(name: "bar")
      Target(name: "foo", file: "bar") != Target(name: "foo", file: "baz")
  
suite "Target filtering":
  setup:
    let targets = @[Target(name: "foo"),
                    Target(name: "bar")]

  test "Exception on unknown target":
    expect KeyError:
      checkErrorMsg("Unknown target foobar"):
        discard targets.filter("foobar")

  test "Get target by name":
    check:
      targets.filter("foo") == @[targets[0]]
      targets.filter("bar") == @[targets[1]]

  test "Get default target with blank name":
    check:
      targets.filter("") == @[targets[0]]

  test "Get all targets with \"all\" group":
    check:
      targets.filter("all") == targets

  test "Get multiple targets with semicolon-delimited list":
    check:
      targets.filter("bar;foo") == @[targets[1], targets[0]]

  test "Each target returned only once":
    check:
      targets.filter("foo;foo") == @[targets[0]]

