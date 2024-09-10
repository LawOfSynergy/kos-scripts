@lazyGlobal off.

print "Loaded, packed".

// ensure all systems ready
wait until ship:unpacked.

//////////////////
// Boot containers and constants
//////////////////

//init vessel profile and launch no.
local baseName is ship:name.
local vesselPath is "/autoOps/vessel/" + baseName.
local countPath is vesselPath + "/count".
local profilePath is vesselPath + "/profile".

local count is 1.
if(archive:files:haskey(countPath)) {
    set count to archive:open(countPath):readAll():toNumber(1).
    archive:delete(countPath).
}
archive:create(countPath).
archive:open(countPath):write(count).

writeJson(core:volume:name, lex("class", ship:name, "number", count)).

// init boot namespace
global boot is lex().
modules:add("boot", boot).

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

    for descriptor in dir:lex:values {
        callback(descriptor).
        if not descriptor:isFile {
            walk(vol, toPathString(path(descriptor)), callback).
        }
    }
}

local function printTree {
    parameter vol, start.
    walk(vol, start, print@).
}.

local function compiler {
    parameter start, dst.

    local compileFile is {
        parameter descriptor.
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

local baseRoot is "0:/autoOps/class".

compiler(baseRoot + "/boot/cmd", "1:/cmd").
compiler(baseRoot + "/boot/include", "1:/include").
compiler(baseRoot + "/boot/test", "1:/test").
compiler(baseRoot + "/bootTest/cmd", "1:/cmd").
compiler(baseRoot + "/bootTest/include", "1:/include").
compiler(baseRoot + "/bootTest/test", "1:/test").

local function initModule {
    parameter descriptor.
    runPath("1:" + toPathString(path(descriptor))).
}

runPath("1:/include/test.ksm").
walk(core:volume, "/test", initModule@).

//Power On Self Test (POST)
local post is true.
test:start().
for module in test:instances {
    if module:status:label <> test:labels:pass post off.
}

if post {
    //clear all test state
    unset test.
    unset console.
    unset fs.
    unset comms.
    unset persist.
    unset ops.
    core:volume:delete("/test").
    
    //reset the test framework
    runPath("1:/include/test.ksm").
    walk(core:volume, "/include", initModule@).

    local logger is console:logger().
    set boot:logger to logger.

    if(archive:files:HASKEY(profilePath)){
        for class in archive:open(profilePath):readAll():split(",") {
            fs:loadClass(class, true).
        }
    }

    //execute all tests in vessel profile
    walk(core:volume, "/test", initModule@).
    test:start().
}