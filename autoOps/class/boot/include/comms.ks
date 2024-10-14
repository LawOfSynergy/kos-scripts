@lazyGlobal off.

require(list("console", "fs")).

//////////////////
// Init Comms
//////////////////

local commsModule is lex().

local logger is console:logger("comms").
set commsModule:logger to logger.

set commsModule:connected to false.
set commsModule:blackout to false.

// get all comm parts on the ship
set commsModule:cmdLink to ship:controlpart:getmodule("modulecommand").
set commsModule:links to lex().
for part in ship:parts {
    if part:hasmodule("moduledatatransmitter") set commsModule["links"][part:tag] to part.
    if part:hasmodule("moduledatatransmitterfeedeable") set commsModule["links"][part:tag] to part.
}

set commsModule:getSignal to {
    return commsModule:cmdLink:getfield("comm signal").
}.

// are we connected?
set commsModule:checkLink to {
    if commsModule:getSignal() = "0.00" {
        if commsModule:connected or commsModule:blackout {
            set commsModule:connected to false.
            set commsModule:blackout to false.
            logger:info("KSC link lost").
        }
        return false.
    } else {
        if not commsModule:connected and not commsModule:blackout {
            set commsModule:connected to true. 
            logger:info("KSC link acquired").
        }

        local signal is commsModule:getSignal().
        // dunno where "NA" comes from, but loading out onto the pad it happens for split second or something
        if signal <> "1.00" and signal <> "NA" and not commsModule:blackout {

            // if the signal has degraded more than 50% and we are in atmosphere, comm blackout is likely coming soon
            if signal < 50 and ship:altitude < 70000 {
                set commsModule:connected to false.
                set commsModule:blackout to true.
                return false.
            }
        }
        if commsModule:blackout return false.
        else return true.
    }
}.

// enable/disable comms
set commsModule:setCommStatus to {
    parameter connection.
    parameter tag is "all".

    // turning off every comm device or just a specific one?
    if tag = "all" {
        for comm in commsModule:links:values {
        if comm:hasmodule("ModuleDeployableAntenna") {
            if comm:getmodule("ModuleDeployableAntenna"):hasevent(connection) comm:getmodule("ModuleDeployableAntenna"):doevent(connection).
        } 
        }
    } else {
        if commsModule:links[tag]:hasmodule("ModuleDeployableAntenna") {
            if commsModule:links[tag]:getmodule("ModuleDeployableAntenna"):hasevent(connection) commsModule:links[tag]:getmodule("ModuleDeployableAntenna"):doevent(connection).
        } 
    }
}.

set commsModule:stashmit to {
    parameter data.
    parameter filename is "/data/log".
    parameter filetype is fs:type:txt:ext.

    if commsModule:checkLink() {
        fs:write(data, fs:ksc:ship:root + filename, filetype, archive).
    } else {
        fs:write(data, filename, filetype).
    }
}.

set commsModule:transferFiles to {
    local transferedFiles is false.
    local filter is fs:isData@.
    local onAccept is {
        parameter f, src, tgt, srcVol, tgtVol.

        set transferedFiles to true.

        logger:debug("transferring file " + src + " with contents: " + f:readall).
        fs:appendOrCopy(f, src, tgt, srcVol, tgtVol).
        srcVol:delete(src).
    }.

    fs:copyDir("/data", fs:ksc:ship:data, filter, onAccept, core:volume, archive).
    if transferedFiles logger:debug("Files were found and transfered").
    return transferedFiles.
}.

global comms is commsModule.
register("comms", comms, {return defined comms.}).