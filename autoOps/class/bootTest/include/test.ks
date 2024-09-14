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

global function assert {
    parameter condition, message.
    if testModule:context = "" {
        print "ERROR: assert only usable during tests, and test/group setup and teardown".
        return.
    }

    if not condition 
    {
        set testModule:context:status:label to testModule:labels:fail.
        testModule:context:status:failures:add(message).
        if testModule:parent:istype("Lexicon") set testModule:parent:status:label to testModule:labels:fail.
    }
}

global test is testModule.
register("test", test, {return defined test and defined assert.}).