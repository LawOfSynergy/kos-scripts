@lazyGlobal off.

parameter kscRoot is "/autoOps", localRoot is "", initReqDirs is list("/boot", "/data", "/mem", "/ops", "/cmd", "/include", "/test").

require("console").
//optional dependency on 'persist' - enables json file types

//////////////////
// Boot-critical Filesystem Initialization
//////////////////

local fsModule is lex().

local localProfile is ship:name.
local launchNum is 0.

if defined boot {
    if boot:hasSuffix("profile") set localProfile to boot:profile.
    if boot:hasSuffix("launchNum") set launchNum to boot:launchNum.
}

local logger to console:logger().
set fsModule:logger to logger.

//archive paths are available via the following constants
//local paths are meant to be handled by the concerned script or or a cmd/include file
set fsModule:ksc to lex().
set fsModule:ksc:root to kscRoot.
set fsModule:ksc:class to lex().
set fsModule:ksc:class:root to fsModule:ksc:root + "/class".
set fsModule:ksc:classFor to {
    parameter name.
    local class is lex().
    set class:root to fsModule:ksc:class:root + "/" + name.
    set class:include to class:root + "/include".
    set class:cmd to class:root + "/cmd".
    set class:tst to class:root + "/test".
    return class.
}.
set fsModule:ksc:profile to lex().
set fsModule:ksc:profile:root to fsModule:ksc:root + "/vessel".
set fsModule:ksc:profileFor to {
    parameter name.
    local profile is lex().
    set profile:root to fsModule:ksc:profile:root + "/" + name.
    set profile:count to profile:root + "/count".
    set profile:class to profile:root + "/profile".
    set profile:launch to {
        parameter num.
        local launch is lex().
        set launch:root to profile:root + "/" + num.
        set launch:reloadFlag to launch:root + "/reload".
        set launch:ops to launch:root + "/ops".
        set launch:boot to launch:root + "/boot.ksm".
        set profile:data to launch:root + "/data".
        return launch.
    }.
    return profile.
}.

set fsModule:ksc:profile:local to fsModule:ksc:profileFor(localProfile).
set fsModule:ksc:ship to fsModule:ksc:profile:local:launch(launchNum).

set fsModule:reqDirs to list().

for dir in initReqDirs {
    fsModule:reqDirs:add(localRoot + dir).
}

set fsModule:reqDirCheck to {
    for dir in fsModule:reqDirs {
        if not core:volume:exists(dir) core:volume:createDir(dir).
    }
}.

fsModule:reqDirCheck(). 

set fsModule:loadClass to {
    parameter class, tst is false.

    logger:info("Loading specified class: " + class).

    fsModule:reqDirCheck().

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

    local root is fsModule:ksc:classFor(class).

    //compile and copy includes
    logger:info("Compiling and copying class includes").
    fsModule:compile(archive, core:volume, root:include).
    fsModule:copyDir(root:include, localRoot + "/include", fsModule:isCompiled@).

    //compile and copy commands
    logger:info("Compiling and copying class cmds").
    fsModule:compile(archive, core:volume, root:cmd).
    fsModule:copyDir(root:cmd, localRoot + "/cmd", fsModule:isCompiled@).

    if tst {
        //compile and copy tests
        logger:info("Compiling and copying class tests").
        fsModule:compile(archive, core:volume, root:tst).
        fsModule:copyDir(root:tst, localRoot + "/test", fsModule:isCompiled@).
    }
}.

//////////////////
// Filesystem Initialization
//////////////////

set fsModule:type to lex().

set fsModule:addFileType to {
    parameter ext, writeHandler, appendHandler is false.

    logger:debug("Adding file handler for " + ext + " writeHandler: " + writeHandler + " appendHandler: " + appendHandler).
    local type is lex().
    set type:ext to ext.
    set type:writeHandler to writeHandler.
    set type:appendHandler to appendHandler.

    fsModule:type:add(ext, type).
}.

local function defaultAppendHandler {
    parameter f, filename, vol.


    if fileName <> "/data/log.txt" {
        logger:debug("executing default append handler").
        logger:debug("appending to " + vol:name + ":" + filename).
        logger:debug("write target: " + vol:open(filename)).
        logger:debug("copying contents of " + f).
        logger:debug(f:readall()).
    }
    vol:open(filename):write(f:readall()).
}

