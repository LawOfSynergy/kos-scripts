@lazyGlobal off.

local setup is {require("console").}.
local teardown is {unset console.}.

local defaultGroup is test:create(
    "test_console_no_dependencies"
).

local function tst {
    parameter module, name, exec, set is setup, tear is teardown.
    return module:test(name, exec, set, tear).
}

tst(defaultGroup, "ensure_format_takes_correct_num_params", {
    local result is console:fmt("this %% string %s values like %s%", "takes", 23).
    assert(result = "this % string takes values like 23%", "String formatting did not occur correctly. Expected '%this % string takes values like 23', recieved '" + result + "'").
}).

tst(defaultGroup, "ensure_4_logLevels", {
    assert(defined console, "'console' does not exist").
    assert(console:hasSuffix("level"), "'console' missing member 'level'").
    local function validateLogLevel {
        parameter name, level.
        assertf(console:level:hasSuffix(name), "'level' missing member '%s'", name).
        assertf(console:level[name]:hasSuffix("name"), "'%s' missing member 'name'", name).
        assertf(console:level[name]:name = name, "'%s' has mismatched 'name': %s", name, console:level[name]:name).
        assertf(console:level[name]:hasSuffix("value"), "'%s' missing member 'value'", name).
        assertf(console:level[name]:value = level, "'%s' has mismatched 'value': %s, expected: %s", name, console:level[name]:value, level).
    }
    validateLogLevel("NONE", -1).
    validateLogLevel("ERROR", 0).
    validateLogLevel("WARN", 1).
    validateLogLevel("INFO", 2).
    validateLogLevel("DEBUG", 3).
}).

tst(defaultGroup, "logger_with_no_deps_defaults_to_print", {
    assert(console:hasSuffix("printWriter"), "'printWriter' has not been initialized").
    assert(console:printWriter:isType("UserDelegate"), "'printWriter' is not invokable").
    
    local logger is console:logger("test").
    logger:info("test logger_with_no_deps_defaults_to_print").
    
    assert(logger:factory:get() = console:printWriter, "'getWriter()' did not return 'console:printWriter'").
}).

tst(defaultGroup, "logger_with_only_fs_dep_defaults_to_fs:write", 
{
    assert(console:hasSuffix("localWriter"), "'localWriter' does not exist").

    //moved before the check validating localWriter's existence since it is lazily initialized
    local logger is console:logger("test"). 
    logger:info("test logger_with_only_fs_dep_defaults_to_fs:write").

    assert(console:localWriter <> "", "'localWriter' has not been initialized!").
    assert(console:localWriter:isType("UserDelegate"), "'localWriter' is not invokable").
    assert(logger:factory:get() = console:fsWriter, "'getWriter()' did not return 'console:localWriter'").
},
{
    setup().
    require("fs").
},
{
    teardown().
    unset fs.
}).

tst(defaultGroup, "logger_with_comms_dep_defaults_to_comms:stashmit", 
{
    assert(console:hasSuffix("localWriter"), "'localWriter' does not exist").

    //moved before the check validating localWriter's existence since it is lazily initialized
    local logger is console:logger("test"). 
    logger:info("test logger_with_only_fs_dep_defaults_to_comms:stashmit").

    assert(console:commWriter <> "", "'commWriter' has not been initialized!").
    assert(console:commWriter:isType("UserDelegate"), "'commWriter' is not invokable").
    assert(logger:factory:get() = console:commWriter, "'getWriter()' did not return 'console:commWriter'").
},
{
    setup().
    require(list("fs", "comms")).
},
{
    teardown().
    unset fs.
    unset comms.
}).

tst(defaultGroup, "unbound_logger_writes_messages_within_log_level_theshold_only", {
    local act is mock(1).
    local writer is console:unboundWriter:bind(act:invoke@).
    local logger is console:logger("test", console:level:info, true, console:factoryFor(writer)).

    local function validate {
        parameter level, count.

        act:reset().
        set logger:level to level.
        logger:error("test error").
        logger:warn("test warn").
        logger:info("test info").
        logger:debug("test debug").
        assertf(act:invocations:length = count, "expected %s writes, received: %s", count, act:invocations:length).
    }

    validate(console:level:none, 0).
    validate(console:level:error, 1).
    validate(console:level:warn, 2).
    validate(console:level:info, 3).
    validate(console:level:debug, 4).
}).