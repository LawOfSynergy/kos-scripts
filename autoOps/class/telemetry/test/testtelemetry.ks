@lazyGlobal off.

local staticsFile is "/data/test-statics.txt".
local timeseriesFile is "/data/test-timeseries.csv".

local timeMock is mock(0).
local deltaTimeMock is mock(2).
local ds is false.

local logger is console:logger("testtelemetry").

local setup is {
    require("telemetry").
    set ds to telemetry:newDataSheet("test").
}.
local teardown is {
    unset telemetry.
    set ds to false.
    timeMock:reset().
    deltaTimeMock:reset().
    if core:volume:exists(staticsFile) core:volume:delete(staticsFile).
    if core:volume:exists(timeseriesFile) core:volume:delete(timeseriesFile).
}.

local defaultGroup is test:create("test_telemetry").

local function tst {
    parameter module, name, exec, set is setup, tear is teardown.
    return module:test(name, exec, set, tear).
}

tst(defaultGroup, "ensure_blank_datasheet_is_well_formed", {
    assert(ds:hasSuffix("name"), "missing identifier: 'ds:name'").
    assertf(ds:name = "test", "expected 'ds:name' to be 'test', received %s", ds:name).
    assert(ds:hasSuffix("baseFilePath"), "missing identifier: 'ds:baseFilePath'").
    assertf(ds:baseFilePath = "/data/test", "expected 'ds:baseFilePath' to be '/data/test', received %s", ds:baseFilePath).
    assert(ds:hasSuffix("static"), "missing identifier: 'ds:static'").
    assert(ds:static:hasSuffix("data"), "missing identifier: 'ds:static:data'").
    assert(ds:static:hasSuffix("add"), "missing identifier: 'ds:static:add'").
    assert(ds:hasSuffix("timeseries"), "missing identifier: 'ds:timeseries'").
    assert(ds:timeseries:hasSuffix("getters"), "missing identifier: 'ds:timeseries:getters'").
    assert(ds:timeseries:hasSuffix("add"), "missing identifier: 'ds:timeseries:add'").
    assert(ds:hasSuffix("delta"), "missing identifier: 'ds:delta'").
    assert(ds:delta:hasSuffix("getters"), "missing identifier: 'ds:delta:getters'").
    assert(ds:delta:hasSuffix("defaults"), "missing identifier: 'ds:delta:defaults'").
    assert(ds:delta:hasSuffix("add"), "missing identifier: 'ds:delta:add'").
    assert(ds:hasSuffix("snapshot"), "missing identifier: 'ds:snapshot'").
    assert(ds:hasSuffix("start"), "missing identifier: 'ds:start'").
    assert(ds:hasSuffix("stop"), "missing identifier: 'ds:stop'").

}).

tst(defaultGroup, "ensure_snapshots_create_timeseries_and_deltas_correctly", {
    timeMock:thenReturn(1):thenReturn(2).
    ds:timeseries:add("time", timeMock:invoke@).
    ds:delta:add("dTime", {
        parameter prev, current.
        return current:time - prev:time.
    }).

    logger:infof("ds: %s", ds).
    
    ds:snapshot().
    assert(ds:previous:time = 1, "expected 'time' = 0, received: " + ds:previous:time).
    assert(ds:previous:dTime = "null", "expected 'dTime' = 'null', received: " + ds:previous:dTime).
    ds:snapshot().
    assert(ds:previous:time = 1, "expected 'time' = 1, received: " + ds:previous:time).
    assert(ds:previous:dTime = 1, "expected 'dTime' = 1, received: " + ds:previous:dTime).
}).

// ensure file migration occurs properly