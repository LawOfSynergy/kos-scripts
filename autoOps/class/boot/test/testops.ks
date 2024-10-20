@lazyGlobal off.

local initMock is mock(1).
local stepSpy is spy().

local setup is {
    require("ops").
    ops:opCodeFor("test", initMock:invoke, stepSpy:invoke).
}.
local teardown is {
    unset ops.
    unset persist.
    initMock:reset().
    stepSpy:reset().
}.

local defaultGroup is test:create(
    "test_ops"
).

local function tst {
    parameter module, name, exec, set is setup, tear is teardown.
    return module:test(name, exec, set, tear).
}

tst(defaultGroup, "ensure_ops_starts_with_no_context_or_tasks", {
    assert(not ops:opsHandler:data:hasSuffix("ctx"), {return console:fmt("Expected no context, recieved %s", ops:opsHandler:data:ctx).}).
    assert(not ops:opsHandler:data:hasSuffix("tasks"), {return console:fmt("Expected no tasks, recieved %s", ops:opsHandler:data:tasks).}).
}).

tst(defaultGroup, "ensure_ops_file_parsed_correctly", {
    ops:load:file(core:volume, "/test/ops.ops").
    assertf(ops:opsHandler:data:tasks:length = 4, "Expected 4 tasks, received: %s", ops:opsHandler:data:tasks:length).
    assertf(ops:opsHandler:data:tasks[0]:name = "test", "Expected 0th task to be named test, received: %s", ops:opsHandler:data:tasks[0]:name).
    assertf(ops:opsHandler:data:tasks[0]:args:length = 0, "Expected 0th task to have 0 args, received: %s", ops:opsHandler:data:tasks[0]:args:length).
    assertf(ops:opsHandler:data:tasks[1]:name = "test", "Expected 1st task to be named test, received: %s", ops:opsHandler:data:tasks[1]:name).
    assertf(ops:opsHandler:data:tasks[1]:args:length = 1, "Expected 1st task to have 1 arg, received: %s", ops:opsHandler:data:tasks[1]:args:length).
    assertf(ops:opsHandler:data:tasks[1]:args[0] = "a", "Expected 1st task to have 0tharg 'a', received: '%s'", ops:opsHandler:data:tasks[1]:args[0]).
    assertf(ops:opsHandler:data:tasks[2]:name = "test", "Expected 2nd task to be named test, received: %s", ops:opsHandler:data:tasks[2]:name).
    assertf(ops:opsHandler:data:tasks[2]:args:length = 2, "Expected 2nd task to have 2 args, received: %s", ops:opsHandler:data:tasks[2]:args:length).
    assertf(ops:opsHandler:data:tasks[2]:args[0] = "b", "Expected 2nd task to have 0th arg 'b', received: '%s'", ops:opsHandler:data:tasks[2]:args[0]).
    assertf(ops:opsHandler:data:tasks[2]:args[1] = "c", "Expected 2nd task to have 1st arg 'c', received: '%s'", ops:opsHandler:data:tasks[2]:args[1]).
    assertf(ops:opsHandler:data:tasks[3]:name = "test", "Expected 3rd task to be named test, received: %s", ops:opsHandler:data:tasks[3]:name).
    assertf(ops:opsHandler:data:tasks[3]:args:length = 3, "Expected 3rd task to have 3 args, received: %s", ops:opsHandler:data:tasks[3]:args:length).
    assertf(ops:opsHandler:data:tasks[3]:args[0] = "d", "Expected 3rd task to have 0th arg 'd', received: '%s'", ops:opsHandler:data:tasks[3]:args[0]).
    assertf(ops:opsHandler:data:tasks[3]:args[1] = "e", "Expected 3rd task to have 1st arg 'e', received: '%s'", ops:opsHandler:data:tasks[3]:args[1]).
    assertf(ops:opsHandler:data:tasks[3]:args[2] = "f", "Expected 3rd task to have 2nd arg 'f', received: '%s'", ops:opsHandler:data:tasks[3]:args[2]).
},
{ //setup
    setup().
    log "test" to "/test/ops.ops".
    log "test:a" to "/test/ops.ops".
    log "test:b:c" to "/test/ops.ops".
    log "test:d:e:f" to "/test/ops.ops".
},
{ //teardown
    teardown().
    core:volume:delete("/test/ops.ops").
}).

tst(defaultGroup, "ensure_ops_text_parsed_correctly", {
    ops:load:ops(console:fmt("test%ntest:a%ntest:b:c%ntest:d:e:f")).
    assertf(ops:opsHandler:data:tasks:length = 4, "Expected 4 tasks, received: %s", ops:opsHandler:data:tasks:length).
    assertf(ops:opsHandler:data:tasks[0]:name = "test", "Expected 0th task to be named test, received: %s", ops:opsHandler:data:tasks[0]:name).
    assertf(ops:opsHandler:data:tasks[0]:args:length = 0, "Expected 0th task to have 0 args, received: %s", ops:opsHandler:data:tasks[0]:args:length).
    assertf(ops:opsHandler:data:tasks[1]:name = "test", "Expected 1st task to be named test, received: %s", ops:opsHandler:data:tasks[1]:name).
    assertf(ops:opsHandler:data:tasks[1]:args:length = 1, "Expected 1st task to have 1 arg, received: %s", ops:opsHandler:data:tasks[1]:args:length).
    assertf(ops:opsHandler:data:tasks[1]:args[0] = "a", "Expected 1st task to have 0tharg 'a', received: '%s'", ops:opsHandler:data:tasks[1]:args[0]).
    assertf(ops:opsHandler:data:tasks[2]:name = "test", "Expected 2nd task to be named test, received: %s", ops:opsHandler:data:tasks[2]:name).
    assertf(ops:opsHandler:data:tasks[2]:args:length = 2, "Expected 2nd task to have 2 args, received: %s", ops:opsHandler:data:tasks[2]:args:length).
    assertf(ops:opsHandler:data:tasks[2]:args[0] = "b", "Expected 2nd task to have 0th arg 'b', received: '%s'", ops:opsHandler:data:tasks[2]:args[0]).
    assertf(ops:opsHandler:data:tasks[2]:args[1] = "c", "Expected 2nd task to have 1st arg 'c', received: '%s'", ops:opsHandler:data:tasks[2]:args[1]).
    assertf(ops:opsHandler:data:tasks[3]:name = "test", "Expected 3rd task to be named test, received: %s", ops:opsHandler:data:tasks[3]:name).
    assertf(ops:opsHandler:data:tasks[3]:args:length = 3, "Expected 3rd task to have 3 args, received: %s", ops:opsHandler:data:tasks[3]:args:length).
    assertf(ops:opsHandler:data:tasks[3]:args[0] = "d", "Expected 3rd task to have 0th arg 'd', received: '%s'", ops:opsHandler:data:tasks[3]:args[0]).
    assertf(ops:opsHandler:data:tasks[3]:args[1] = "e", "Expected 3rd task to have 1st arg 'e', received: '%s'", ops:opsHandler:data:tasks[3]:args[1]).
    assertf(ops:opsHandler:data:tasks[3]:args[2] = "f", "Expected 3rd task to have 2nd arg 'f', received: '%s'", ops:opsHandler:data:tasks[3]:args[2]).
}).

// test ops file gets renamed when loaded
// test ops file inits and steps through tasks appropriately
// test ops context and task list are removed when task list is completed
// test ops context gets persisted and restored correctly
// test timers execute at or after scheduled duration
// test persistent timers are kept until persist is set to false
