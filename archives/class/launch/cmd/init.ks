@lazyGlobal off.

//# set up stages

// global stages is lex(). //ENGINE, lex(), COUPLER, lex(), CHUTE, lex(), TOWER, list(), STAGE_AVAILABLE_THRUST, lex()

// function initStagedPartType {
//     parameter type, initializer.

//     for part in ship:partstaggedpattern(type+":\d") {
//         local tag is part:tag.
//         local index is tag:indexof(type).
//         local stg is tag:substring(index + type:length + 1, 1).
        
//         if (not stages[type]:haskey(stg)) {
//             stages[type]:add(stg, list()).
//         }

//         initializer(part, stg).
//     }
// }

// function standardStagedPartInit {
//     parameter type, module.

//     set stages[type] to lex().
//     initStagedPartType(type, {
//         parameter part, stg.
//         if not stages[type]:hasKey(stg) stages[type]:add(stg, list()).
//         stages[type][stg]:add(part:getModule(module)).
//     }).
// }

// initialize engines
// global ENGINE is "engine".
// global ENGINE_MODULE is "engineModule".
// global STAGE_AVAILABLE_THRUST is "availableThrust".

// global engList is list().
// set stages[ENGINE] to lex().
// set stages[ENGINE_MODULE] to lex().
// set stages[STAGE_AVAILABLE_THRUST] to lex().

// initStagedPartType(ENGINE, {
//     parameter part, stg.

//     local module is part:getModule("ModuleEngines").

//     if not stages[ENGINE]:hasKey(stg) {
//         stages[ENGINE]:add(stg, list()).
//     }

//     if not stages[ENGINE_MODULE]:hasKey(stg) {
//         stages[ENGINE_MODULE]:add(stg, list()).
//     }
    
//     stages[ENGINE][stg]:add(part).
//     stages[ENGINE_MODULE][stg]:add(module).
//     engList:add(part).

//     if not stages[STAGE_AVAILABLE_THRUST]:haskey(stg) set stages[STAGE_AVAILABLE_THRUST][stg] to part:availableThrust.
//     else set stages[STAGE_AVAILABLE_THRUST][stg] to stages[STAGE_AVAILABLE_THRUST][stg] + part:availableThrust.
// }).

// initialize couplers
// global COUPLER is "coupler".
// standardStagedPartInit(COUPLER, "ModuleAnchoredDecoupler").

// initialize chutes
// global CHUTE is "chute".
// standardStagedPartInit(CHUTE, "RealChuteModule").

//initialize fairings
global fairings is list().
for part in ship:partstagged("fairing") {
    fairings:add(part:getModule("ModuleProceduralFairing")).
}

// initialize towers. These do not actually have a stage. They are all meant to be decoupled at transition from stage 0 -> 1
// global TOWER is "tower".
// set stages[TOWER] to list().
// for part in ship:partstagged(TOWER) {
//     stages[TOWER]:add(part:getmodule("LaunchClamp")).
// }

// global payloadDecoupler is ship:partstagged("payloadBase")[0]:getmodule("ModuleDecouple").

if ship:partstaggedpattern("class:"):length > 0 {
    global probe is ship:partstaggedpattern("class:")[0]:getModule("kOSProcessor").
    
    // set the probe's boot log, copy it over and shut it down
    set probe:bootfilename to "boot/boot.ksm".
    set probe:volume:name to "probe".
    copypath("0:/class/boot/tinyboot.ksm", probe:volume:name + ":/boot/boot.ksm").
    wait 0.001.
    probe:deactivate.
}



//# initialize variables
// global currThrottle is 0.
// global logInterval is 1.
// global maxQ is 0.
// lock pitch to 89.98.

//log stage telemetry
//log engine telemetry

//TODO fix telemetry
// add any custom logging fields, then call for header write and setup log call
// set getter("addlLogData")["Target Pitch"] to {
//     return pitch.
// }.

// initLog().
// function logData {
//   logTlm(floor(time:seconds) - getter("launchTime")).
// }