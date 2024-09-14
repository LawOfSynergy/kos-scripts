//////////////////
// Boot Utility Functions
//////////////////

local modules is lex().

local function ensureModuleIsLoaded {
    parameter name.

    if not modules:hasKey(name) runOncePath("/include/" + name).
    else if not modules[name]:isLoaded() runPath("/include/" + name).
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
    parameter name, instance, isLoaded.

    local module is lex().
    set module:name to name.
    set module:instance to instance.
    set module:isLoaded to isLoaded.

    set modules[name] to module.
}

global function validateModules {
    for key in modules:keys {
        ensureModuleIsLoaded(key).
    }
}