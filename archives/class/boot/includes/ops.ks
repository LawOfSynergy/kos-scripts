@lazyGlobal off.

//init dependencies, if they haven't already been
require(list("console", "persist", "comms")).

global ops is lex().

set ops:RELATIVE_TIME to true.
set ops:ABSOLUTE_TIME to false.
set ops:PERSIST_Y to true.
set ops:PERSIST_N to false.

set ops:MILLIS to 1.
set ops:SECOND to 1000.
set ops:MINUTE to ops:SECOND * 60.
set ops:HOUR to ops:MINUTE*60.
set ops:DAY to ops:HOUR*24.

set ops:opsFilePath to boot:shipDir + "/" + ship:name + ".ops".

//init persistent state
set ops:operations to lexicon().
local sleepTimers to lexicon().
local operationsHandler is persist:handlerFor("opsData", {return ops:operations.}, {parameter data. set ops:operations to data.}).
local timerHandler is persist:handlerFor("timerData", {return sleepTimers.}, {parameter data. set sleepTimers to data.}).
operationsHandler:readFromDisk().
timerHandler:readFromDisk().

//init module
local opCodes is list().

//creates and registers an operation that can be executed through a .ops file
//delegate should return true if this script needs to abort
set ops:opCodeFor to {
    parameter command, delegate.

    local result is lex(
        "command", command,
        "exec", delegate
    ).

    opCodes:add(result).
    return result.
}.

set ops:start to {
    local printOpsFileMsg is true.

    until false {
        //things to do if there is a connection
        if comms:checkLink() {
            local opsfile is ops:opsFilePath.

            console:debug("Beginning ops loop").
            //check if a new ops file is waiting to be executed
            if printOpsFileMsg {
                console:info("Looking in archive for: " + opsfile).
                set printOpsFileMsg to false.
            }
            if archive:exists(opsfile) {
                set printOpsFileMsg to true.

                console:debug("Found ops file. Begining read of " + opsfile).

                //read each line of the file and carry out the command
                local opLine is archive:open(opsfile):readall:iterator.
                local stop is false.
                until not opLine:next or stop {
                    local cmd is opLine:value:split(":").

                    local unknown is true.

                    for opcode in opCodes {
                        if cmd[0] = opcode:command {
                            set unknown to false.
                            set stop to opcode:exec(cmd).
                            break.
                        }
                    }
                    if unknown console:error("Unknown command: " + cmd[0]).
                }
                archive:delete(opsfile).
            }

            // if there is any data stored on the local drive, we need to send that to KSC
            // loop through all the data and either copy or append to what is on the archiveset
            console:debug("checking for files to transfer").
            if comms:transferFiles() console:info("Data dump to KSC complete").
        }

        executeTimers().

        //run stored ops files
        fs:visit(core:volume, "/ops", fs:isCompiled@, {parameter f. runPath(f).}).

        // run any existing ops
        if ops:operations:length {
            for op in ops:operations:values op().
        }

        wait 0.001.
    }
}.

local function executeTimers {
    // are there any sleep timers to check?
    local timerKill is list().
    if sleepTimers:length {

        // loop through all active timers
        for timer in sleepTimers:values {

            // decide if the timer has expired using time from when it was started (relative)
            // or by the current time exceeding the specified alarm time
            if 
            (timer:relative and time:seconds - timer:startsec >= timer:naptime)
            or
            (not timer:relative and time:seconds >= timer:naptime) {

                // if the timer is up, decide how to proceed with the callback based on timer persistence
                if timer:persist {

                    // this is a function called multiple times, so call it directly then reset the timer
                    timer:callback().
                    set timer:startsec to floor(time:seconds).
                } else {

                    // this is a function called once, so add it to the ops queue and delete the timer        
                    set ops["operations"][timer:name] to timer:callback.
                    timerKill:add(timer["name"]).
                }
            }
        }
    }
    for deadID in timerKill sleepTimers:remove(deadID).
}


// create wait timers without pausing code operation
set ops:sleep to {
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
  
  set sleepTimers[name] to timer.
}.

// file opcodes

// load a command file or folder of files from KSC to the onboard disk
ops:opCodeFor("load", {
    parameter cmd.
    copyPath("0:" + boot:shipDir + cmd[1], "/cmd/" + cmd[2]).
}).

// run a stored file. files stored in /ops are automatically run on boot
ops:opCodeFor("run", {
    parameter cmd.

    // confirm that this is an actual file. If it is not, ignore all further run commands
    // this prevents a code crash if mis-loaded file had dependencies for future files
    if not core:volume:exists("/cmd/" + cmd[1]) {
        console:error("Could not find " + cmd[1] + " - further run commands ignored").
        return true.
    }

    local opTime is time:seconds.
    runpath("/cmd/" + cmd[1]).
    console:info("Instruction run complete for " + cmd[1]  + " (" + round(time:seconds - opTime,2) + "ms)").
}).

// run a file that we only want to execute once from the archive and not store to run again
// NOTE: calling the same file after making changes on the archive during the same run period will not pick up changes!
ops:opCodeFor("exe", {
    parameter cmd.
    
    if archive:exists(cmd[1]) {
        local opTime is time:seconds.
        runpath("0:" + cmd[1]).
        console:info("Instruction execution complete for " + cmd[1]  + " (" + round(time:seconds - opTime,2) + "ms)").
    } else {
        console:error("Could not find " + cmd[1]).
        return true.
    }
}).

// delete a file or directory
ops:opCodeFor("del", {
    parameter cmd.
    
    if core:volume:exists("/" + cmd[1]) {
        core:volume:delete("/" + cmd[1]).
        console:info("Instruction deletion complete for /" + cmd[1]).
    } else {
        console:warn("Could not find file or directory: /" + cmd[1]).
    }

    // do not let the deletion of required directories remain
    reqDirCheck().
}).

// print to console (not log) all files in a directory
ops:opCodeFor("list", {
    parameter cmd.
    
    local vol is choose core:volume if cmd:length < 3 else volume(cmd[2]).
    
    fs:printTree(vol, cmd[1]).
}).

// session opcodes

// reboot the cpu
ops:opCodeFor("reboot", {
    parameter cmd.
    
    persist:write().
    archive:delete(ops:opsFilePath).
    reboot.
}).

// end this session with the probe
ops:opCodeFor("disconnect", {
    parameter cmd.
    
    persist:write().
    print "Connection closed. Please return to Tracking Station or Space Center".
    archive:delete(ops:opsFilePath).
    when kuniverse:canquicksave then kuniverse:quicksaveto(ship:name + " - Disconnect @ " + time:calendar + " [" + time:clock + "]").
    wait 0.1.
    kuniverse:pause().
}).

ops:opCodeFor("class", {
    parameter cmd.
    
    local previousClass is persist:get("class").
    console:info("Registering class as: " + cmd[1] + "...").
    if (cmd[1] <> previousClass) {
        console:info("Successful").
        persist:set("class", cmd[1]).
        persist:write().
        reboot.
    } else {
        console:info("Failed. New class is same as previous class: " + previousClass).
    }
}).

ops:opCodeFor("set", {
    parameter cmd.

    persist:set(cmd[1], cmd[2]).
}).

ops:opCodeFor("declare", {
    parameter cmd.

    persist:declare(cmd[1], cmd[2]).
}).