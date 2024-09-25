@lazyGlobal off.

//////////////////
// Boot Utility Functions
//////////////////

local modules is lex().

local function ensureModuleIsLoaded {
    parameter name.

    if not modules:hasKey(name) runOncePath("/include/" + name).
    else {
        local module is modules[name].
        if not module:isLoaded() {
            if module:cleanUp:isType("UserDelegate") module:cleanUp().
            runPath("/include/" + name).
        }
    }
}

global function require {
    parameter module.

    if module:isType("Enumerable") {
        for m in module {
            ensureModuleIsLoaded(m).
        }
    } else {
        ensureModuleIsLoaded(module).
    }
}

global function register {
    parameter name, instance, isLoaded, cleanUp is false.

    local module is lex().
    set module:name to name.
    set module:instance to instance.
    set module:isLoaded to isLoaded.
    set module:cleanUp to cleanUp.

    set modules[name] to module.
}

global function validateModules {
    for key in modules:keys {
        ensureModuleIsLoaded(key).
    }
}