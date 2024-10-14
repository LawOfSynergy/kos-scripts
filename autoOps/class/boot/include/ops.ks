@lazyGlobal off.

require(list("console", "fs", "comms", "persist")).

local opsModule is lex().
local logger is console:logger("ops").
set opsModule:logger to logger.
set opsModule:userLogger to console:logger("user").

set opsModule:RELATIVE_TIME to true.
set opsModule:ABSOLUTE_TIME to false.
set opsModule:PERSIST_Y to true.
set opsModule:PERSIST_N to false.

set opsModule:MILLIS to 1.
set opsModule:SECOND to 1000.
set opsModule:MINUTE to opsModule:SECOND * 60.
set opsModule:HOUR to opsModule:MINUTE*60.
set opsModule:DAY to opsModule:HOUR*24.

set opsModule:opsFilePath to fs:ksc:ship:ops.

//init persistent state
set opsModule:operations to lexicon().
local opsH is persist:basicDataHandler(
    "task", true, lex(), 
    {return opsH:data.}, 
    {
        parameter opsData.
        set opsH:data to opsData.
        if opsData:hasSuffix("ctx") {
            set opsH:data:ctx to context(opsData:stepIndex).
        }
    }
).
set opsModule:opsHandler to opsH.

// not persistent
local timers is lex().

//init module
local opCodes is lex().

//creates and registers an operation that can be executed through a .ops file
set opsModule:opCodeFor to {
    parameter command, init, step.

    local result is lex(
        "command", command, 
        "init", init, //called prior to starting the task, or when resuming a task after reboot/hibernate. Delegates, timers, and other things that don't survive restarts should be set up here
        "step", step //called each tick. This should be a short running piece of work that will advance the task. Waits should not occur in this method. Instead, return and check again on the next tick.
    ).

    opCodes:add(command, result).
    return result.
}.

local function toOp {
    parameter args.

    local operation is lex("name", args[0], "args", args:sublist(1, args:length-1)).

    if not opsH:data:hassuffix("tasks") set opsH:data:tasks to list().

    opsH:data:tasks:add(operation).
}
set opsH:load to lex().
set opsModule:load to opsH:load.
set opsH:load:op to toOp@.

local function loadOps {
    parameter fileContents.

    for line in fileContents:split(console:NL) {
        toOp(line:split(":")).
    }
}
set opsH:load:ops to loadOps@.

local function loadOpsFile {
    parameter vol, pth.

    logger:info(console:fmt("Loading new ops file: '%s:%s'", vol:name, pth)).
    local opLine is vol:open(pth):readall:iterator.
    until not opLine:next() {
        toOp(opLine:value:split(":")).
    }
}
set opsH:load:file to loadOpsFile@.

set opsH:reset to {
    opsH:info("Clearing ops tasks").
    opsH:data:remove("tasks").
}.

local function context {
    parameter step is -1.
    local ctx is lex().
    set ctx:logger to opsModule:userLogger.
    set ctx:steps to opsH:data:tasks.
    set ctx:stepIndex to step.
    set ctx:step to ctx:steps[step].
    set ctx:args to ctx:steps[step]:args.
    set ctx:done to {
        if step = ctx:steps:length {
            opsH:data:remove("ctx").
            opsH:data:remove("tasks").
        }
        local newCtx is context(step+1).
        opCodes[newCtx:step:name]:init(newCtx).
        set opsH:data:ctx to newCtx.
    }.
    set ctx:abortStatus to false.
    set ctx:abort to {
        set ctx:abortStatus to true.
    }.
    set ctx:hibernateStatus to false.
    set ctx:prepareToHibernate to {
        parameter wakefile, duration is 0, comms is false.
        set ctx:hibernateStatus to true.
        set ctx:hibernateRequest to lex("wakefile", wakefile, "duration", duration, "comms", comms).
    }. 
}

local function connectToKSC {
    logger:debug("Checking link to ksc").
    if comms:checkLink() {
        logger:debug("Link to ksc established").
        logger:debug("Checking for new ops file at: " + fs:ksc:ship:ops:file).
        if archive:exists(fs:ksc:ship:ops:file) {
            
            opsH:reset().
            loadOpsFile(archive, fs:ksc:ship:ops:file).
            movePath("0:" + fs:ksc:ship:ops:file, "0:" +  fs:ksc:ship:ops:root + timestamp() + ".ops").
            context():done(). //initialize first step of the new ops file.
        }
        
        // if there is any data stored on the local drive, we need to send that to KSC
        // loop through all the data and either copy or append to what is on the archive
        logger:debug("checking for files to transfer").
        if comms:transferFiles() logger:info("Data dump to KSC complete").
    }
}

//example
//telemetry:start
//launchWindow:??
//launch:tgtAlt
//rndx:vesselName
//dock:vesselName:dockName
//telemetry:stop



set opsModule:start to {
    //if we are resuming an existing context
    if opsH:data:hassuffix("ctx") opCodes[opsH:data:ctx:step:name]:init(opsH:data:ctx).
    local exit is false.

    until exit {
        connectToKSC().
        if opsH:data:hassuffix("ctx") {
            logger:debug("stepping current operation: " + opsH:data:ctx:step:name).
            opCodes[opsH:data:ctx:step:name]:step(opsH:data:ctx).
        }
        executeTimers().
        set exit to opsH:data:ctx:abortStatus or opsH:data:ctx:hibernateStatus.
        wait 0.001.
    }
    logger:info("Exit condition detected, ops loop terminated").

    //TODO hibernate prep and execute
    //TODO abort followup?
}.


local function executeTimers {
    // are there any sleep timers to check?
    local timerKill is list().
    if timers:length {

        // loop through all active timers
        for timer in timers:values {

            // decide if the timer has expired using time from when it was started (relative)
            // or by the current time exceeding the specified alarm time
            if 
            (timer:relative and time:seconds - timer:startsec >= timer:naptime)
            or
            (not timer:relative and time:seconds >= timer:naptime) {
                timer:callback().
                if timer:persist {
                    //reset the timer
                    set timer:startsec to floor(time:seconds).
                } else {
                    //add to delete queue
                    timerKill:add(timer["name"]).
                }
            }
        }
    }
    //delete dead timers
    for deadID in timerKill timers:remove(deadID).
}


// create wait timers without pausing code operation
set opsModule:sleep to {
  parameter name.
  parameter callback.
  parameter napTime.
  parameter relative.
  parameter persist.

  local timer is lexicon(
    "persist", persist,
    "naptime", napTime,
    "relative", relative,
    "name", name,
    "callback", callback,
    "startsec", choose floor(time:seconds) if persist else time:seconds
  ).
  
  set timers[name] to timer.

  return timer. // return this object so perstence can be altered. This way timers can be allowed to lapse after some condition is met
}.


global ops is opsModule.
register("ops", ops, {return defined ops.}).