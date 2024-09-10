@lazyGlobal off.

// ensure all systems ready
wait until ship:unpacked.

//open the terminal so I don't have to do it manually
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
set terminal:height to 80.

//give this volume a name
set core:volume:name to "core".

//////////////////
// CPU Boot Info
//////////////////
function printSysInfo {
    parameter args is list().

    local output is "".

    if defined console {
        set output to console:info@.
    } else {
        set output to print@.
    }
    output("kOS processor version " + CORE:VERSION).
    output("Running on " + CORE:ELEMENT:NAME).
    output(CORE:VOLUME:CAPACITY + " total space").
    output(CORE:VOLUME:FREESPACE + " bytes free").
}

clearscreen.
printSysInfo().

// init module container
global modules is lex().

// init boot namespace
global boot is lex().
modules:add("boot", boot).

set boot:shipDir to "/vessel/" + ship:name.
set boot:reqDirs to list("/data", "/mem", "/ops", "/cmd", "/includes").


//////////////////
// Boot Utility Functions
//////////////////

function initModules {
    fs:visit(core:volume, "/includes", fs:isCompiled@, {parameter f. runOncePath(f).}).
}.

function require {
    parameter module.

    if module:isType("Enumerable") {
        for m in module {
            runOncePath("/includes/" + m).
        }
    } else {
        runOncePath("/includes/" + module).
    }
}

function reqDirCheck {
    for dir in boot:reqDirs {
        if not core:volume:exists(dir) core:volume:createDir(dir).
    }
}

function loadClass {
    local class is persist:get("class").

    console:info("Loading specified class: " + class).

    reqDirCheck().

    if(not class) {
        console:warn("Class not specified").
        console:info("Skipping class includes...").
        console:info("Skipping class cmds...").
        return.
    }

    if(not archive:exists("/class/" + class + "/")) {
        console:warn("Class does not yet exist").
        console:info("Skipping class includes...").
        console:info("Skipping class cmds...").
        return.
    }

    local rootPath is "/class/" + class.
    //compile and copy includes
    fs:compile(archive, rootPath + "/includes").
    fs:copyDir(rootPath + "/includes", "/includes", fs:isCompiled@).

    //compile and copy commands
    fs:compile(archive, rootPath + "/cmd").
    fs:copyDir(rootPath + "/cmd", "/cmd", fs:isCompiled@).
}

/////////////////////////
// Begin system boot ops
/////////////////////////
local link is ship:controlpart:getmodule("modulecommand").
local signal is link:getfield("comm signal"). 
if signal <> "0.00" {
    // check for a new bootscript
    if archive:exists(boot:shipDir + "/boot.ksm") {
        print "new system boot file received".
        movepath("0:" + boot:shipDir + "/boot.ksm", "/boot/boot.ksm").
        wait 1.
        reboot.
    }

    // reload the dependencies in case any were updated
    if core:volume:exists("/includes") core:volume:delete("/includes").

    //compile, copy, and load Filesystem module
    switch to archive.
    compile "/class/boot/includes/fs.ks".
    switch to core:volume.

    reqDirCheck().
    copyPath("0:/class/boot/includes/fs.ksm", "1:/includes/fs.ksm").
    require("fs").

    //compile, copy, and load remaining boot modules
    fs:compile(archive, "/class/boot/includes").
    fs:copyDir("/class/boot/includes", "/includes", fs:isCompiled@).
    initModules().

    loadClass().
}

// run what dependencies we have stored
initModules().

// ensure required directories exist
reqDirCheck().

// initialize commlink status
comms:checkLink().

// load any persistent data and operations
persist:read().

// initial persistent variable definitions
persist:declare("startupUT", time:seconds).
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
if persist:get("lastDay") <> time:day comms:stashmit("[" + time:calendar + "]").
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

console:info("System boot complete").


/////////////////
// Begin ops run
/////////////////

// if we came out of hibernation, call the file and delete the variable
if persist:get("wakeFile") {
    runOncePath("/cmd/" + persist:get("wakeFile")).
    persist:set("wakeFile").
}
ops:start().