@lazyGlobal off.

global test is lex().
set test:instances to list().
set test:context to "".

local testRoot is "/autoOps/test/reports/".
local reporter is {
    parameter filename.
    local logFile is testRoot + filename + ".txt".
    return {
        parameter line is "".
        print line.
        log line to logFile.
    }.
}.

set test:labels to lex().
local function labelFor {
    parameter name, color.
    local label is lex().
    set label:name to name.
    set label:color to color.
    test:labels:append(label).
}

labelFor("pass", green).
labelFor("fail", red).
labelFor("skipped", yellow).

local function newStatus {
    local status is lex().
    set status:label to test:labels:skipped.
    set status:failures to list().
}

set test:create to {
    parameter name, setup is false, teardown is false.

    local instance is lex().
    set instance:name to name.
    set instance:tests to list().
    set instance:setup to setup.
    set instance:teardown to teardown.
    set instance:status to newStatus().
    set instance:test to {
        parameter name, run, before is false, after is false.
        local testinst is lex().
        set testinst:name to name.
        set testinst:parent to instance.
        set testinst:run to run.
        set testinst:setup to setup.
        set testinst:teardown to teardown.
        set testinst:status to newStatus().
        instance:tests:append(testinst).
        return testinst.
    }.
    test:instances:append(instance).
    return instance.
}.

global function start {
    //run tests
    for module in test:instances {
        set test:context to module.
        if module:setup <> false module:setup().
        if module:status:label = test:labels:skipped {
            for t in module:tests {
                set test:context to t.
                if t:setup <> false t:setup().
                if t:status:label = test:labels:skipped  {
                    t:run().
                }
                t:teardown().
                if t:status:label = test:labels:skipped set t:status:label to test:labels:pass.
            }
        }
        set test:context to module.
        module:teardown().
        if module:status:label = test:labels:skipped set module:status:label to test:labels:pass.
    }
    set test:context to "".

    //generate report
    for module in test:instances {
        local report is reporter(module:name).
        report(module:name + " " + module:status:label:name).
        for message in module:status:failures {
            report("    " + message).
        }
        report().
        for t in module {
            set status to statusFor(t).
            report("    " + t:name + " " + t:status:label:name).
            for message in t:status:failures {
                report("        " + message).
            }
            report().
        }
    }
}

global function assert {
    parameter condition, message.
    if test:context = "" {
        print "ERROR: assert only usable during tests, and test/group setup and teardown".
        return.
    }

    if not condition 
    {
        set test:context:status:label to test:labels:fail.
        test:context:status:failures:append(message).
        if test:context:hasSuffix("parent") {
            set test:context:parent:status:label to test:labels:fail.
        }
    }
}
