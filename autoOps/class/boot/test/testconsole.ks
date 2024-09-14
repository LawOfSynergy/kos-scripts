@lazyGlobal off.

local setup is {runPath("/include/console").}.
local teardown is {unset console.}.

local noDeps is test:create(
    "test_console_no_dependencies"
).

local function tst {
    parameter module, name, exec, set is setup, tear is teardown.
    return module:test(name, exec, set, tear).
}

tst(noDeps, "ensure_4_logLevels", {
    assert(defined console, "'console' does not exist").
    assert(console:hasSuffix("level"), "'console' missing member 'level'").
    local function validateLogLevel {
        parameter name, level.
        assert(console:level:hasSuffix(name), "'level' missing member '" + name + "'").
        assert(console:level[name]:hasSuffix("name"), "'error' missing member 'name'").
        assert(console:level[name]:name = name, "'" + name + "' has mismatched 'name': " + console:level[name]:name).
        assert(console:level[name]:hasSuffix("value"), "'" + name + "' missing member 'value'").
        assert(console:level[name]:value = level, "'" + name + "' has mismatched 'value': " + console:level[name]:value + ", expected: " + level).
    }
    validateLogLevel("error", 0).
    validateLogLevel("WARN", 1).
    validateLogLevel("INFO", 2).
    validateLogLevel("DEBUG", 3).
}).

tst(noDeps, "logger_with_no_deps_defaults_to_print", {
    assert(console:hasSuffix("printWriter"), "'printWriter' has not been initialized").
    assert(console:printWriter:isType("UserDelegate"), "'printWriter' is not invokable").
    
    local logger is console:logger().
    logger:info("test logger_with_no_deps_defaults_to_print").
    
    assert(logger:factory:get() = console:printWriter, "'getWriter()' did not return 'console:printWriter'").
}).

tst(noDeps, "logger_with_only_fs_dep_defaults_to_fs:write", 
{
    assert(console:hasSuffix("localWriter"), "'localWriter' does not exist").

    //moved before the check validating localWriter's existence since it is lazily initialized
    local logger is console:logger(). 
    logger:info("test logger_with_only_fs_dep_defaults_to_fs:write").

    assert(console:localWriter <> "", "'localWriter' has not been initialized!").
    assert(console:localWriter:isType("UserDelegate"), "'localWriter' is not invokable").
    assert(logger:factory:get() = console:localWriter, "'getWriter()' did not return 'console:localWriter'").
},
{
    setup().
    runPath("/include/fs").
},
{
    teardown().
    unset fs.
}).

tst(noDeps, "logger_with_only_fs_dep_defaults_to_comms:stashmit", 
{
    assert(console:hasSuffix("localWriter"), "'localWriter' does not exist").

    //moved before the check validating localWriter's existence since it is lazily initialized
    local logger is console:logger(). 
    logger:info("test logger_with_only_fs_dep_defaults_to_comms:stashmit").

    assert(console:commWriter <> "", "'commWriter' has not been initialized!").
    assert(console:commWriter:isType("UserDelegate"), "'commWriter' is not invokable").
    assert(logger:factory:get() = console:commWriter, "'getWriter()' did not return 'console:commWriter'").
},
{
    setup().
    runPath("/include/fs").
    runPath("/include/comms").
},
{
    teardown().
    unset fs.
    unset comms.
}).

tst(noDeps, "logger_with_no_deps_only_writes_once", {
    local testWriter is {
        parameter text, level, loggerLevel, toConsole.
        assert(not toConsole, "wrote to console in addition to console:printWriter").
    }.
    set console:printWriter to testWriter.

    local logger is console:logger(console:level:info, true, console:factoryFor(testWriter)).
    logger:info("test logger_with_no_deps_only_writes_once").
}).

tst(noDeps, "unbound_logger_writes_messages_within_log_level_theshold_only", {
    local invokeCount is 0.
    local delegate is {
        parameter text.
        set invokeCount to invokeCount + 1.
    }.
    local writer is console:unboundWriter:bind(delegate).
    local logger is console:logger(console:level:info, true, console:factoryFor(writer)).

    local function validate {
        parameter level, count.

        set invokeCount to 0.
        set logger:level to level.
        logger:error("test error").
        logger:warn("test warn").
        logger:info("test info").
        logger:debug("test debug").
        assert(invokeCount = count, "expected " + count + " writes, received: " + invokeCount).
    }

    validate(console:level:none, 0).
    validate(console:level:error, 1).
    validate(console:level:warn, 2).
    validate(console:level:info, 3).
    validate(console:level:debug, 4).
}).