//////////////////
// Initialize Console (logging)
//////////////////

// optional dependency on fs
// optional dependency on comms

local consoleModule is lex().

set consoleModule:level to lex().

local function addLogLevel {
    parameter name, value.

    local level is lex().
    set level:name to name.
    set level:value to value.
    set level:logAt to {
        parameter logger, text, toConsole is logger.toConsole.
        local writer is logger:factory:get().
        writer(text, level, logger:level, toConsole AND writer <> consoleModule:printWriter). //prevent double-printing
    }.

    consoleModule:level:add(name, level).
}

addLogLevel("NONE", -1).
addLogLevel("ERROR", 0).
addLogLevel("WARN", 1).
addLogLevel("INFO", 2).
addLogLevel("DEBUG", 3).

set consoleModule:unboundWriter to {
    parameter writeDelegate.
    parameter text.
    parameter level.
    parameter loggerLevel.
    parameter toConsole is true.

    //filter out messages below our current display threshold
    if level:value > loggerLevel:value {
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

set consoleModule:conditionalFactory to {
    parameter defaultWriter is consoleModule:printWriter.

    local wrapper is lex().
    set wrapper:factories to list().
    set wrapper:prepend to {
        parameter condition, factory.

        local fragment is lex().
        set fragment:condition to condition.
        set fragment:factory to factory.
        wrapper:factories:insert(0, fragment).
    }.
    set wrapper:get to {
        for fragment in wrapper:factories {
            if fragment:condition() return fragment:factory().
        }
        return defaultWriter.
    }.

    return wrapper.
}.

set consoleModule:factoryFor to {
    parameter writer.

    local wrapper is lex().
    set wrapper:get to {
        return writer.
    }.
    return wrapper.
}.

set consoleModule:printWriter to consoleModule:unboundWriter@:bind(print@).
set consoleModule:localWriter to "".
set consoleModule:commWriter to "".

set consoleModule:defaultFactory to consoleModule:conditionalFactory(consoleModule:printWriter).
consoleModule:defaultFactory:prepend({return defined fs.}, {
    if consoleModule:localWriter = "" set consoleModule:localWriter to consoleModule:unboundWriter:bind(fs:write@).
    return consoleModule:localWriter.
}).
consoleModule:defaultFactory:prepend({return defined comms.}, {
    if consoleModule:commWriter = "" set consoleModule:commWriter to consoleModule:unboundWriter:bind(comms:stashmit@).
    return consoleModule:commWriter.
}).

set consoleModule:logger to {
    parameter level is consoleModule:level:info, toConsole is true, writerFactory is consoleModule:defaultFactory.

    local logger is lex().
    set logger:level to level.
    set logger:factory to writerFactory.
    set logger:toConsole to toConsole.

    for loglevel in consoleModule:level:values {
        if(logLevel <> consoleModule:level:none) {
            set logger[loglevel:name] to loglevel:logAt:bind(logger).
        }
    }

    return logger.
}.

global console is consoleModule.
register("console", console, {return defined console.}).