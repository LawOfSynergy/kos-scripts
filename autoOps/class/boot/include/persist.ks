@lazyGlobal off.

require("console").

local persistModule is lex().
local logger is console:logger().
set persistModule:logger to logger.

set persistModule:handlers to list().


//create and register a handler for persisting a new lexicon to disk
set persistModule:handlerFor to {
    parameter filename, getDelegate, setDelegate.

    local filepath is "/mem/" + filename + ".json".

    local result is lex(
        "filename", filename,
        "filepath", filepath,
        "readFromDisk", {
            if core:volume:exists(filepath) {                
                setDelegate(readJson(filepath)).
            }
        },
        "writeToDisk", {
            //sanitize the lexicon to remove any delegates
            local contents is getDelegate().
            for var in contents:values if var:typename = "UserDelegate" set var to "null".
            writejson(contents, filepath).
        }
    ).

    persistModule:handlers:add(result).

    return result.
}.

local ALL is "persistModuleALLmarker".

set persistModule:write to {
    parameter identifier is ALL.

    for handler in persistModule:handlers {
        if (
            identifier = ALL 
            or identifier = handler:filename 
            or identifier = handler:filepath
            or identifier:contains(handler:filename)
            or identifier:contains(handler:filepath)
        ) handler:writeToDisk().
    }
}.

set persistModule:read to {
    parameter identifier is ALL.

    for handler in persistModule:handlers {
        if (
            identifier = ALL 
            or identifier = handler:filename 
            or identifier = handler:filepath
            or identifier:contains(handler:filename)
            or identifier:contains(handler:filepath)
        ) handler:readFromDisk().
    }
}.

set persistModule:varData to lexicon().

// define a variable with this value only if it doesn't already exist
set persistModule:declare to {
    parameter varName.
    parameter value.
    if not persistModule:varData:haskey(varName) set persistModule["varData"][varName] to value.
}.

// set or create a variable value. If no value supplied, delete the variable or just do nothing
set persistModule:set to {
    parameter varName.
    parameter value is "killmeplzkthxbye".
    if value = "killmeplzkthxbye" and persistModule:varData:haskey(varName) persistModule:varData:remove(varName).
    else set persistModule["varData"][varName] to value.
}.

// get the value of a variable
set persistModule:get to {
    parameter varName.
    if persistModule:varData:haskey(varName) return persistModule["varData"][varName].
    else return 0.
}.

// init varData namespace

local varDataHandler is persistModule:handlerFor("varData", {return persistModule:varData.}, {parameter data. set persistModule:varData to data.}).
varDataHandler:readFromDisk().

global persist is persistModule.
register("persist", persist, {return defined persist.}).