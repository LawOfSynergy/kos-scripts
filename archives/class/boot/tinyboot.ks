@lazyGlobal off.

// ensure all systems ready
wait until ship:unpacked.

//open the terminal so I don't have to do it manually
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
set terminal:height to 80.

//give this volume a name
set core:volume:name to "probe".

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
    local class is ship:partstaggedpattern("class:")[0]:tag:split(":")[1].//load from tag on core

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
    compile "/class/boot/includes/console.ks".
    compile "/class/boot/includes/comms.ks".
    switch to core:volume.

    reqDirCheck().
    copyPath("0:/class/boot/includes/fs.ksm", "1:/includes/fs.ksm").
    copyPath("0:/class/boot/includes/console.ksm", "1:/includes/console.ksm").
    copyPath("0:/class/boot/includes/comms.ksm", "1:/includes/comms.ksm").
    require(list("fs", "console", "comms")).

    // all remaining modules and boot logic must be supplied/loaded by the class
    loadClass(). 
}

// run what dependencies we have stored
initModules().

// ensure required directories exist
reqDirCheck().

// initialize commlink status
comms:checkLink().

console:info("System boot complete").