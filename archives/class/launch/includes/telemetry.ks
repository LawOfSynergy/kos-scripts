@lazyGlobal off.

require(list("console", "helpFunc", "persist", "ops")).

global telemetry is lex().

// //init static, single-write datapoints
// local statics is lex().
// persist:handlerFor("statics", {return statics.}, {parameter data. set statics to data.}).

// set telemetry:logStatic to {
//     parameter name, value.

//     if(not statics:hasKey(name)) statics:add(name, value).
// }.

// telemetry:
// telemetry:
// telemetry:
// telemetry:

//init time-series telemetry datapoints

local SOURCES is "sources".
local HEADERS is "headers".
local HISTORY is "history".

set telemetry:datasheet to lex().
set telemetry:newDataSheet to {
    parameter name.

    local datasheet is lex().
    set datasheet:statics to lex().
    set datasheet:data to lex(SOURCES, list(), HEADERS, list(), HISTORY, list()).
    set datasheet:previousDatapoint to lex().
    set datasheet:locked to false.

    set datasheet:logStatic to {
        parameter key, value.

        if(not datasheet:statics:hasKey(key)) {
            datasheet:statics:add(key, value).
            comms:stashmit(key + "," + value, name + "-statics", fs:type:csv:ext).
        }
    }.

    set datasheet:addDataSource to {
        parameter dataLex.

        if datasheet:locked return.

        datasheet:data:sources:add(dataLex).
        for header in dataLex:keys {
            if not datasheet:data:headers:contains(header) datasheet:data:headers:add(header).
        }
    }.

    local function getDatapoint {
        wait 0.001. //ensure calculations are done in a single physics tick (if possible)
        local datum is lex().
        for source in datasheet:data:sources {
            for key in source:keys {
                if datasheet:data:headers:contains(key) datum:add(key, source[key]()).
            }
        }

        set datum:getOrDefault to {
            parameter header, default.

            if datum:hasKey(header) return datum[header].
            return default.
        }.
        return datum.
    }

    set datasheet:capture to {
        if not datasheet:locked {
            set datasheet:locked to true.
            comms:stashmit(datasheet:data:headers, name, fs:type:csv:ext).
        }

        local newDP is getDatapoint().

        set datasheet:previousDatapoint to newDP.
        datasheet:data:history:add(newDP).
        comms:stashmit(newDP, name, fs:type:csv:ext).
    }.

    set datasheet:logDeltaVs to {
        parameter prefix, deltaVs.

        datasheet:addDataPoints(lex(
            prefix + " (Current)", {return deltaVs():current.},
            prefix + " (ASL)", {return deltaVs():asl.},
            prefix + " (Vacuum)", {return deltaVs():vacuum.},
            prefix + " (duration)", {return deltaVs():duration.}
        )).
    }.

    set datasheet:addDefaults to {
        //default statics
        datasheet:logStatic("launchPositionLat", ship:geoposition:lat).
        datasheet:logStatic("launchPositionLng", ship:geoposition:lng).
        datasheet:logStatic("kOS processor version", core:version).
        datasheet:logStatic("Running on,", core:element:name).
        
        //default time-series sources
        datasheet:addDataPoints(dds).
        datasheet:logDeltaVs("Ship deltaV", {return ship:deltav.}).
        datasheet:logDeltaVs("Current Stage deltaV", {return stage:deltaV.}).    
    }.

    telemetry:datasheet:add(name, datasheet).

    return datasheet.
}.

lock localBody to SHIP:BODY.
lock localAtm to localBody:atm.
lock jPerKgK to constant:IdealGas/localAtm:molarmass.
lock heatCapacityRatio to localAtm:ADIABATICINDEX.

local dds is lex().

//universe
dds:add("UT", {return floor(time:seconds).}).
dds:add("MET (S)", {return MISSIONTIME.}).

//kOS stats
dds:add("Total Space (bytes)", {return core:volume:capacity.}).
dds:add("Free Space (bytes)", {return core:volume:freespace.}).
dds:add("Used Space (bytes)", {return core:volume:capacity - core:volume:freespace.}).

//ship
dds:add("Heading", {return compass_for(ship).}).
dds:add("Pitch", {return pitch_for(ship).}).
dds:add("Roll", {return roll_for(ship).}).
dds:add("Throttle (%)", {return throttle*100.}).
dds:add("Altitude (m)", {return ship:altitude.}).
dds:add("Mach (m/s)", {return SQRT(heatCapacityRatio*jPerKgK*localAtm:ALTITUDETEMPERATURE(ship:altitude)).}).
dds:add("Surface Velocity (m/s)", {return ship:velocity:surface.}).
dds:add("Orbital Velocity", {return ship:velocity:orbit.}).
dds:add("Vertical Angle of Attack", {return vertical_aoa().}).

dds:add("Mass (t)", {return ship:mass.}).
dds:add("Max Thrust (kN)", 
    {
        local possibleThrust is 0.

        for engine in ship:engines {
            set possibleThrust to possibleThrust + engine:maxThrust.
        }

        return possibleThrust.
    }).
dds:add("Possible Thrust (kN)", 
    {
        local possibleThrust is 0.

        for engine in ship:engines {
            set possibleThrust to possibleThrust + engine:possibleThrust.
        }

        return possibleThrust.
    }).
dds:add("Available Thrust (kN)", 
    {
        local thrust is 0.

        for engine in ship:engines {
            set thrust to thrust + engine:availableThrust.
        }

        return thrust.
    }).
dds:add("Current Thrust (kN)", 
    {
        local thrust is 0.

        for engine in ship:engines {
            set thrust to thrust + engine:thrust.
        }

        return thrust.
    }).
dds:add("Possible TWR", {return addons:ke:totalTWR.}).
dds:add("Actual TWR", {return addons:ke:actualTWR.}).


dds:add("Latitude", {return ship:geoposition:lat.}).
dds:add("Longitude", {return ship:geoposition:lng.}).
dds:add("Apoapsis (m)", {return ship:orbit:apoapsis.}).
dds:add("Periapsis (m)", {return ship:orbit:periapsis.}).
dds:add("Inclination", {return ship:orbit:inclination.}).
dds:add("Distance Downrange (m)", {return circle_distance(latlng(statics["launchPositionLat"], statics["launchPositionLng"]), ship:geoposition, localBody:radius).}).


//environment
dds:add("Dynamic Pressure - Q (atm)", {return ship:Q.}).
dds:add("Pressure (atm)", {return localAtm:ALTITUDEPRESSURE(ship:altitude).}).
dds:add("Density (kg/m^3)", {return (telemetry:getPreviousDatumOrDefault("Dynamic Pressure - Q (atm)", 0) + ship:Q) / ((ship:velocity:surface:SQRMAGNITUDE + telemetry:getPreviousDatumOrDefault("Surface Velocity (m/s)", ship:velocity:surface):SQRMAGNITUDE) / 2).}).
dds:add("Molar Mass (mg/J)", {return localAtm:molarmass.}).
dds:add("Atmospheric Temperature (K)", {return localAtm:ALTITUDETEMPERATURE(ship:altitude).}).
dds:add("Gravity", 
    {
        local radiusFromCenter is localBody:radius + ship:altitude.
        local radiusFromCenterkm is radiusFromCenter/1000.
        local bodyRadiuskm is localBody:radius/1000.
        local radiusRatio is radiusFromCenterkm/bodyRadiuskm.
        local radiusRatioSqr is radiusRatio^2.
        local result is surfaceGravity/radiusRatioSqr.
        return result.
    }).