fsModule:addFileType(
    "txt", 
    {
        parameter data.
        parameter filename.
        parameter vol.

        //prevent recursive writes to the default log file.
        local doLog is not (filename:endsWith("/data/log") or filename:endsWith("/data/log.txt")).

        if doLog {
            logger:debug("writing contents to " + vol:name + ":" + filename).
            logger:debug("data size: " + data:length + " free space: " + vol:freespace).
            logger:debug("raw data: " + data).
            logger:debug("write target: " + vol:open(filename)).
        }
        if vol:freespace = -1 or vol:freespace > data:length {
            vol:open(filename):writeln(data).
        } else {
            if doLog logger:error("Out Of Memory!").
        }
    },
    defaultAppendHandler@
).

fsModule:addFileType(
    "raw",
    {
        parameter data.
        parameter filename.
        parameter vol.

        logger:debug("writing contents to " + vol:name + ":" + filename).
        logger:debug("data size: " + data:length + " free space: " + vol:freespace).
        logger:debug("raw data: " + data).
        logger:debug("write target: " + vol:open(filename)).

        if vol:freespace = -1 or vol:freespace > data:length {
            vol:open(filename):write(data).
        }
    },
    false //not appendable (safer for unknown file types)
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
set fsModule:toCSVLine to toCSVLine@.

fsModule:addFileType(
    "csv",
    {
        parameter data.
        parameter filename.
        parameter vol.

        logger:debug("writing contents to " + vol:name + ":" + filename).
        logger:debug("data size: " + data:length + " free space: " + vol:freespace).
        logger:debug("raw data: " + data).
        logger:debug("formatted data: " + toCSVLine(data)).
        logger:debug("write target: " + vol:open(filename)).
        logger:debug("invoking txt:writeHandler").

        fsModule:type:txt:writeHandler(toCSVLine(data), filename, vol).
    },
    defaultAppendHandler@
).

fsModule:addFileType(
    "json",
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

        logger:debug("writing contents to " + vol:name + ":" + filename).
        logger:debug("data size: " + dataSize + " free space: " + vol:freespace).
        logger:debug("raw data: " + data).
        logger:debug("write target: " + vol:open(filename)).
        logger:debug("json specific debug logging not implemented yet").

        // compare the size of the old file to the size of the new one and store it
        local filesize is vol:open(filename):size.
        writejson(data, vol:name + ":" + filename).
        persist:get("jsonSizes")[filename]:add(vol:open(filename):size - filesize).
    },
    false //not appendable
).

fsModule:addFileType("ks", false, false). //not writable, not appendable
fsModule:addFileType("ksm", false, false). //not writable, not appendable

set fsModule:write to {
    parameter data.
    parameter filename is "/data/log".
    parameter filetype is fsModule:type:txt:ext.
    parameter vol is core:volume.

    //prevent recursive writes to the default log file.
    local doLog is not (filename:endsWith("/data/log") or filename:endsWith("/data/log.txt")).

    if not filename:endswith("." + filetype) set filename to filename + "." + filetype.

    if doLog logger:debug("Writing data to " + vol:name + ":" + filename).

    if not vol:exists(filename) {
        if doLog logger:debug("File does not exist; creating empty file.").
        vol:create(filename).
    }

    if doLog logger:debug("Loading file handler for " + filetype).

    local writer is "".
    //get handler for extension and invoke write handler
    if not fsModule:type:hasKey(filetype) {
        if doLog logger:error("Unknown filetype: " + filetype + ", defaulting to raw").
        set writer to fsModule:type:raw:writeHandler.
    } else {
        set writer to fsModule["type"][filetype]["writeHandler"].
    }

    if doLog logger:debug("Handler exists for " + filetype). 
    if doLog logger:debug("Write handler for filetype is " + writer).

    if writer:isType("UserDelegate") {
        if doLog logger:debug("Write handler is valid delegate. Executing delegate").
        writer(data, filename, vol).
    }
    else 
        if doLog logger:warn("Writing is not supported for filetype: " + filetype).
}.

