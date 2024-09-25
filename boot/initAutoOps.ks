@lazyGlobal off.

print "Loaded, packed".

// ensure all systems ready
wait until ship:unpacked.

//open the terminal so I don't have to do it manually
print "loaded, unpacked".
CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").

//give this volume a name
set core:volume:name to "core".

local link is ship:controlpart:getmodule("modulecommand").
local signal is link:getfield("comm signal"). 

until false {
    set signal to link:getField("comm signal").

    print "looking for adequate signal. currently: " + signal.
    
    if signal <> "0.00" {
        //newly compile boot files
        local baseRoot is "/autoOps/class/boot/".
        local bootfiles is list("cmd/boot", "cmd/module-utils", "include/fs").

        //compile, copy, load, and init boot files
        switch to archive.
        for file in bootfiles {
            compile baseRoot + file.
            copyPath("0:" + baseRoot + file, "1:/" + file).
        }
        switch to core:volume.

        runOncePath("/cmd/module-utils").
        require("fs").
        set core:bootfilename to "/cmd/boot.ksm".

        //pull all class includes and cmd scripts required for full boot, and inits all modules
        fs:loadClass("boot").

        //init vessel profile and launch no.
        local baseName is ship:name.
        local vesselPath is "/autoOps/vessel/" + baseName.
        local countPath is vesselPath + "/count".
        local profilePath is vesselPath + "/profile".

        local count is 1.
        if(archive:files:haskey(countPath)) {
            set count to archive:open(countPath):readAll():toNumber(1) + 1.
            archive:delete(countPath).
        }
        archive:create(countPath).
        archive:open(countPath):write(count).

        if(archive:files:HASKEY(profilePath)){
            for class in archive:open(profilePath):readAll():split(",") {
                fs:loadClass(class).
            }
        }

        writeJson(core:volume:name, lex("class", ship:name, "number", count)).

        set ship:name to baseName + " " + count.

        //execute main boot file
        wait 0.1.
        reboot.
    }

    wait 0.1.
}