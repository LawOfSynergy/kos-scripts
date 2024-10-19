@lazyGlobal off.

local testModule is lex().
set testModule:instances to list().
set testModule:context to "".

local testRoot is "0:/autoOps/vessel/" + boot:profile + "/" + boot:launchNum + "/test/reports/".
local reporter is {
    parameter filename.
    local logPath is testRoot + filename + ".txt".
    return {
        parameter line is "".
        print line.
        log line to logPath.
    }.
}.

set testModule:labels to lex().
local function labelFor {
    parameter name, color.
    local label is lex().
    set label:name to name.
    set label:color to color.
    set testModule["labels"][name] to label.
}

labelFor("pass", green).
labelFor("fail", red).
labelFor("skipped", yellow).

local function newStatus {
    local stat is lex().
    set stat:label to testModule:labels:skipped.
    set stat:failures to list().
    return stat.
}

set testModule:create to {
    parameter name, setup is false, teardown is false.

    local instance is lex().
    set instance:name to name.
    set instance:tests to list().
    set instance:setup to setup.
    set instance:teardown to teardown.
    set instance:status to newStatus().
    set instance:test to {
        parameter tname, runner, before is false, after is false.
        local testinst is lex().
        set testinst:name to tname.
        set testinst:parent to instance:name.
        set testinst:run to runner.
        set testinst:setup to before.
        set testinst:teardown to after.
        set testinst:status to newStatus().
        instance:tests:add(testinst).
        print "created test " + tname.
        return testinst.
    }.
    testModule:instances:add(instance).

    print "created test group " + name.

    return instance.
}.

set testModule:start to {
    //run tests
    for module in testModule:instances {
        set testModule:parent to false.
        set testModule:context to module.
        if module:setup:istype("UserDelegate") {
            print "Performing setup for test group " + module:name.
            module:setup().
        } else {
            print "No setup required for test group " + module:name + ", setup is " + module:setup.
        }
        if module:status:label = testModule:labels:skipped {
            print "Executing tests in group " + module:name.
            set testModule:parent to module.
            for t in module:tests {
                set testModule:context to t.
                if t:setup:istype("UserDelegate") {
                    print "Performing setup for test " + t:name.
                    t:setup().
                } else {
                    print "No setup required for test " + t:name + ", setup is " + t:setup.
                }
                if t:status:label = testModule:labels:skipped  {
                    print "Executing test " + t:name.
                    t:run().
                } else {
                    print "Issue during test setup, skipping test " + t:name.
                }
                if t:teardown:istype("UserDelegate") {
                    print "Performing teardown for test " + t:name.
                    t:teardown().
                } else {
                    print "No teardown required for test " + t:name.
                }
                if t:status:label = testModule:labels:skipped set t:status:label to testModule:labels:pass.
            }
        } else {
            print "Issue during test group setup, skipping tests in group " + module:name.
        }
        set testModule:parent to false.
        set testModule:context to module.
        if module:teardown:istype("UserDelegate") {
            print "Performing teardown for test group " + module:name.
            module:teardown().
        } else {
            print "No teardown required for test group " + module:name.
        }
        if module:status:label = testModule:labels:skipped set module:status:label to testModule:labels:pass.
    }
    set testModule:context to "".

    //generate report
    for module in testModule:instances {
        local report is reporter(module:name).
        report(module:name + " " + module:status:label:name).
        for message in module:status:failures {
            report("    " + message).
        }
        report().
        for t in module:tests {
            report("    " + t:name + " " + t:status:label:name).
            for message in t:status:failures {
                report("        " + message).
            }
            report().
        }
    }
}.

global mock is {
    parameter argCount.

    //the full mock context, for configuration and validation
    local result is lex().
    set result:invocations to list().
    //clear the invocations list
    set result:reset to {
        set result:invocations to list().
        set result:returnVals to queue().
    }.
    //the mock function
    set result:invoke to {
        //capture values of this invocation
        local args is list().
        from {local i is 0.} until i = argCount step {set i to i + 1.} do {
            parameter arg.
            args:add(arg).
        }
        result:invocations:add(args).

        //return value from this invocation
        if result:returnVals:empty return. //no return values
        local rv is result:returnVals:peek().
        if not rv:persist result:returnVals:pop(). //pop non-terminal return values
        return rv:value.
    }.
    set result:returnVals to queue().
    //fluent terminator for final successive return value
    set result:finallyReturn to {
        parameter value.
        result:returnVals:push(lex("value", value, "persist", true)).
    }.
    //fluent style for sequenced returns
    set result:thenReturn to {
        parameter value.
        result:returnVals:push(lex("value", value, "persist", false)).
        return result.
    }.

    return result.
}.

global spy is {
    //the full mock context, for configuration and validation
    local result is lex().
    set result:invocations to list().
    //clear the invocations list
    set result:reset to {
        set result:invocations to list().
        set result:delegates to queue().
    }.
    set result:delegates to queue().
    //fluent style configurator to set up invocation sequence.
    set result:then to {
        parameter argCount, func. //argcount is here to support varargs invocations
        local ctx is lex("argCount", argCount, "invoke", func).
        set ctx:persist to false.
        result:delegates:push(ctx).
        return result.
    }.
    //fluent style terminator to set p invocation sequence
    set result:finally to {
        parameter argCount, func. //argcount is here to support varargs invocations
        local ctx is lex("argCount", argCount, "invoke", func).
        set ctx:persist to true.
        result:delegates:push(ctx).
        return result.
    }.

    //the spy function
    set result:invoke to {
        local delCtx is result:delegates:peek().
        if not delCtx:persist result:delegates:pop().

        local del is delCtx:invoke.
        local ctx is lex().
        set ctx:args to list().

        //capture and bind parameters
        from {local i is 0.} until i = delCtx:argCount step {set i to i + 1.} do {
            parameter arg.
            ctx:args:add(arg).
            set del to del:bind(arg).
        }

        //invoke and store return value
        set ctx:rv to del().
        result:invocations:add(ctx).
        return ctx:rv.
    }.

    return result.
}.

global assert is {
    parameter condition, message.
    if testModule:context = "" {
        print "ERROR: assert only usable during tests, and test/group setup and teardown".
        return.
    }

    if not condition 
    {
        if message:isType("UserDelegate") set message to message().
        set testModule:context:status:label to testModule:labels:fail.
        testModule:context:status:failures:add(message).
        if testModule:parent:istype("Lexicon") set testModule:parent:status:label to testModule:labels:fail.
    }
}.

global assertf is {
    parameter condition, message.

    local result is "".
    local s is message.
    local i is 0.
    local param is "undefined".
    until i >= s:length {
        if console:fmtUtils:consumeParam(s, i) {
            parameter p.
            set param to p.
        }
        local sub is console:fmtUtils:substitute(s, i, param).
        set result to result + sub:value.
        set i to i + sub:inc.
    }

    assert(condition, result).
}.

global test is testModule.
register("test", test, {return defined test and defined assert and defined mock.}, {unset test. unset assert. unset mock.}).