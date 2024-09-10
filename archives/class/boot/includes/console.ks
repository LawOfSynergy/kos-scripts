//////////////////
// Initialize Console (logging)
//////////////////

require("fs").

global console is lex().

set console:level to lex().
set console:level:error to lex().
set console:level:error:name to "ERROR".
set console:level:error:value to 0.
set console:level:warning to lex().
set console:level:warning:name to "WARN".
set console:level:warning:value to 1.
set console:level:info to lex().
set console:level:info:name to "INFO".
set console:level:info:value to 2.
set console:level:debug to lex().
set console:level:debug:name to "DEBUG".
set console:level:debug:value to 3.
set console:level:current to console:level:info.

set console:unboundLogger to {
    parameter writeDelegate.
    parameter text.
    parameter level.
    parameter toConsole is true.

    //filter out messages below our current display threshold
    if level:value > console:level:current:value {
        return.
    }

    // print to console if requested
    if toConsole print text.

    // format the timestamp
    local hours to time:hour.
    local minutes to time:minute.
    local seconds to time:second.
    local mseconds to round(time:seconds - floor(time:seconds), 2) * 100.
    if hours < 10 set hours to "0" + hours.
    if minutes < 10 set minutes to "0" + minutes.
    if seconds < 10 set seconds to "0" + seconds.
    if mseconds < 10 set mseconds to "0" + mseconds.

    // log the new data
    writeDelegate("[" + hours + ":" + minutes + ":" + seconds + "." + mseconds + "][" + level:name + "] " + text).
}.

set console:error to {
    parameter text, toConsole is true. 
    getLogger()(text, console:level:error, toConsole).
}.
set console:warn to {
    parameter text, toConsole is true. 
    getLogger()(text, console:level:warning, toConsole).
}.
set console:info to {
    parameter text, toConsole is true. 
    getLogger()(text, console:level:info, toConsole).
}.
set console:debug to {
    parameter text, toConsole is true. 
    getLogger()(text, console:level:debug, toConsole).
}.

local localLogger is console:unboundLogger@:bind(fs:write@).
local commLogger is "".

local function getLogger {
    if defined comms {
        if commLogger = "" set commLogger to console:unboundLogger@:bind(comms:stashmit@).
        return commLogger.
    }
    return localLogger.
}

modules:add("console", console).