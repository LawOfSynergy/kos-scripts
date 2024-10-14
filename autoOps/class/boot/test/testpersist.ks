@lazyGlobal off.

local setup is {}.
local teardown is {}.

local noDeps is test:create(
    "test_persist",
    {
        require("persist").
    },
    {
        unset persist.
    }
).

local function tst {
    parameter module, name, exec, set is setup, tear is teardown.
    return module:test(name, exec, set, tear).
}

tst(noDeps, "module_starts_with_default_handler_and_convenience_refs", {
    assert(persist:handler:length = 1, "Unexpected number of starting handlers. Expected 1, received " + persist:handler:length).
    assert(persist:handler:hasKey("common"), "Missing expected handler: common").
    assert(persist:hasKey("common"), "Missing convenience ref: common").
    assert(persist:common = persist:handler:common, "default handler 'common', does not match convenience ref 'common'").
    assert(persist:hasKey("declare"), "Missing convenience ref: declare").
    assert(persist:declare = persist:handler:common:declare, "convenience ref 'declare' does not match persist:handler:common:declare").
    assert(persist:hasKey("set"), "Missing convenience ref: set").
    assert(persist:set = persist:handler:common:set, "convenience ref 'set' does not match persist:handler:common:set").
    assert(persist:hasKey("get"), "Missing convenience ref: get").
    assert(persist:get = persist:handler:common:get, "convenience ref 'get' does not match persist:handler:common:get").
}).

tst(noDeps, "module_writes_and_reads_correctly", 
    {
        persist:declare("test", "value").
        persist:set("delegate", {return true.}).
        persist:write().
        assert(core:volume:exists("/mem/common.json"), "common.json was not written to upon save").
        unset persist.
        require("persist").
        assert(persist:get("test") = "value", "Expected 'test'='value', got '" + persist:get("test")+"'").
        assert(persist:get("delegate") = "null", "Expected 'delegate'='null', got '" + persist:get("delegate")+"'").
    },
    {
        assert(not core:volume:exists("/mem/common.json"), "Precondition not met: no previous /mem/common.json file").
    },
    {
        core:volume:delete("/mem/common.json").
    }
).