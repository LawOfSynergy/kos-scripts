@lazyGlobal off.

print "Loaded, packed".

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

//init vessel profile and launch no.
local baseName is ship:name.
local vesselPath is "/autoOps/vessel/" + baseName.
local countPath is vesselPath + "/count".
local profilePath is vesselPath + "/profile".

local count is 1.
if archive:exists(countPath) {
    print countPath + " already exists. reading then deleting".
    set count to archive:open(countPath):readAll():string:toNumber(1) + 1.
    archive:delete(countPath).
}
print "creating " + countPath + " and writing " + count.
archive:create(countPath).
archive:open(countPath):write("" + count).

writeJson(core:volume:name, lex("class", ship:name, "number", count)).

// init boot namespace
global boot is lex().

set boot:profile to ship:name.
set boot:launchNum to count.
set ship:name to baseName + " " + count.

//////////////////
// CPU Boot Info
//////////////////
function printSysInfo {
    parameter args is list().

    print("kOS processor version " + CORE:VERSION).
    print("Running on " + CORE:ELEMENT:NAME).
    print(CORE:VOLUME:CAPACITY + " total space").
    print(CORE:VOLUME:FREESPACE + " bytes free").
    print("Vessel: " + boot:profile + " " + boot:launchNum).
}

//////////////////
// Boot Utility Functions
//////////////////
local function toPathString {
    parameter p.

    local result is "".
    for segment in p:segments {
        set result to result + "/" + segment.
    }
    return result.
}.

local function walk {
    parameter vol.
    parameter start.
    parameter callback.

    if start:isType("VolumeItem") set start to path(start).
    if start:isType("Path") set start to toPathString(start).

    local dir is vol:open(start).
    callback(dir).

    if dir:isType("Boolean") return.

    for descriptor in dir:lex:values {
        if not descriptor:isFile {
            walk(vol, toPathString(path(descriptor)), callback).
        } else {
            callback(descriptor).
        }
    }
}

local function info {
    parameter data.
    print toPathString(path(data)).
}

local function printTree {
    parameter vol, start.
    walk(vol, start, info@).
}.

local function compiler {
    parameter start, dst.

    local compileFile is {
        parameter descriptor.
        if(not descriptor:isType("VolumeItem")) {
            print "expected VolumeItem, received: " + descriptor.
            return.
        }
        if descriptor:extension = "ks" {
            switch to archive.
            compile toPathString(path(descriptor)).
            switch to core:volume.
            copyPath("0:" + toPathString(path(descriptor):changeExtension("ksm")), dst).
        }
    }.

    walk(archive, start, compileFile).
}

//////////////////
// POST
//////////////////

local baseRoot is "/autoOps/class".

core:volume:createdir("/cmd").
core:volume:createdir("/include").
core:volume:createdir("/test").

compiler(baseRoot + "/boot/cmd", "1:/cmd").
compiler(baseRoot + "/boot/include", "1:/include").
compiler(baseRoot + "/boot/test", "1:/test").
compiler(baseRoot + "/bootTest/cmd", "1:/cmd").
compiler(baseRoot + "/bootTest/include", "1:/include").
compiler(baseRoot + "/bootTest/test", "1:/test").

printTree(core:volume, "/").

runOncePath("/cmd/module-utils").
runPath("/include/test").
walk(core:volume, "/test", {parameter f. if f:isFile runOncePath(f).}).

print "Beginning POST".

//Power On Self Test (POST)
local post is true.
test:start().
for module in test:instances {
    if module:status:label <> test:labels:pass post off.
}

if post {
    print "POST Succesful, cleaning up resources".
    //clear all test state
    unset test.
    unset console.
    unset fs.
    unset comms.
    unset persist.
    unset ops.
    core:volume:delete("/test").

    print "Beginning remaining unit testing".
    validateModules().
    fs:reqDirCheck().

    local logger is console:logger("boot").
    set boot:logger to logger.

    if(archive:exists(profilePath)){
        for class in archive:open(profilePath):readAll():string:split(",") {
            print "Loading class: " + class.
            fs:loadClass(class, true).
        }
    }

    printTree(core:volume, "/").

    //execute all tests in vessel profile
    walk(core:volume, "/test", {parameter f. if f:isFile runOncePath(f).}).
    test:start().
}