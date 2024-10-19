@lazyGlobal off.

local logger is console:logger("kpm-info").

logger:info("addons: " + addons).
for key in addons:suffixnames {
    logger:info(key).
}

logger:info("kpm: " + addons:kpm).
for key in addons:kpm:suffixnames {
    logger:info(key).
}

logger:info("kpm:buttons: " + addons:kpm:buttons).
for key in addons:kpm:buttons:suffixnames {
    logger:info(key).
}

logger:info("kpm:flags: " + addons:kpm:flags).
for key in addons:kpm:flags:suffixnames {
    logger:info(key).
}

// logger:info(addons:kpm).
// logger:info(addons:kpm:buttons).
// logger:info(addons:kpm:flags).

local function handler {
    parameter index.

    return {
        logger:info(index + " pressed").
    }.
}

from {local x is -6.} until x = 20 STEP {set x to x+1.} do {
    addons:kpm:buttons:setDelegate(x, handler(x)).
}