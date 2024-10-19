@lazyGlobal off.

//////////////////
// Initialize Console (logging)
//////////////////

// optional dependency on fs
// optional dependency on comms

local module is lex().

set module:LF to char(10). //line feed, unix-style line endings
set module:CR to char(13). //carriage return
set module:CRLF to "" + module:CR + module:LF. //cr + lf for windows style line endings
set module:NL to module:CRLF. //default to windows style line endings.

set module:fmtStr to "[%t][%s] %s".
set module:defaultLogFile to lex("path", "/data/log", "log").

set module:loggers to lex().

set module:level to lex().

local function addLogLevel {
    parameter name, value.

    local level is lex().
    set level:name to name.
    set level:value to value.
    set level:logAt to {
        parameter logger, text, toConsole is logger:toConsole.
        local writer is logger:factory:get().
        write(logger, level:value, text, toConsole, writer). 
    }.
    set level:fmtLogAt to {
        parameter logger, text.
        local writer is logger:factory:get().

        local result is "".
        local s is text.
        local i is 0.
        local param is "undefined".
        until i >= s:length {
            if consumeParam(s, i) {
                parameter p.
                set param to p.
            }
            local sub is substitute(s, i, param).
            set result to result + sub:value.
            set i to i + sub:inc.
        }
        parameter toConsole is logger:toConsole.

        write(logger, level:value, result, toConsole, writer). 
    }.

    module:level:add(name, level).
}

addLogLevel("NONE", -1).
addLogLevel("ERROR", 0).
addLogLevel("WARN", 1).
addLogLevel("INFO", 2).
addLogLevel("DEBUG", 3).

local function consumeParam {
    parameter s, i.

    return i < s:length-1 and s[i] = "%" and s[i+1] = "s".
}

local function substitute {
    parameter s, i, val is "undefined".

    local result is lex().

    if i < s:length-1 and s[i] = "%" {
        local next is s[i+1].
        if next = "%" { // %% -> %
            set result:value to "%".
            set result:inc to 2.
        } else if next = "s" { //%s -> parameter[index]:toString()
            set result:value to val.
            set result:inc to 2.
        } else if next = "n" { //%n -> new line
            set result:value to module:NL.
            set result:inc to 2.
        } else if next = "t" { //%t -> hh:mm:ss.MMM
            local hours to time:hour.
            local minutes to time:minute.
            local seconds to time:second.
            local mseconds to round(time:seconds - floor(time:seconds), 2) * 100.
            if hours < 10 set hours to "0" + hours.
            if minutes < 10 set minutes to "0" + minutes.
            if seconds < 10 set seconds to "0" + seconds.
            if mseconds < 10 set mseconds to "0" + mseconds.
            set result:value to hours + ":" + minutes + ":" + seconds + "." + mseconds.
            set result:inc to 2.
        } else { // default to just %
            print "Warning, encounted '%' that is not part of a valid escape sequence, treating as literal. string: " + s.
            set result:value to "%".
            set result:inc to 1.
        }
    } else {
        set result:value to s[i].
        set result:inc to 1.
    }

    return result.
}

local function canonizeNL {
    parameter s, i.
    
    local result is lex().

    if i < s:length-1 and ((s[i] = module:CR and s[i+1] = module:LF) or (s[i] = module:LF and s[i+1] = module:CR)) {
            set result:value to module:NL.
            set result:inc to 2.
    } else if s[i] = module:CR or s[i] = module:LF {
        set result:value to module:NL.
        set result:inc to 1.
    } else {
        set result:value to s[i].
        set result:inc to 1.
    }

    return result.
}

local function canonize {
    parameter s.

    local result is "".
    local i is 0.
    until i >= s:length {
        local sub is canonizeNL(s, i).
        set result to result + sub:value.
        set i to i + sub:inc.
    }
    return result.
}

set module:fmtUtils to lex().
set module:fmtUtils:consumeParam to consumeParam@.
set module:fmtUtils:substitute to substitute@.
set module:fmtUtils:canonize to canonize@.

local function write {
    parameter logger, level, text, toConsole, delegate.

    //filter out messages below our current display threshold
    if level:value > logger:level:value {
        return.
    }

    local fmttedText is module:fmt(logger:fmtStr, level:name, text).

    // print to console if requested
    if toConsole and delegate <> module:printWriter print fmttedText. //prevent double-printing

    delegate(logger, fmttedText).
}.

set module:printWriter to {
    parameter logger, text.
    print text.
}.

set module:fsWriter to {
    parameter logger, text.
    if defined fs {
        fs:write(text, logger:logFile:path, logger:logFile:ext, core:volume).
    }
}.

set module:commWriter to {
    parameter logger, text.

    if defined comms {
        comms:stashmit(text, logger:logFile:path, logger:logFile:ext).
    }
}.

set module:conditionalFactory to {
    parameter defaultWriter is module:printWriter.

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
            if fragment:condition() {
                if not fragment:hassuffix("cached") set fragment:cached to fragment:factory().

                return fragment:cached.
            }
        }
        return defaultWriter.
    }.

    return wrapper.
}.

set module:factoryFor to {
    parameter writer.

    local wrapper is lex().
    set wrapper:get to {
        return writer.
    }.
    return wrapper.
}.

set module:defaultFactory to module:conditionalFactory(module:printWriter).
module:defaultFactory:prepend({return defined fs.}, {return module:fsWriter.}).
module:defaultFactory:prepend({return defined comms.}, {return module:commWriter.}).

set module:logger to {
    parameter name, level is module:level:info, toConsole is true, logFile is module:defaultLogFile, writerFactory is module:defaultFactory.
    
    local logger is lex().

    set logger:name to name.
    set logger:level to level.
    set logger:toConsole to toConsole.
    set logger:logFile to logFile.
    set logger:factory to writerFactory.

    for logLevel in module:level:values {
        if(logLevel <> module:level:none) {
            set logger[logLevel:name] to logLevel:logAt:bind(logger).
            set logger[logLevel:name + "f"] to logLevel:fmtLogAt:bind(logger).
        }
    }

    set module["loggers"][name] to logger.

    return logger.
}.

set module:fmt to {
    parameter s.

    local result is "".
    local i is 0.
    local param is "undefined".
    until i >= s:length {
        if consumeParam(s, i) {
            parameter p.
            set param to p.
        }
        local sub is substitute(s, i, param).
        set result to result + sub:value.
        set i to i + sub:inc.
    }
    return result.
}.

global console is module.
register("console", console, {return defined console.}).