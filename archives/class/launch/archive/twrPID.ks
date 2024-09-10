require(list("helpFunc", "telemetry")).

global twrPID is pidLoop().

local datasheet is false.

local tuning is lex().
set tuning:dir to boot:shipDir + "/tuning".
set tuning:trackerFile to tuning:dir + "/tracker".
set tuning:bestFile to tuning:dir + "/best".
set tuning:aggregateFile to tuning:dir + "/data".
set tuning:headers to lex().
set tuning:headers:time to "Time since Limit Start (Seconds)".
set tuning:headers:error to "Error".
set tuning:headers:maxTWR to "Max TWR".
set tuning:headers:startTime to "TWR Limiter Start TIme (Seconds)".
set tuning:headers:kp to "Kp".
set tuning:headers:slope to "slope".
set tuning:headers:avgPoO to "avgPoO".
set tuning:ops to lex().
set tuning:ops:init to "initiate twr limiter".
set tuning:ops:limit to "twr limiter".
set tuning:ops:postProcess to "tuning post-processing".


//set the twr pid loop to a specific set of values
ops:opCodeFor("twrpid", {
    parameter cmd.

    set twrPID to pidLoop(cmd[1]:toNumber(), cmd[2]:toNumber(), cmd[3]:toNumber(), 0, 1, cmd[4]:toNumber()).
    set twrPID:setpoint to cmd[5]:toNumber().
}).

ops:opCodeFor("useTuned", {
    parameter cmd.
    //get the optimal tuning based on the tuning data
}).

//mark this as a tuning session. use tuneTracker.json to configure this launch's parameters
ops:opCodeFor("tune", {
    parameter cmd.

    local previousConfig is lex(
        "id", -1, 
        "Kp", 0, 
        "suggestions", lex(
            "Kp", 0.1
        )
    ).

    // I am asserting that we have signal here, since we would have to wait until we have it anyways
    if archive:exists(tuning:trackerFile) {
        set previousConfig to readJson("0:" + tuning:trackerFile).
    }

    //create current config
    local currConfig is lex().
    set currConfig:id to previousConfig:id + 1.
    set currConfig:Kp to previousConfig:suggestions:Kp.
    set currConfig:suggestions to lex().

    //init pid loop with new config values
    set twrPID to pidLoop(currConfig:Kp, 0, 0, 0, 1, 0.005).
    set twrPID:setpoint to 1.

    //init telemetry
    set datasheet to telemetry:newDataSheet("pidtuning-" + currConfig:id).
    datasheet:logStatic("Tuning ID", currConfig:id).
    datasheet:logStatic("Kp", currConfig:Kp).
    local startTime is time:seconds.
    datasheet:logStatic("Start Time", startTime).
    datasheet:addDataSource(lex(
        tuning:headers:time, {return choose time:seconds - datasheet["statics"][tuning:headers:startTime] if datasheet:statics:hasKey(tuning:headers:startTime) else 0.},
        tuning:headers:error, {return choose twrPID:error if datasheet:statics:hasKey(tuning:headers:startTime) else 0.},
        tuning:headers:maxTWR, {return choose addons:ke:totalTWR if datasheet:statics:hasKey(tuning:headers:startTime) else 0.}
    )).
    
    //init ops tasks
    when missionTime > 0 then ops:operations:add("log tuning telemetry", datasheet:capture@).

    ops:operations:add(tuning:ops:postProcess, {
        if ship:altitude > 30000 {
            ops:remove("log tuning telemetry").
            //compare against current best and create suggestions for next tuning launch
            calculateTelemetry(currConfig, datasheet).
            writeJson(currConfig, "0:" + tuning:trackerFile).
        }
    }).
}).

