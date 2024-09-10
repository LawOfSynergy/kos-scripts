@lazyGlobal off.

// We want pitch to equal 90 at apoapsis 0.
// And 0 at apoapsis 70.
// (0,90) to (70000,0)
local dir is persist:get("dir"):toNumber(). //compass heading
local tgtAlt is persist:get("alt"):toNumber(). //in km
local deorbitAlt is persist:get("deorbitAlt"):toNumber(). //in km

local slope is (0 - 90) / (1000*(tgtAlt-10-tgtAlt*.05)- 0).
console:info("slope: " + slope).

local function getPitch {
	// y - y1 = m(x - x1)
	// pitch - 90 = slope * apoapsis
	local pitch is slope * ship:obt:apoapsis + 90.
	set pitch to max (pitch, 0).
    console:debug(pitch).
	return pitch.
}

set ops["operations"]["stage when empty"] to {
    if stage:liquidfuel < 0.001 and stage:solidfuel < 0.001
    {
        console:info("No fuel remaining in stage. Staging.").
        stage.
        if stage:liquidfuel < 0.001 and stage:solidfuel < 0.001 {
            console:info("No fuel in next stage. Removing autostage").
            ops:operations:remove("stage when empty").
        }
    }
}.

set ops["operations"]["deploy fairings"] to {
    if(ship:altitude > 50000) {
        for plf in fairings {
            plf:doevent("deploy").
        }
        console:info("PLF detached @ 50km").
        ops:operations:remove("deploy fairings").
    }
}.

set ops["operations"]["target apoapsis"] to {
    if ship:obt:apoapsis > 1000*(tgtAlt+1) { //give a little buffer room
        console:info("suborbital ascent complete").

        // ops:operations:remove("twr limiter").
        lock throttle to 0. // Not in RO!
        set ship:control:pilotmainthrottle to 0.
        unlock steering.

        sas on.
        set sasMode to "Stability".

        // wait until we get closer to our node to circularize
        ops:sleep("orient for circularization", {
            console:info("Reorienting for circularization").
            set sasMode to "Prograde".
            set ops["operations"]["circularize"] to circularize@.
        }, (eta:apoapsis - 19), ops:RELATIVE_TIME, ops:PERSIST_N).

        ops:operations:remove("target apoapsis").
    }
}.


local function circularize {
    if eta:apoapsis < 15 {
        ops:operations:remove("circularize").
        console:info("Beginning circularization burn.").
        lock throttle to 1.

        set ops["operations"]["end circularize"] to endCircularize@.
    }
}

local function endCircularize {
    if ship:obt:periapsis > 1000*tgtAlt {
        ops:operations:remove("end circularize").
        console:info("Ending circularization burn.").
        sas off.
        unlock throttle.
    }
}

//once this starts, new datapoints cannot be added to telemetry.
// set ops["operations"]["telemetry"] to telemetry:captureTelemetry@.

////////////////
// Begin Launch
////////////////

//feedback based on atmospheric efficiency

// initTWRLimiter(2).
lock throttle to 1.

SAS off.
lock steering to heading(dir, getPitch()).
stage.