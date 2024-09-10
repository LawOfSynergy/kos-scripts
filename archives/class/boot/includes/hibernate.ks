@lazyGlobal off.

require(list("console", "comms", "persist")).

// get a hibernation controller?
global canHibernate is false.
if ship:partstagged("hibernationCtrl"):length {
  global hibernateCtrl to ship:partstagged("hibernationCtrl")[0]:getmodule("Timer").
  set canHibernate to true.
  if ship:partstagged(core:tag)[0]:getmodule("ModuleGenerator"):hasevent("Activate CPU") {
    ship:partstagged(core:tag)[0]:getmodule("ModuleGenerator"):doevent("Activate CPU").
  }
}

// place the command probe into a state of minimum power
function hibernate {
  parameter wakefile.
  parameter duration is 0.
  parameter comms is false.

  // only proceed if hibernation is available
  if canHibernate {

    // set comms as requested
    if not comms comms:setCommStatus("retract antenna").

    // define the file that will run once after coming out of hibernation
    if wakefile:length persist:set("wakeFile", wakeFile).

    // save all the current volatile data
    persist:write().

    // set and activate the timer?
    if duration > 0 and duration <= 120 {
      if hibernateCtrl:hasevent("Use Seconds") hibernateCtrl:doevent("Use Seconds").
      hibernateCtrl:setfield("Seconds", duration).
      hibernateCtrl:doevent("Start Countdown").
    } else if duration > 0 {
      if hibernateCtrl:hasevent("Use Minutes") hibernateCtrl:doevent("Use Minutes").
      hibernateCtrl:setfield("Minutes", floor(duration/60)).
      hibernateCtrl:doevent("Start Countdown").
    }
    
    // switch off the cpu. Nite nite!
    console:info("Activating hibernation").
    ship:partstagged(core:tag)[0]:getmodule("ModuleGenerator"):doevent("Hibernate CPU").
    ship:partstagged(core:tag)[0]:getmodule("KOSProcessor"):doevent("Toggle Power").
  } else console:warn("Hibernation is not supported on this vessel!").
}