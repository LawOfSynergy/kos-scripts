@lazyGlobal off.

require(list("console", "fs", "ops")).

local module is lex().
local logger is console:logger("telemetry").
set module:logger to logger.

local map is {
    parameter hs, vs.
    local hit is hs:iterator.
    local vit is vs:iterator.

    local result is lex().
    until not hit:next() and not vit:next() {
        result:add(hit:value, vit:value).
    }

    return result.
}.

local toPaddedOrderedList is {
    parameter headers, snapshot.

    local result is list().

    for key in headers {
        if not snapshot:hasSuffix(key) {
            result:add("null").
        } else {
            result:add(snapshot[key]).
        }
    }

    return result.
}.

local function addTS {
    parameter ds.

    local ts is lex().
    local tsgetters is lex().
    set ts:getters to tsgetters.
    set ts:add to {
        parameter header, getter.
        set ds:migrate to true.
        tsgetters:add(header, getter).
    }.
    set ds:timeseries to ts.
}

local function addDeltas{
    parameter ds.

    local delta is lex().
    local dgetters is lex().
    set delta:getters to dgetters.
    local ddefaults is lex().
    set delta:defaults to ddefaults.
    set delta:add to {
        parameter header, getter, default is {return "null".}.
        set ds:migrate to true.
        dgetters:add(header, getter).
        ddefaults:add(header, default).
    }.
    set ds:delta to delta.
}

set module:newDataSheet to {
    parameter name, baseFilePath is "/data/" + name.

    local ds is lex().
    set ds:name to name.
    set ds:baseFilePath to baseFilePath.
    
    local migrate is false.

    local sdata is list().
    local tsgetters is lex().
    local dgetters is lex().
    local ddefaults is lex().


    set ds:static to lex().
    set ds:static:data to sdata.
    
    local function staticAdd {
        parameter value.
        fs:write(console:fmt("%s%n", value), console:fmt("%s-statics.txt", ds:baseFilePath), fs:type:txt:ext).
        sdata:add(value).
    }.
    set ds:static:log to staticAdd@.

    set ds:timeseries to lex().
    set ds:timeseries:getters to tsgetters.
    local function tsAdd {
        parameter header, getter.
        set tsgetters[header] to getter.
    }
    set ds:timeseries:register to tsAdd@.

    set ds:delta to lex().
    set ds:delta:getters to dgetters.
    set ds:delta:defaults to ddefaults.
    local function deltaAdd {
        parameter header, getter, default is "null".
        set dgetters[header] to getter.
        set ddefaults[header] to default.
    }
    set ds:delta:register to deltaAdd@.

    local snap is {
        parameter previous is false.

        local result is lex().

        logger:infof("getters: %s", ds:timeseries:getters).
        //snapshot timeseries datapoints
        for key in ds:timeseries:getters:keys {
            result:add(key, ds:timeseries:getters[key]()).
        }

        //snapshot deltas
        if previous:isType("Lexicon") { //prior data exists
            //calculate deltas
            for key in ds:delta:getters:keys {
                result:add(key, ds:delta:getters[key](previous, result)).
            }
        } else { //prior data does not exist
            //grab default values for each delta datapoint
            for key in ds:delta:defaults:keys {
                local val is ds:delta:defaults[key].
                if val:isType("UserDelegate"){
                    set val to val(result).
                }
                result:add(key, val).
            }
        }

        return result.
    }.

    set ds:snapshot to {
        local filepath is console:fmt("%s-timeseries.csv", baseFilePath).
        local filetype is fs:type:csv:ext.

        local previous is false.
        if ds:hasSuffix("previous") {
            set previous to ds:previous.
        }
        local current is snap(previous).
        local currentHeaders is current:keys.
        set ds:previous to current.

        if migrate {
            set migrate to false.
            if core:volume:exists(filepath) {
                local it is core:volume:open(filepath):readall:iterator.
                local headers is it:value:split(",").
                local datapoints is list().
                it:next().
                
                until not it:next() {
                    datapoints:add(map(headers, it:value:split(","))).
                }
                core:volume:delete(filepath).
                fs:write(currentHeaders, filepath, filetype).
                for datapoint in datapoints {
                    fs:write(toPaddedOrderedList(currentHeaders, datapoint), filepath, filetype).
                }
            }
        }

        if not core:volume:exists(filepath) {
            fs:write(currentHeaders, filepath, filetype).
        }

        fs:write(toPaddedOrderedList(currentHeaders, current), filepath, filetype).
    }.

    set ds:start to {
        ops:addDaemon(console:fmt("telem-%s-daemon", name), ds:snapshot@).
    }.

    set ds:stop to {
        ops:removeDaemon(console:fmt("telem-%s-daemon", name)).
    }.

    return ds.
}.

global telemetry is module.
register("telemetry", telemetry, {return defined telemetry.}).