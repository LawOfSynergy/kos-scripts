@lazyGlobal off.

local setup is {
    require("console").
    require("fs").
    core:volume:createDir("/testdata/1").
    core:volume:create("/testdata/data.txt").
    core:volume:create("/testdata/1/data.txt").
    core:volume:create("/testdata/1/data2.csv").
    core:volume:create("/testdata/1/exec.ks").
}.
local teardown is {
    unset fs.
    unset console.
    core:volume:delete("/testdata").
}.

local defaultGroup is test:create(
    "test_fs_no_dependencies"
).

local function tst {
    parameter module, name, exec, set is setup, tear is teardown.
    return module:test(name, exec, set, tear).
}

local function noop {}

tst(defaultGroup, "ensure_path_constants_map_correctly", {
    local function validate {
        parameter name, value, expected.

        assert(value = expected, console:fmt("expected '%s' = '%s', received: %s", name, expected, value)).
    }

    validate("fs:ksc:root", fs:ksc:root, "/autoOps").
    validate("fs:ksc:class:root", fs:ksc:class:root, "/autoOps/class").

    local bootClass is fs:ksc:classFor("boot").
    validate("fs:ksc:classFor('boot'):root", bootClass:root, "/autoOps/class/boot").
    validate("fs:ksc:classFor('boot'):cmd", bootClass:cmd, "/autoOps/class/boot/cmd").
    validate("fs:ksc:classFor('boot'):include", bootClass:include, "/autoOps/class/boot/include").
    validate("fs:ksc:classFor('boot'):tst", bootClass:tst, "/autoOps/class/boot/test").
    validate("fs:ksc:profile:root", fs:ksc:profile:root, "/autoOps/vessel").
    local localProfile is fs:ksc:profileFor(boot:profile).
    validate("fs:ksc:profileFor(ship:name):root", localProfile:root, "/autoOps/vessel/" + boot:profile).
    validate("fs:ksc:profile:local:root", fs:ksc:profile:local:root, "/autoOps/vessel/" + boot:profile).
    validate("fs:ksc:profile:local:count", fs:ksc:profile:local:count, "/autoOps/vessel/" + boot:profile + "/count").
    validate("fs:ksc:profile:local:class", fs:ksc:profile:local:class, "/autoOps/vessel/" + boot:profile + "/profile").
    validate("fs:ksc:profile:local:launch(0):root", fs:ksc:profile:local:launch(0):root, "/autoOps/vessel/" + boot:profile + "/0").
    validate("fs:ksc:ship:root", fs:ksc:ship:root, "/autoOps/vessel/" + boot:profile + "/" + boot:launchNum).
    validate("fs:ksc:ship:reloadFlag", fs:ksc:ship:reloadFlag, "/autoOps/vessel/" + boot:profile + "/" + boot:launchNum + "/reload").
    validate("fs:ksc:ship:ops:root", fs:ksc:ship:ops:root, "/autoOps/vessel/" + boot:profile + "/" + boot:launchNum + "/ops").
    validate("fs:ksc:ship:ops:file", fs:ksc:ship:ops:file, "/autoOps/vessel/" + boot:profile + "/" + boot:launchNum + "/ops/ops.ops").
    validate("fs:ksc:ship:boot", fs:ksc:ship:boot, "/autoOps/vessel/" + boot:profile + "/" + boot:launchNum + "/boot.ksm").
}).

//fs:type:is
tst(defaultGroup, "is_correctly_identifies_file_extension", {
    assert(fs:is("txt", core:volume:open("/testdata/1/data.txt")), "did not correctly recognize txt filetype").
    assert(not fs:is("txt", core:volume:open("/testdata/1/data2.csv")), "incorrectly recognized file as txt filetype").
}).

//fs:type:in
tst(defaultGroup, "in_correctly_identifies_file_extensions", {
    local types is list("txt", "csv").
    assert(fs:in(types, core:volume:open("/testdata/1/data.txt")), "did not correctly recognize txt filetype").
    assert(fs:in(types, core:volume:open("/testdata/1/data2.csv")), "did not correctly recognize csv filetype").
    assert(not fs:in(types, core:volume:open("/testdata/1/exec.ksm")), "incorrectly recognized file as txt filetype").
}).