local function calculateTelemetry {
    parameter cfg.

    local data is datasheet:history.

    //calculate peaks
    local peaks is list().

    local prevPeak is "null".
    local ascending is false.
    local peakError is 0.
    local peakTime is 0.
    local prevError is 0.
    local prevTime is 0.
    for datum in data {
        if datum[tuning:headers:time] <> 0 { //filter out datapoints where limiter was not running
            set prevError to datum[tuning:headers:error].
            set prevTime to datum[tuning:headers:time].
            if ascending {
                if prevError > peakError { //increasing, continue tracking
                    set peakError to prevError.
                    set peakTime to prevTime.
                } else { //decreasing, reached new peak
                    set ascending to false.
                    if prevPeak <> "null" { //not first peak
                        local peak is lex().
                        set peak:time to peakTime.
                        set peak:error to peakError.
                        set peak:period to peak:time - prevPeak:time.
                        peaks:add(peak).
                    }
                    set prevPeak to lex().
                    set prevPeak:time to peakTime.
                    set prevPeak:error to peakError.
                }
            } else { //descending
                if prevError < peakError { //decreasing, continue tracking
                    set peakError to prevError.
                    set peakTime to prevTime.
                } else { //increasing, reached new minimum
                    set ascending to true.
                }
            }
        }
    }

    //calculate slope of peaks
    local line is lineFit(peaks).
    
    //calculate average period of oscillation
    local avgPoO is getAvgPoO(peaks).

    //log calculated values to aggregate file

    //ensure file and headers exist
    if not archive:exists(tuning:aggregateFile) {
        archive:create(tuning:aggregateFile).
        comms:stashmit(list(tuning:headers:kp, tuning:headers:slope, tuning:headers:avgPoO)).
    }

    //log Kp, slope, avgPoO
    comms:stashmit(list(cfg:Kp, line:slope, avgPoO)).

    //if better, write as best
    local best is "null".
    if archive:exists(tuning:bestFile) {
        set best to readJson("0:" + tuning:bestFile).
    }
    
    set cfg:line to line.
    if best = "null" or abs(line:slope) < abs(best:line:slope) {
        writeJson(cfg, "0:" + tuning:bestFile).
        set cfg:suggestions:Kp to cfg:Kp * 10.
    }

    //calculate suggestions (hill climb on slope/kP graph)
    local better is "null".
    local worse is "null".
    local onTrack is "null".
    if abs(best:slope) - abs(line:slope) > 0 {
        set onTrack to true.
        set better to cfg.
        set worse to best.
    } else {
        set onTrack to false.
        set better to best.
        set worse to cfg.
    }
    
    local direction is 1.
    if onTrack <> sameSign(better:line:slope, worse:line:slope) {
        set direction to -1.
    }

    local scale is abs((better:Kp - worse:Kp)/(better:line:slope - worse:line:slope)).
    local jitter is random() * scale * direction.

    set cfg:suggestions:Kp to better:Kp + jitter.
}

local function sameSign {
    parameter a, b.
    return (a > 0) = (b > 0).
}

local function getAvgPoO {
    parameter peaks.

    local sum is 0.
    
    for peak in peaks {
        set sum to sum + peak:period.
    }
    return sum/peaks:length.
}

local function lineFit {
    parameter peaks, getCorrelationCoeffition is false.

    local output is lex().

    local sumTime is 0.
    local sumTimeSqrd is 0.
    local sumTimeByAmplitude is 0.
    local sumAmplitude is 0.
    local sumAmplitudeSqrd is 0.

    for peak in peaks {
        set sumTime to sumTime + peak:time.
        set sumTimeSqrd to sumTimeSqrd + peak:time^2.
        set sumTimeByAmplitude to sumTimeByAmplitude + peak:time*peak:error.
        set sumAmplitude to sumAmplitude + peak:error.
        set sumAmplitudeSqrd to sumAmplitudeSqrd + peak:error^2.
    }

    local denom is peaks:length * sumTimeSqrd - sumTime^2.
    if denom = 0 {
        // singular matrix. can't solve the problem
        set output:slope to 0.
        set output:offset to 0.
        if getCorrelationCoeffition set output:correlationCoefficient to 0.
    } else {
        set output:slope to (peaks:length * sumTimeByAmplitude - sumTime*sumAmplitude)/denom.
        set output:offset to (sumAmplitude * sumTimeSqrd - sumTime*sumTimeByAmplitude)/denom.
        if getCorrelationCoeffition {
            set output:correlationCoefficient to 
            (sumTimeByAmplitude - sumTime * sumAmplitude / peaks:length) 
            / sqrt(
                (sumTimeSqrd - sumTime^2/peaks:length) 
                * (sumAmplitudeSqrd - sumAmplitude^2/peaks:length)
            ).
        }
    }
    return output.
}

// lock atmoeff to ship:velocity:surface:mag / .
global currThrottle is 1.

function initTWRLimiter {
    parameter delay.
    
    ops:sleep(tuning:ops:init, {
        datasheet:logStatic(tuning:headers:startTime, time:seconds).

        set ops["operations"][tuning:ops:limit] to {
            set currThrottle to twrPID:update(time:seconds, atmoeff).
        }.
    }, delay, ops:RELATIVE_TIME, ops:PERSIST_N).
}