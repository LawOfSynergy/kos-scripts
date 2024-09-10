@lazyGlobal off.

require("console").

global persist is lex().
local logger is console:logger().
set persist:logger to logger.

set persist:handlers to list().


//create and register a handler for persisting a new lexicon to disk
set persist:handlerFor to {
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

    persist:handlers:add(result).

    return result.
}.

local ALL is "persistModuleALLmarker".

set persist:write to {
    parameter identifier is ALL.

    for handler in persist:handlers {
        if (
            identifier = ALL 
            or identifier = handler:filename 
            or identifier = handler:filepath
            or identifier:contains(handler:filename)
            or identifier:contains(handler:filepath)
        ) handler:writeToDisk().
    }
}.

set persist:read to {
    parameter identifier is ALL.

    for handler in persist:handlers {
        if (
            identifier = ALL 
            or identifier = handler:filename 
            or identifier = handler:filepath
            or identifier:contains(handler:filename)
            or identifier:contains(handler:filepath)
        ) handler:readFromDisk().
    }
}.

set persist:varData to lexicon().

// define a variable with this value only if it doesn't already exist
set persist:declare to {
    parameter varName.
    parameter value.
    if not persist:varData:haskey(varName) set persist["varData"][varName] to value.
}.

// set or create a variable value. If no value supplied, delete the variable or just do nothing
set persist:set to {
    parameter varName.
    parameter value is "killmeplzkthxbye".
    if value = "killmeplzkthxbye" and persist:varData:haskey(varName) persist:varData:remove(varName).
    else set persist["varData"][varName] to value.
}.

// get the value of a variable
set persist:get to {
    parameter varName.
    if persist:varData:haskey(varName) return persist["varData"][varName].
    else return 0.
}.

// init varData namespace

local varDataHandler is persist:handlerFor("varData", {return persist:varData.}, {parameter data. set persist:varData to data.}).
varDataHandler:readFromDisk().