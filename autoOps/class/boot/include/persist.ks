@lazyGlobal off.

require("console").

local persistModule is lex().
local logger is console:logger("persist").
set persistModule:logger to logger.

set persistModule:handler to lex().

local function sanitize {
    parameter ref, visited.

    if ref:isType("UserDelegate") return "null".
    if ref:isType("Lexicon") {
        if(visited:contains(ref)) return "cyclic ref:" + visited:indexof(ref).
        visited:add(ref).

        for key in ref:keys {
            set ref[key] to sanitize(ref[key], visited).
        }
        return ref.
    }
    if ref:isType("Enumerable") {
        if(visited:contains(ref)) return "cyclic ref:" + visited:indexof(ref).
        visited:add(ref).

        local newList is list().
        local it is ref:iterator.
        until not it:next() {
            newList:add(sanitize(it:value, visited)).
        }
    }
    return ref.
}
set persistModule:sanitize to sanitize@.

//create and register a basic lex-backed handler with default get/set logic
set persistModule:basicDataHandler to {
    parameter name, 
        readOnCreate is false, 
        data is lex(), 
        getDelegate is {
            return result:data.
        },
        setDelegate is {
            parameter newData.
            set result:data to newData.
        },
        filepath is "/mem/" + name + ".json".

    local result is persistModule:handlerFor(
        name, 
        getDelegate, 
        setDelegate,
        filepath
    ).
    set result:data to data.
    set result:declare to {
        parameter varName.
        parameter value.
        if not result:data:haskey(varName) set result["data"][varName] to value.
    }.
    set result:set to {
        parameter varName.
        parameter value is "killmeplzkthxbye".
        if value = "killmeplzkthxbye" and result:data:haskey(varName) result:data:remove(varName).
        else set result["data"][varName] to value.
    }.
    set result:get to {
        parameter varName.
        if result:data:haskey(varName) return result["data"][varName].
        else return 0.
    }.
    if readOnCreate result:readFromDisk().
    return result.
}.

//create and register a handler for persisting a new lexicon to disk
set persistModule:handlerFor to {
    parameter name, getDelegate, setDelegate, filepath is "/mem/" + name + ".json".

    local result is lex(
        "name", name,
        "filepath", filepath,
        "readFromDisk", {
            if core:volume:exists(filepath) {        
                logger:debug(console:fmt("Loading contents of '%s':%n%s", filepath, readJson(filepath))).        
                setDelegate(readJson(filepath)).
            } else {
                logger:warn(console:fmt("Could not find '%s', data not set", filepath)).
            }
        },
        "writeToDisk", {
            local contents is sanitize(getDelegate(), list()).
            logger:debug(console:fmt("Writing contents to '%s':%n%s", filepath, contents)).
            writejson(contents, filepath).
        }
    ).

    set persistModule["handler"][name] to result.
    return result.
}.

local ALL is "persistModuleALLmarker".

set persistModule:write to {
    parameter identifier is ALL.

    if identifier:isType("Enumerable") {
        local it is identifier:iterator.

        until not it:next() {
            if it:value:isType("String") persistModule:handler[it:value]:writeToDisk().
            else logger:error("Expected string in enumerable, received " + it:value).
        }
    } else if identifier:isType("String") {
        if identifier = ALL {
            for handler in persistModule:handler:values {
                handler:writeToDisk().
            }
        } else {
            persistModule:handler[identifier]:writeToDisk().
        }
    } else {
        logger:error("Expected string or enumerable<string>, received " + identifier).
    }
}.

set persistModule:read to {
    parameter identifier is ALL.

    if identifier:isType("Enumerable") {
        local it is identifier:iterator.

        until not it:next() {
            if it:value:isType("String") persistModule:handler[it:value]:readFromDisk().
            else logger:error("Expected string in enumerable, received " + it:value).
        }
    } else if identifier:isType("String") {
        if identifier = ALL {
            for handler in persistModule:handler:values {
                handler:readFromDisk().
            }
        } else {
            persistModule:handler[identifier]:readFromDisk().
        }
    } else {
        logger:error("Expected string or enumerable<string>, received " + identifier).
    }
}.

// init common namespace
set persistModule:common to persistModule:basicDataHandler("common", true).
set persistModule:declare to persistModule:common:declare.
set persistModule:set to persistModule:common:set.
set persistModule:get to persistModule:common:get.

global persist is persistModule.
register("persist", persist, {return defined persist.}).