//fs:toPathString
tst(defaultGroup, "toPathString_returns_absolute_path_without_volume_name_or_number", {
    assert(fs:toPathString(path(core:volume:open("/testdata/data.txt"))) = "/testdata/data.txt", "toPathString did not match the absolute path").
}).

tst(defaultGroup, "toPathString_does_not_return_paths_ending_in_slash_for_dirs", {
    assert(fs:toPathString(path(core:volume:open("/testdata/1/"))) = "/testdata/1", "path for directory ended with a slash").
}).

//fs:pathAfter
tst(defaultGroup, "pathAfter_returns_sensible_subpath", {
    local parent is core:volume:open("/testdata").
    
    assert(fs:pathAfter(core:volume:open("/testdata/1/data.txt"), parent) = "/1/data.txt", "did not return correct subpath for file").
    assert(fs:pathAfter(core:volume:open("/testdata/1/"), parent) = "/1", "did not return correct subpath for directory").
    assert(fs:pathAfter("/testdata/1/data.txt", "/testdata") = "/1/data.txt", "did not return correct subpath for string file").
    assert(fs:pathAfter("/testdata/1/", "/testdata") = "/1", "did not return correct subpath for string directory").
    assert(fs:pathAfter("/testdata/1", "/testdata") = "/1", "did not return correct subpath for string directory without trailing slash").
    assert(fs:pathAfter(path("/testdata/1/data.txt"), path("/testdata")) = "/1/data.txt", "did not return correct subpath for path file").
    assert(fs:pathAfter(path("/testdata/1"), path("/testdata")) = "/1", "did not return correct subpath for path directory").
    assert(fs:pathAfter("/tesstdata/1", parent) = "/1", "did not return correct subpath for mixed pathlike parameters").
}).

//fs:toCSVLine
tst(defaultGroup, "toCSVLine_returns_identity_for_string", {
    assert(fs:toCSVLine("test") = "test", "returned string was modified from the original").
}).

tst(defaultGroup, "toCSVLine_returns_comma_separated_values_line_for_enumerable", {
    assert(fs:toCSVLine(list("a", "b", "c")) = "a,b,c", "did not concatenate the list correctly").
}).

tst(defaultGroup, "toCSVLine_does_not_have_trailing_comma_for_single_entry_list", {
    assert(fs:toCSVLine(list("a")) = "a", "expected identity of only element").
}).

tst(defaultGroup, "toCSVLine_discards_keys_and_keeps_values_for_lexicon", {
    assert(fs:toCSVLine(lex("a", "b", "c", "d", "e", "f")) = "b,d,f", "did not concatenate only the values").
}).

//TODO consider resolving delegate to return value, instead of discarding.
tst(defaultGroup, "toCSVLine_converts_delegates_to_null", {
    assert(fs:toCSVLine(list("a", noop@, "c")) = "a,null,c", "did not convert delegate to null").
}).

//fs:walk
tst(defaultGroup, "walk_recurses_through_the_whole_directory_and_includes_starting_dir", {
    local act is mock(1).
    fs:walk(core:volume, "/testdata", act:invoke@).
    assert(act:invocations:length = 6, "did not hit the correct number of file descriptors. expected: 6, received: " + act:invocations:length).
}).

//fs:visit
tst(defaultGroup, "visit_only_hits_files_and_only_if_they_match_the_filter", {
    local act is mock(1).
    fs:visit(core:volume, "/testdata", fs:is:bind("txt"), act:invoke@).
    assert(act:invocations:length = 2, "did not hit the correct number of file descriptors. expected: 2, received: " + act:invocations:length).
}).

//fs:compile
tst(defaultGroup, "compile_recurses_into_directories_and_creates_ksm_files_from_ks_files", {
    fs:compile(core:volume, core:volume, "/testdata").
    assert(core:volume:exists("/testdata/1/exec.ksm"), "did not compile exec.ks to exec.ksm").
}, 
{
    setup().
},
{
    teardown().
    core:volume:delete("/testdata/1/exec.ksm").
}).

//TODO putting these off since I know from manual testing that these work for boot needs
//fs:copyDir
//copyOnly
//core:volume:open:readall:string gives file contents
//appendOrCopy
//appendable (txt or csv)
//writable but not appendable (json)

//fs:write
//create file if not extant
//raw test
//txt test
//csv test
//json test
//non-writeable file test
//unknown file type test