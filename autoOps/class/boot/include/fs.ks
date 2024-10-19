@lazyGlobal off.

parameter kscRoot is "/autoOps", localRoot is "", initReqDirs is list("/boot", "/data", "/mem", "/ops", "/cmd", "/include", "/test").

require("console").
//optional dependency on 'persist' - enables json file types

//////////////////
// Boot-critical Filesystem Initialization
//////////////////

local module is lex().

local localProfile is ship:name.
local launchNum is 0.

if defined boot {
    if boot:hasSuffix("profile") set localProfile to boot:profile.
    if boot:hasSuffix("launchNum") set launchNum to boot:launchNum.
}

local logger to console:logger("fs").
set logger:level to console:level:debug.
set module:logger to logger.

//archive paths are available via the following constants
//local paths are meant to be handled by the concerned script or or a cmd/include file
set module:ksc to lex("root", kscRoot).
set module:ksc:class to lex("root", module:ksc:root + "/class").
set module:ksc:classFor to {
    parameter name.
    local class is lex("root", module:ksc:class:root + "/" + name).
    set class:include to class:root + "/include".
    set class:cmd to class:root + "/cmd".
    set class:tst to class:root + "/test".
    return class.
}.
set module:ksc:profile to lex("root", module:ksc:root + "/vessel").
set module:ksc:profileFor to {
    parameter name.
    local profile is lex("root", module:ksc:profile:root + "/" + name).
    set profile:count to profile:root + "/count".
    set profile:class to profile:root + "/profile".
    set profile:launch to {
        parameter num.
        local launch is lex("root", profile:root + "/" + num).
        set launch:reloadFlag to launch:root + "/reload".
        set launch:ops to lex("root", launch:root + "/ops").
        set launch:ops:file to launch:ops:root + "/ops.ops".
        set launch:boot to launch:root + "/boot.ksm".
        set profile:data to launch:root + "/data".
        return launch.
    }.
    return profile.
}.

set module:ksc:profile:local to module:ksc:profileFor(localProfile).
set module:ksc:ship to module:ksc:profile:local:launch(launchNum).

set module:reqDirs to list().

for dir in initReqDirs {
    module:reqDirs:add(localRoot + dir).
}

set module:reqDirCheck to {
    for dir in module:reqDirs {
        if not core:volume:exists(dir) core:volume:createDir(dir).
    }
}.

module:reqDirCheck(). 

set module:loadClass to {
    parameter class, tst is false.

    logger:infof("Loading specified class: %s", class).

    module:reqDirCheck().

    if(not class) {
        logger:warn("Class not specified").
        logger:info("Skipping class includes...").
        logger:info("Skipping class cmds...").
        if tst logger:info("Skipping class tests...").
        return.
    }

    if(not archive:exists("/autoOps/class/" + class + "/")) {
        logger:warn("Class does not yet exist").
        logger:info("Skipping class includes...").
        logger:info("Skipping class cmds...").
        if tst logger:info("Skipping class tests...").
        return.
    }

    local root is module:ksc:classFor(class).

    //compile and copy includes
    logger:info("Compiling and copying class includes").
    module:compile(archive, core:volume, root:include).
    module:copyDir(root:include, localRoot + "/include", module:isCompiled@).

    //compile and copy commands
    logger:info("Compiling and copying class cmds").
    module:compile(archive, core:volume, root:cmd).
    module:copyDir(root:cmd, localRoot + "/cmd", module:isCompiled@).

    if tst {
        //compile and copy tests
        logger:info("Compiling and copying class tests").
        module:compile(archive, core:volume, root:tst).
        module:copyDir(root:tst, localRoot + "/test", module:isCompiled@).
    }
}.

//////////////////
// Filesystem Initialization
//////////////////

set module:type to lex().

set module:addFileType to {
    parameter ext, formatter, writeHandler is defaultWriter@, appendHandler is defaultAppendHandler@.

    logger:debugf("Adding file handler for '.%s'%nformatter: %s%nwriteHandler: %s%nappendHandler: %s", ext, formatter, writeHandler, appendHandler).
    local type is lex().
    set type:ext to ext.
    set type:formatter to formatter.
    set type:writeHandler to writeHandler.
    set type:appendHandler to appendHandler.

    module:type:add(ext, type).
}.

local function defaultWriter {
    parameter text, filename, vol.

    logger:debug("executing default write handler").
    logger:debugf("Writing to '%s:%s' the contents: %s", vol, filename, text).
    
    if vol:freespace = -1 or vol:freespace > text:length {
        vol:open(filename):write(text).
    } else {
        logger:error("Out Of Memory!").
    }
}

local function defaultAppendHandler {
    parameter f, filename, vol.
    
    logger:debug("executing default append handler").
    logger:debugf("copying from '%s' to '%s:%s'", fs:toPath(f), vol, filename).

    local contents is f:readall().

    if vol:freespace = -1 or vol:freespace > contents:length {
        vol:open(filename):write(contents).
    } else {
        logger:error("Out Of Memory!").
    }
}

module:addFileType(
    "raw",
    {
        parameter data.

        if data:isType("String") return data.
        return console:fmt("%s", data).
    },
    defaultWriter@,
    false //not appendable (safer for unknown file types)
).

