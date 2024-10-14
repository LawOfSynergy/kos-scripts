@lazyGlobal off.

local setup is {}.
local teardown is {}.

local defaultGroup is test:create(
    "test_comms"
).

// local function tst {
//     parameter module, name, exec, set is setup, tear is teardown.
//     return module:test(name, exec, set, tear).
// }