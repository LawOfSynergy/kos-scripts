@lazyGlobal off.

require("console").

local module is lex().
local logger is console:logger("persist").
set module:logger to logger.

set module:handler to lex().

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
set module:sanitize to sanitize@.

//create and register a basic lex-backed handler with default get/set logic
set module:basicDataHandler to {
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

    local result is module:handlerFor(
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
set module:handlerFor to {
    parameter name, getDelegate, setDelegate, filepath is "/mem/" + name + ".json".

    local result is lex(
        "name", name,
        "filepath", filepath,
        "readFromDisk", {
            if core:volume:exists(filepath) {        
                logger:debugf("Loading contents of '%s':%n%s", filepath, readJson(filepath)).        
                setDelegate(readJson(filepath)).
            } else {
                logger:warnf("Could not find '%s', data not set", filepath).
            }
        },
        "writeToDisk", {
            local contents is sanitize(getDelegate(), list()).
            logger:debugf("Writing contents to '%s':%n%s", filepath, contents).
            writejson(contents, filepath).
        }
    ).

    set module["handler"][name] to result.
    return result.
}.

local ALL is "persistModuleALLmarker".

set module:write to {
    parameter identifier is ALL.

    if identifier:isType("Enumerable") {
        local it is identifier:iterator.

        until not it:next() {
            if it:value:isType("String") module:handler[it:value]:writeToDisk().
            else logger:error("Expected string in enumerable, received " + it:value).
        }
    } else if identifier:isType("String") {
        if identifier = ALL {
            for handler in module:handler:values {
                handler:writeToDisk().
            }
        } else {
            module:handler[identifier]:writeToDisk().
        }
    } else {
        logger:error("Expected string or enumerable<string>, received " + identifier).
    }
}.

set module:read to {
    parameter identifier is ALL.

    if identifier:isType("Enumerable") {
        local it is identifier:iterator.

        until not it:next() {
            if it:value:isType("String") module:handler[it:value]:readFromDisk().
            else logger:error("Expected string in enumerable, received " + it:value).
        }
    } else if identifier:isType("String") {
        if identifier = ALL {
            for handler in module:handler:values {
                handler:readFromDisk().
            }
        } else {
            module:handler[identifier]:readFromDisk().
        }
    } else {
        logger:error("Expected string or enumerable<string>, received " + identifier).
    }
}.

// init common namespace
set module:common to module:basicDataHandler("common", true).
set module:declare to module:common:declare.
set module:set to module:common:set.
set module:get to module:common:get.

global persist is module.
register("persist", persist, {return defined persist.}).