module:addFileType(
    "txt", 
    {
        parameter data.

        if data:isType("String") return data.
        return console:fmt("%s", data).
    }
).

//disable logging while operating on log files to prevent infinite recursion
module:addFileType(
    "log",
    {
        parameter data.

        if data:isType("String") return data.
        return console:fmt("%s%n", data).
    },
    {
        parameter text, filename, vol.

        if vol:freespace = -1 or vol:freespace > text:length {
            vol:open(filename):write(text).
        }
    },
    {
        parameter f, filename, vol.

        local contents is f:readall().
        if vol:freespace = -1 or vol:freespace > contents:length {
            vol:open(filename):write(contents).
        }
    }
).

local function toCSVLine{
    parameter data.

    if data:isType("String") return data.
    if data:isType("Lexicon") set data to data:values.
    if data:isType("Enumerable") {
        local result is "".

        for entry in data {
            if entry:isType("UserDelegate") set entry to "null".
            if result = "" set result to entry.
            else set result to result + "," + entry.
        }
        return result.
    }
    logger:error("Invalid object! Expected: String | Lexicon | Enumerable").
    return false.
}
set module:toCSVLine to toCSVLine@.

module:addFileType(
    "csv",
    {
        parameter data.
        return console:fmt("%s%n", toCSVLine(data)).
    }
).

module:addFileType(
    "json",
    {
        parameter data.
        return data.
    },
    {
        parameter data.
        parameter filename.
        parameter vol.

        //skip size calculations (and by extension persist) if writing to archive
        if vol = archive {
            logger:debug("Target volume is Archive. Skipping size calculations and writing directly").
            writejson(data, vol:name + ":" + filename).
            return.
        }

        if not (defined persist) {
            logger:error("Cannot write json to local volumes! Requires 'persist' module to be loaded").
            return.
        }

        // strings and filecontents can be translated directly into byte sizes, but json lists need more work
        persist:declare("jsonSizes", lexicon()).

        local dataSize is 0.

        // if the json file has not yet been written, we won't know the size
        // set size to 15bytes per value to avoid disk write overrun
        if not persist:get("jsonSizes"):haskey(filename) {
            persist:get("jsonSizes"):add(filename, list()).
            set dataSize to 15 * data:length.
        } else {

            // get the average size of this json object
            for filesize in persist:get("jsonSizes")[filename] set dataSize to dataSize + filesize.
            set dataSize to dataSize / persist:get("jsonSizes")[filename]:length.
        }

        logger:debugf("writing contents to %s: %s", vol:name, filename).
        logger:debugf("data size: %s, free space: %s", dataSize, vol:freespace).
        logger:debugf("raw data: %s", data).
        logger:debugf("write target: %s", vol:open(filename)).

        // compare the size of the old file to the size of the new one and store it
        local filesize is vol:open(filename):size.
        writejson(data, vol:name + ":" + filename).
        persist:get("jsonSizes")[filename]:add(vol:open(filename):size - filesize).
    },
    false //not appendable
).

module:addFileType("ks", false, false, false). //not writable, not appendable
module:addFileType("ksm", false, false, false). //not writable, not appendable

set module:write to {
    parameter data.
    parameter filename is "/data/log".
    parameter filetype is module:type:log:ext.
    parameter vol is core:volume.

    if not filename:endswith("." + filetype) set filename to filename + "." + filetype.

    //prevent recursive writes to any log files.
    local doLog is not filetype = "log".

    if doLog logger:debugf("Writing data to %s:%s", vol:name, filename).

    if not vol:exists(filename) {
        if doLog logger:debug("File does not exist; creating empty file.").
        vol:create(filename).
    }

    if doLog logger:debugf("Loading file handler for '%s'", filetype).

    local formatter is false.
    local writer is false.
    //get handler for extension and invoke write handler
    if not module:type:hasKey(filetype) {
        if doLog logger:warnf("Unknown filetype: '%s', defaulting to raw", filetype).
        set formatter to module:type:raw:formatter.
        set writer to module:type:raw:writeHandler.
    } else {
        set formatter to module["type"][filetype]["formatter"].
        set writer to module["type"][filetype]["writeHandler"].

        if doLog logger:debugf("Handler exists for '%s'", filetype).
    }

    if doLog logger:debugf("formatter: %s%nwriter: %s", formatter, writer).

    if formatter:isType("UserDelegate") and writer:isType("UserDelegate") {
        if doLog logger:debug("Formatter and write handler are valid delegates.").
        writer(formatter(data), filename, vol).
    }
    else if doLog logger:warn("Writing is not supported for filetype: " + filetype).
}.

set module:toPathString to {
    parameter p.

    set p to toPath(p).
    if not p:isType("Path") return false.

    local result is "".
    for segment in p:segments {
        set result to result + "/" + segment.
    }
    return result.
}.

local function toPath {
    parameter pathLike.

    if pathLike:isType("Path") return pathLike.
    if pathLike:isType("VolumeItem") return path(pathLike).
    if pathLike:isType("String") return path(pathLike).

    logger:error("Expected pathlike (String | Path | VolumeItem), received: " + pathLike).
    return false.
}
set module:toPath to toPath@.

