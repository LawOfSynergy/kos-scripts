require(list("fs", "console")).

//////////////////
// Init Comms
//////////////////

global comms is lex().

set comms:connected to false.
set comms:blackout to false.

// get all comm parts on the ship
set comms:cmdLink to ship:controlpart:getmodule("modulecommand").
set comms:links to lex().
for part in ship:parts {
    if part:hasmodule("moduledatatransmitter") set comms["links"][part:tag] to part.
    if part:hasmodule("moduledatatransmitterfeedeable") set comms["links"][part:tag] to part.
}

set comms:getSignal to {
    return comms:cmdLink:getfield("comm signal").
}.

// are we connected?
set comms:checkLink to {
    if comms:getSignal() = "0.00" {
        if comms:connected or comms:blackout {
            set comms:connected to false.
            set comms:blackout to false.
            console:info("KSC link lost").
        }
        return false.
    } else {
        if not comms:connected and not comms:blackout {
            set comms:connected to true. 
            console:info("KSC link acquired").
        }

        local signal is comms:getSignal().
        // dunno where "NA" comes from, but loading out onto the pad it happens for split second or something
        if signal <> "1.00" and signal <> "NA" and not comms:blackout {

            // if the signal has degraded more than 50% and we are in atmosphere, comm blackout is likely coming soon
            if signal < 50 and ship:altitude < 70000 {
                set comms:connected to false.
                set comms:blackout to true.
                return false.
            }
        }
        if comms:blackout return false.
        else return true.
    }
}.

// enable/disable comms
set comms:setCommStatus to {
    parameter connection.
    parameter tag is "all".

    // turning off every comm device or just a specific one?
    if tag = "all" {
        for comm in comms:links:values {
        if comm:hasmodule("ModuleDeployableAntenna") {
            if comm:getmodule("ModuleDeployableAntenna"):hasevent(connection) comm:getmodule("ModuleDeployableAntenna"):doevent(connection).
        } 
        }
    } else {
        if comms:links[tag]:hasmodule("ModuleDeployableAntenna") {
            if comms:links[tag]:getmodule("ModuleDeployableAntenna"):hasevent(connection) comms:links[tag]:getmodule("ModuleDeployableAntenna"):doevent(connection).
        } 
    }
}.

set comms:stashmit to {
    parameter data.
    parameter filename is "/data/log".
    parameter filetype is fs:type:txt:ext.

    if comms:checkLink() {
        fs:write(data, boot:shipDir + filename, filetype, archive).
    } else {
        fs:write(data, filename, filetype).
    }
}.

set comms:transferFiles to {
    local transferedFiles is false.
    local filter is fs:isData@.
    local onAccept is {
        parameter f, src, tgt, srcVol, tgtVol.

        set transferedFiles to true.

        print "transferring file " + src + " with contents: " + f:readall.
        fs:appendOrCopy(f, src, tgt, srcVol, tgtVol).
        srcVol:delete(src).
    }.

    fs:copyDir("/data", boot:shipDir + "/data", filter, onAccept, core:volume, archive).
    if transferedFiles print "Files were found and transfered".
    return transferedFiles.
}.
modules:add("comms", comms).