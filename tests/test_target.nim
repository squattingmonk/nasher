import unittest

import nasher/utils/target

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

  test "Get target by name":
    let
      foo = Target(name: "foo")
      bar = Target(name: "bar")
      baz = Target(name: "baz")
      targets = @[foo, bar, baz]
      empty: seq[Target] = @[]

    check:
      targets.getTarget("foo") == foo
      targets.getTarget("bar") == bar
      targets.getTargets(@["all"]) == targets
      targets.getTargets(@[]) == empty