// visits all file and folder descriptors (recursively) in the start directory, and feeds them to the callback
local function walk {
    parameter vol.
    parameter start.
    parameter callback.

    set start to toPath(start).
    if not start:isType("Path") return.

    logger:debugf("Beginning walk of %s:%s with callback: %s", vol, start, callback).

    local dir is vol:open(module:toPathString(start)).
    logger:debug("invoking callback for " + dir).
    callback(dir).

    for descriptor in dir:lex:values {
        if not descriptor:isFile {
            logger:debug("recursing into directory " + descriptor).
            walk(vol, module:toPathString(path(descriptor)), callback).
        } else {
            logger:debug("invoking callback for " + descriptor).
            callback(descriptor).
        }
    }

    logger:debugf("Ending walk of %s:%s with callback: %s", vol, start, callback).
}

set module:walk to walk@.

set module:visitor to {
    parameter filter, callback, f.

    if f:isFile {
        if filter(f) callback(f).
    }
}.

// visits all files (recursively) in the start directory. If it is accepted by the filter, then it is fed to the callback
set module:visit to {
    parameter vol.
    parameter start.
    parameter filter.
    parameter callback.

    logger:debugf("beginning visit to %s, %s, %s, %s", vol, start, filter, callback).

    walk(vol, start, module:visitor@:bind(filter, callback)).
}.

set module:pathAfter to {
    parameter child, parent.

    local childPath is toPath(child).
    local parentPath is toPath(parent).

    if not childPath:isType("Path") or not parentPath:isType("Path") return "".

    local result is "".

    for segment in childPath:segments:sublist(parentPath:segments:length, childPath:segments:length - parentPath:segments:length) {
        set result to result + "/" + segment.
    }

    return result.
}.

set module:copyOnly to {
    parameter f, src, tgt, srcVol, tgtVol. 

    logger:debugf("performing copy-only from %s:%s to %s:%s", srcVol:name, src, tgtVol:name, tgt).

    copyPath(srcVol:name + ":" + src, tgtVol:name + ":" + tgt).
}.

set module:appendOrCopy to {
    parameter f, src, tgt, srcVol, tgtVol.

    local ext is path(src):extension.
    if module:type:hasKey(ext) {
        local append is module["type"][ext]["appendHandler"].

        //if file type is appendable, then append
        if append:isType("UserDelegate") {
            append(f, tgt, tgtVol).
            return.
        }
    }
    //copy if not appendable, or file type not recognized
    copyPath(srcVol:name + ":" + src, tgtVol:name + ":" + tgt).
}.

set module:copyDir to {
    parameter src, tgt.
    parameter accept is {parameter f. return true.}.
    parameter onAccept is module:copyOnly@.
    parameter srcVol is archive.
    parameter tgtVol is core:volume.

    local copier is {
        parameter f.

        logger:debug("Performing copy operation on " + fs:toPathString(path(f))).
        logger:debugf("src: %s, tgt: %s, srcVol: %s, tgtVol: %s", src, tgt, srcVol:name, tgtVol:name).

        local fPath is fs:pathAfter(f, srcVol:open(src)).
        logger:debug("fPath: " + fPath).

        if f:isFile {
            logger:debug("evaluating file against filter").
            if accept(f) {
                logger:debug("accepted by filter").
                onAccept(f, src + fPath, tgt + fPath, srcVol, tgtVol).
            } else {
                logger:debug("rejected by filter").
            }
        } else {
            logger:debug("checking existence of dir").
            if not tgtVol:exists(tgt + fPath) {
                logger:debug("dir does not exist, creating new dir").
                tgtVol:createDir(tgt + fPath).
            } else {
                logger:debug("dir already exists, skipping creation").
            }
        }
    }.

    walk(srcVol, src, copier).
}.


set module:compile to {
    parameter vol, retVol, start.

    local compiler is {
        parameter f.
        switch to vol.
        compile fs:toPathString(path(f)).
        switch to retVol.
    }.

    module:visit(vol, start, module:isSrc@, compiler@).
}.

set module:is to {
    parameter type, f.

    local filePath is path(f).

    logger:debugf("'%s' is of filetype '%s': %s ", module:toPathString(filePath), type, (filePath:extension = type)).
    return filePath:extension = type.
}.

set module:in to {
    parameter types, f.

    local filePath is path(f).

    logger:debugf("%s is in file type list %s: %s", module:toPathString(filePath), types, (types:contains(filePath:extension))).

    return types:contains(filePath:extension).
}.

set module:isSrc to module:is@:bind(module:type:ks:ext).
set module:isCompiled to module:is@:bind(module:type:ksm:ext).
set module:dataTypes to list(module:type:log:ext, module:type:txt:ext, module:type:raw:ext, module:type:json:ext, module:type:csv:ext).
set module:isData to module:in@:bind(module:dataTypes).

set module:printTree to {
    parameter vol, start, printer is logger:info.
    walk(vol, start, printer).
}.

global fs is module.
register("fs", fs, {return defined fs.}).