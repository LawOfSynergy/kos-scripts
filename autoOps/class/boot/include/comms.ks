@lazyGlobal off.

require(list("console", "fs")).

//////////////////
// Init Comms
//////////////////

local module is lex().

local logger is console:logger("comms").
set module:logger to logger.

set module:connected to false.
set module:blackout to false.

// get all comm parts on the ship
set module:cmdLink to ship:controlpart:getmodule("modulecommand").
set module:links to lex().
for part in ship:parts {
    if part:hasmodule("moduledatatransmitter") set module["links"][part:tag] to part.
    if part:hasmodule("moduledatatransmitterfeedeable") set module["links"][part:tag] to part.
}

set module:getSignal to {
    return module:cmdLink:getfield("comm signal").
}.

// are we connected?
set module:checkLink to {
    if module:getSignal() = "0.00" {
        if module:connected or module:blackout {
            set module:connected to false.
            set module:blackout to false.
            logger:info("KSC link lost").
        }
        return false.
    } else {
        if not module:connected and not module:blackout {
            set module:connected to true. 
            logger:info("KSC link acquired").
        }

        local signal is module:getSignal().
        // dunno where "NA" comes from, but loading out onto the pad it happens for split second or something
        if signal <> "1.00" and signal <> "NA" and not module:blackout {

            // if the signal has degraded more than 50% and we are in atmosphere, comm blackout is likely coming soon
            if signal < 50 and ship:altitude < 70000 {
                set module:connected to false.
                set module:blackout to true.
                return false.
            }
        }
        if module:blackout return false.
        else return true.
    }
}.

// enable/disable comms
set module:setCommStatus to {
    parameter connection.
    parameter tag is "all".

    // turning off every comm device or just a specific one?
    if tag = "all" {
        for comm in module:links:values {
        if comm:hasmodule("ModuleDeployableAntenna") {
            if comm:getmodule("ModuleDeployableAntenna"):hasevent(connection) comm:getmodule("ModuleDeployableAntenna"):doevent(connection).
        } 
        }
    } else {
        if module:links[tag]:hasmodule("ModuleDeployableAntenna") {
            if module:links[tag]:getmodule("ModuleDeployableAntenna"):hasevent(connection) module:links[tag]:getmodule("ModuleDeployableAntenna"):doevent(connection).
        } 
    }
}.

set module:stashmit to {
    parameter data.
    parameter filename is "/data/log".
    parameter filetype is fs:type:log:ext.

    if module:checkLink() {
        fs:write(data, fs:ksc:ship:root + filename, filetype, archive).
    } else {
        fs:write(data, filename, filetype).
    }
}.

set module:transferFiles to {
    local transferedFiles is false.
    local filter is fs:isData@.
    local onAccept is {
        parameter f, src, tgt, srcVol, tgtVol.

        set transferedFiles to true.

        logger:debugf("transferring file %s with contents:%n%s", src, f:readall).
        fs:appendOrCopy(f, src, tgt, srcVol, tgtVol).
        srcVol:delete(src).
    }.

    fs:copyDir("/data", fs:ksc:ship:data, filter, onAccept, core:volume, archive).
    if transferedFiles logger:debug("Files were found and transfered").
    return transferedFiles.
}.

global comms is module.
register("comms", comms, {return defined comms.}).