set fsModule:toPathString to {
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
set fsModule:toPath to toPath@.

// visits all file and folder descriptors (recursively) in the start directory, and feeds them to the callback
local function walk {
    parameter vol.
    parameter start.
    parameter callback.

    set start to toPath(start).
    if not start:isType("Path") return.

    logger:debug("Beginning walk of " + vol + ", " + start + ", " + callback).

    local dir is vol:open(fsModule:toPathString(start)).
    logger:debug("invoking callback for " + dir).
    callback(dir).

    for descriptor in dir:lex:values {
        if not descriptor:isFile {
            logger:debug("recursing into directory " + descriptor).
            walk(vol, fsModule:toPathString(path(descriptor)), callback).
        } else {
            logger:debug("invoking callback for " + descriptor).
            callback(descriptor).
        }
    }

    logger:debug("Ending walk of " + vol + ", " + start + ", " + callback).
}

set fsModule:walk to walk@.

set fsModule:visitor to {
    parameter filter, callback, f.

    if f:isFile {
        if filter(f) callback(f).
    }
}.

// visits all files (recursively) in the start directory. If it is accepted by the filter, then it is fed to the callback
set fsModule:visit to {
    parameter vol.
    parameter start.
    parameter filter.
    parameter callback.

    logger:debug("beginning visit to " + vol + ", " + start + ", " + filter + ", " + callback).

    walk(vol, start, fsModule:visitor@:bind(filter, callback)).
}.

set fsModule:pathAfter to {
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

set fsModule:copyOnly to {
    parameter f, src, tgt, srcVol, tgtVol. 

    logger:debug("performing copy-only from " + srcVol:name + ":" + src + ", to " + tgtVol:name + ":" + tgt).

    copyPath(srcVol:name + ":" + src, tgtVol:name + ":" + tgt).
}.

set fsModule:appendOrCopy to {
    parameter f, src, tgt, srcVol, tgtVol.

    local ext is path(src):extension.
    if fsModule:type:hasKey(ext) {
        local append is fsModule["type"][ext]["appendHandler"].

        //if file type is appendable, then append
        if append:isType("UserDelegate") {
            append(f, tgt, tgtVol).
            return.
        }
    }
    //copy if not appendable, or file type not recognized
    copyPath(srcVol:name + ":" + src, tgtVol:name + ":" + tgt).
}.

set fsModule:copyDir to {
    parameter src, tgt.
    parameter accept is {parameter f. return true.}.
    parameter onAccept is fsModule:copyOnly@.
    parameter srcVol is archive.
    parameter tgtVol is core:volume.

    local copier is {
        parameter f.

        logger:debug("Performing copy operation on " + fs:toPathString(path(f))).
        logger:debug("src: " + src + ", tgt: " + tgt + ", srcVol: " + srcVol:name + ", tgtVol: " + tgtVol:name).

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


set fsModule:compile to {
    parameter vol, retVol, start.

    local compiler is {
        parameter f.
        switch to vol.
        compile fs:toPathString(path(f)).
        switch to retVol.
    }.

    fsModule:visit(vol, start, fsModule:isSrc@, compiler@).
}.

set fsModule:is to {
    parameter type, f.

    local filePath is path(f).

    logger:debug(fsModule:toPathString(filePath) + " is of file type " + type + ": " + (filePath:extension = type)).
    return filePath:extension = type.
}.

set fsModule:in to {
    parameter types, f.

    local filePath is path(f).

    logger:debug(fsModule:toPathString(filePath) + " is in file type list " + types + ": " + (types:contains(filePath:extension))).

    return types:contains(filePath:extension).
}.

set fsModule:isSrc to fsModule:is@:bind(fsModule:type:ks:ext).
set fsModule:isCompiled to fsModule:is@:bind(fsModule:type:ksm:ext).
set fsModule:dataTypes to list(fsModule:type:txt:ext, fsModule:type:raw:ext, fsModule:type:json:ext, fsModule:type:csv:ext).
set fsModule:isData to fsModule:in@:bind(fsModule:dataTypes).

set fsModule:printTree to {
    parameter vol, start.
    walk(vol, start, logger:info@).
}.

global fs is fsModule.
register("fs", fs, {return defined fs.}).