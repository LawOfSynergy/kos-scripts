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

/////////////////////////
// Begin system boot load
/////////////////////////

//load cached modules
runOncePath("/cmd/module-utils").
require(list("console", "fs")).
local logger is console:logger("boot").
set boot:logger to logger.
fs:visit(core:volume, "/include", fs:isCompiled, runOncePath@).

// set up hibernation utilities
set boot:canHibernate to false.
if ship:partstagged("hibernationCtrl"):length {
  set boot:hibernateCtrl to ship:partstagged("hibernationCtrl")[0]:getmodule("Timer").
  set boot:canHibernate to true.
  if ship:partstagged(core:tag)[0]:getmodule("ModuleGenerator"):hasevent("Activate CPU") {
    ship:partstagged(core:tag)[0]:getmodule("ModuleGenerator"):doevent("Activate CPU").
  }
}

set boot:noWakeFile to "".

set boot:hibernate to {
  parameter wakefile is boot:noWakeFile.
  parameter duration is 0.
  parameter comms is false.

  // only proceed if hibernation is available
  if boot:canHibernate {

    // set comms as requested
    if not comms comms:setCommStatus("retract antenna").

    // define the file that will run once after coming out of hibernation
    if wakefile:length persist:set("wakeFile", wakeFile).

    // save all the current volatile data
    persist:write().

    // set and activate the timer?
    if duration > 0 and duration <= 120 {
      if boot:hibernateCtrl:hasevent("Use Seconds") boot:hibernateCtrl:doevent("Use Seconds").
      boot:hibernateCtrl:setfield("Seconds", duration).
      boot:hibernateCtrl:doevent("Start Countdown").
    } else if duration > 0 {
      if boot:hibernateCtrl:hasevent("Use Minutes") boot:hibernateCtrl:doevent("Use Minutes").
      boot:hibernateCtrl:setfield("Minutes", floor(duration/60)).
      boot:hibernateCtrl:doevent("Start Countdown").
    }
    
    // switch off the cpu. Nite nite!
    logger:info("Activating hibernation").
    ship:partstagged(core:tag)[0]:getmodule("ModuleGenerator"):doevent("Hibernate CPU").
    ship:partstagged(core:tag)[0]:getmodule("KOSProcessor"):doevent("Toggle Power").
  } else logger:warn("Hibernation is not supported on this vessel!").
}.

/////////////////////////
// Begin system boot ops
/////////////////////////

clearscreen.
printSysInfo().

local link is ship:controlpart:getmodule("modulecommand").
local signal is link:getfield("comm signal"). 
if signal <> "0.00" {
    // check for a new bootscript
    if archive:exists(fs:ship:boot) {
        logger:info("new system boot file received").
        movepath("0:" + fs:ship:boot, "/boot/boot.ksm").
        set core:bootfilename to "/boot/boot.ksm".
        wait 1.
        reboot.
    }

    // reload the dependencies if any were updated
    if archive:exists(fs:ship:reloadFlag) {
        logger:info("request to reload ship profile received").
        archive:delete(fs:ship:reloadFlag).
        core:volume:delete("/include").
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
persist:get("startupUT"):add(time:seconds).
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