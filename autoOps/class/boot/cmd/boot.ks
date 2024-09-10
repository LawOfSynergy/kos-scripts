@lazyGlobal off.

// ensure all systems ready
wait until ship:unpacked.

//open the terminal so I don't have to do it manually
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
set terminal:height to 80.

//give this volume a name
set core:volume:name to "core".

//////////////////
// Boot containers and constants
//////////////////

// init boot namespace
global boot is lex().
modules:add("boot", boot).

local profile is readJson("/boot/profile").
set boot:profile to profile["class"].
set boot:launchNum to profile["number"].

//////////////////
// CPU Boot Info
//////////////////
function printSysInfo {
    parameter args is list().

    logger:info("kOS processor version " + CORE:VERSION).
    logger:info("Running on " + CORE:ELEMENT:NAME).
    logger:info(CORE:VOLUME:CAPACITY + " total space").
    logger:info(CORE:VOLUME:FREESPACE + " bytes free").
    logger:info("Vessel: " + boot:profile + " " + boot:launchNum).
}

//////////////////
// Boot Utility Functions
//////////////////

global function initModules {
    fs:visit(core:volume, "/includes", fs:isCompiled@, {parameter f. runOncePath(f).}).
}.

global function require {
    parameter module.

    if module:isType("Enumerable") {
        for m in module {
            runOncePath("/includes/" + m).
        }
    } else {
        runOncePath("/includes/" + module).
    }
}

/////////////////////////
// Begin system boot ops
/////////////////////////

//load cached modules
require(list("console", "fs")).
local logger is console:logger().
set boot:logger to logger.
initModules().

clearscreen.
printSysInfo().

local link is ship:controlpart:getmodule("modulecommand").
local signal is link:getfield("comm signal"). 
if signal <> "0.00" {
    // check for a new bootscript
    if archive:exists(fs:ship:boot) {
        logger:info( "new system boot file received").
        movepath("0:" + fs:ship:boot, "/boot/boot.ksm").
        set core:bootfilename to "/boot/boot.ksm".
        wait 1.
        reboot.
    }

    // reload the dependencies if any were updated
    if archive:exists(fs:ship:reloadFlag) {
        logger:info("request to reload ship profile received").
        archive:delete(fs:ship:reloadFlag).
        core:volume:delete("/includes").
        fs:loadClass("boot").
        if(archive:exists(fs:ksc:profile:local:class)){
            for class in archive:open(fs:ksc:profile:local:class):readAll():split(",") {
                fs:loadClass(class).
            }
        }
        wait 1.
        reboot.
    }
}

// ensure required directories exist
fs:reqDirCheck().

// initialize commlink status
comms:checkLink().

// load any persistent data and operations
persist:read().

// initial persistent variable definitions
persist:declare("startupUT", list()).
persist:get("startupUT"):append(time:seconds).
persist:declare("lastDay", -1).
persist:declare("commRanges", lexicon()).

// find and store all comm ranges if we haven't already
if not persist:get("commRanges"):length {
    for comm in comms:links:values {

        local rangeInfo is 0.
        local rangeScale is 0.

        // store the antenna range in meters
        if comm:hasmodule("moduledatatransmitter") set rangeInfo to comm:getmodule("moduledatatransmitter"):getfield("Antenna Rating"):split(" ")[0].
        if comm:hasmodule("moduledatatransmitterfeedeable") set rangeInfo to comm:getmodule("moduledatatransmitterfeedeable"):getfield("Antenna Rating"):split(" ")[0].
        if rangeInfo:contains("k") set rangeScale to 1000.
        if rangeInfo:contains("M") set rangeScale to 1000000.
        if rangeInfo:contains("G") set rangeScale to 1000000000.
        local commRange is (rangeInfo:substring(0, (rangeInfo:length-1)):tonumber())*rangeScale.

        // list the comm unit
        persist:get("commRanges"):add(comm, commRange).
    } 
}

// date stamp the log if this is a different day then update the day
if persist:get("lastDay") <> time:day logger:info("[" + time:calendar + "]").
persist:set("lastDay", time:day).

// add system opcodes
ops:opCodeFor("sysinfo", printSysInfo@).
ops:opCodeFor("tree", { //more like forest, since it can take multiple dirs
    parameter args.

    if args:length > 2 {
        for path in args:sublist(1, args:length - 1) {
            fs:printTree(core:volume, path).
        }
    } else {
        fs:printTree(core:volume, "/").
    }
}).

logger:info("System boot complete").


/////////////////
// Begin ops run
/////////////////

// if we came out of hibernation, call the file and delete the variable
if persist:get("wakeFile") {
    runOncePath("/cmd/" + persist:get("wakeFile")).
    persist:set("wakeFile").
}
ops:start().