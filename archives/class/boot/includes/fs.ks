//optional dependency on 'persist' - enables json file types

//////////////////
// Initialize Filesystem
//////////////////

global fs is lex().

//for enabling non-logger based debug statements.
//useful for boot and logging debugging
set fs:debug to false. 

set fs:type to lex().

set fs:addFileType to {
    parameter ext, writeHandler, appendHandler is false.

    if fs:debug print "Adding file handler for " + ext + " writeHandler: " + writeHandler + " appendHandler: " + appendHandler.
    local type is lex().
    set type:ext to ext.
    set type:writeHandler to writeHandler.
    set type:appendHandler to appendHandler.

    fs:type:add(ext, type).
}.

local function defaultAppendHandler {
    parameter f, filename, vol.

    if fs:debug {
        print "executing default append handler".
        print "appending to " + vol:name + ":" + filename.
        print "write target: " + vol:open(filename).
        print "copying contents of " + f.
        print f:readall().
    }
    vol:open(filename):write(f:readall()).
}

fs:addFileType(
    "txt", 
    {
        parameter data.
        parameter filename.
        parameter vol.

        if fs:debug {
            print "writing contents to " + vol:name + ":" + filename.
            print "data size: " + data:length + " free space: " + vol:freespace.
            print "raw data: " + data.
            print "write target: " + vol:open(filename).
        }

        if vol:freespace = -1 or vol:freespace > data:length {
            vol:open(filename):writeln(data).
        } else {
            print "ERROR: Out Of Memory!".
        }
    },
    defaultAppendHandler@
).

fs:addFileType(
    "raw",
    {
        parameter data.
        parameter filename.
        parameter vol.

        if fs:debug {
            print "writing contents to " + vol:name + ":" + filename.
            print "data size: " + data:length + " free space: " + vol:freespace.
            print "raw data: " + data.
            print "write target: " + vol:open(filename).
        }

        if vol:freespace = -1 or vol:freespace > data:length {
            vol:open(filename):write(data).
        }
    },
    defaultAppendHandler@
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
    print "Invalid object! Expected: String | Lexicon | Enumerable".
    return false.
}

fs:addFileType(
    "csv",
    {
        parameter data.
        parameter filename.
        parameter vol.

        if fs:debug {
            print "writing contents to " + vol:name + ":" + filename.
            print "data size: " + data:length + " free space: " + vol:freespace.
            print "raw data: " + data.
            print "formatted data: " + toCSVLine(data).
            print "write target: " + vol:open(filename).
            print "invoking txt:writeHandler".
        }

        fs:type:txt:writeHandler(toCSVLine(data), filename, vol).
    },
    defaultAppendHandler@
).

fs:addFileType(
    "json",
    {
        parameter data.
        parameter filename.
        parameter vol.

        //skip size calculations (and by extension persist) if writing to archive
        if vol = archive {
            if fs:debug print "Target volume is Archive. Skipping size calculations and writing directly".
            writejson(data, vol:name + ":" + filename).
            return.
        }

        if not (defined persist) {
            print "Cannot write json! Requires 'persist' module to be loaded".
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

        if fs:debug {
            print "writing contents to " + vol:name + ":" + filename.
            print "data size: " + dataSize + " free space: " + vol:freespace.
            print "raw data: " + data.
            print "write target: " + vol:open(filename).
            print "json specific debug logging not implemented yet".
        }

        // compare the size of the old file to the size of the new one and store it
        local filesize is vol:open(filename):size.
        writejson(data, vol:name + ":" + filename).
        persist:get("jsonSizes")[filename]:add(vol:open(filename):size - filesize).
    },
    false //not appendable
).

fs:addFileType("ks", false, false). //not writable. not appendable
fs:addFileType("ksm", false, false). //not writable. not appendable

set fs:write to {
    parameter data.
    parameter filename is "/data/log".
    parameter filetype is fs:type:txt:ext.
    parameter vol is core:volume.

    if not filename:endswith("." + filetype) set filename to filename + "." + filetype.

    if fs:debug print "Writing data to " + vol:name + ":" + filename.

    if not vol:exists(filename) {
        if fs:debug print "File does not exist; creating emtpy file.".
        vol:create(filename).
    }

    if fs:debug print "Loading file handler for " + filetype.

    //get handler for extension and invoke write handler
    if fs:type:hasKey(filetype) {

        local writer is fs["type"][filetype]["writeHandler"].

        if fs:debug {
            print "Handler exists for " + filetype. 
            print "Write handler for filetype is " + writer.
        }

        if writer:isType("UserDelegate") {
            if fs:debug print "Write handler is valid delegate. Executing delegate".
            writer(data, filename, vol).
        }
        else 
            print "WARNING: Writing is not supported for filetype: " + filetype.
    } else {
        print "ERROR: Unknown filetype: " + filetype.
    }
}.

set fs:toPathString to {
    parameter p.

    local result is "".
    for segment in p:segments {
        set result to result + "/" + segment.
    }
    return result.
}.

local function walk {
    parameter vol.
    parameter start.
    parameter callback.

    if start:isType("VolumeItem") set start to path(start).
    if start:isType("Path") set start to fs:toPathString(start).

    if defined console console:debug("Beginning walk of " + vol + ", " + start + ", " + callback).

    local dir is vol:open(start).
    if defined console console:debug("invoking callback for " + dir).
    callback(dir).

    for descriptor in dir:lex:values {
        if defined console console:debug("invoking callback for " + descriptor).
        callback(descriptor).
        if not descriptor:isFile {
            if defined console console:debug("recursing into directory " + descriptor).
            walk(vol, fs:toPathString(path(descriptor)), callback).
        }
    }

    if defined console console:debug("Ending walk of " + vol + ", " + start + ", " + callback).
}.

set fs:walk to walk@.

set fs:visitor to {
    parameter filter, callback, f.

    if f:isFile {
        if filter(f) callback(f).
    }
}.

// visits all files (recursively) in the start directory. If it is accepted by the filter, then it is fed to the callback
set fs:visit to {
    parameter vol.
    parameter start.
    parameter filter.
    parameter callback.

    if defined console console:debug("beginning visit to " + vol + ", " + start + ", " + filter + ", " + callback).

    walk(vol, start, fs:visitor@:bind(filter, callback)).
}.

set fs:pathAfter to {
    parameter child, parent.

    local childPath is path(child).
    local parentPath is path(parent).
    local result is "".

    for segment in childPath:segments:sublist(parentPath:segments:length, childPath:segments:length - parentPath:segments:length) {
        set result to result + "/" + segment.
    }

    return result.
}.

set fs:copyOnly to {
    parameter f, src, tgt, srcVol, tgtVol. 
    copyPath(srcVol:name + ":" + src, tgtVol:name + ":" + tgt).
}.

set fs:appendOrCopy to {
    parameter f, src, tgt, srcVol, tgtVol.

    local ext is path(src):extension.
    if fs:type:hasKey(ext) {
        local append is fs["type"][ext]["appendHandler"].

        //if file type is appendable, then append
        if append:isType("UserDelegate") {
            append(f, tgt, tgtVol).
            return.
        }
    }
    //copy if not appendable, or file type not recognized
    copyPath(srcVol:name + ":" + src, tgtVol:name + ":" + tgt).
}.

set fs:copyDir to {
    parameter src, tgt.
    parameter accept is {return true.}.
    parameter onAccept is fs:copyOnly@.
    parameter srcVol is archive.
    parameter tgtVol is core:volume.

    local srcDir is path(src).

    local copier is {
        parameter f.

        local srcPath is src + fs:pathAfter(path(f), srcDir).
        local tgtPath is tgt + fs:pathAfter(path(f), srcDir).

        if f:isFile {
            if accept(f) {
                onAccept(f, srcPath, tgtPath, srcVol, tgtVol).
            }
        } else {
            if not tgtVol:exists(tgtPath) {
                tgtVol:createDir(tgtPath).
            }
        }
    }.

    walk(srcVol, src, copier).
}.


set fs:compile to {
    parameter vol, start.

    local compiler is {
        parameter f.
        compile path(f).
    }.

    fs:visit(vol, start, fs:isSrc@, compiler@).
}.

set fs:type:is to {
    parameter type, f.

    local filePath is path(f).

    if defined console console:debug(fs:toPathString(filePath) + " is of file type " + type + ": " + (filePath:extension = type)).
    return filePath:extension = type.
}.

set fs:type:in to {
    parameter types, f.

    local filePath is path(f).

    if defined console console:debug(fs:toPathString(filePath) + " is in file type list " + types + ": " + (types:contains(filePath:extension))).

    return types:contains(filePath:extension).
}.

set fs:isSrc to fs:type:is@:bind(fs:type:ks:ext).
set fs:isCompiled to fs:type:is@:bind(fs:type:ksm:ext).
set fs:dataTypes to list(fs:type:txt:ext, fs:type:raw:ext, fs:type:json:ext, fs:type:csv:ext).
set fs:isData to fs:type:in@:bind(fs:dataTypes).

set fs:printTree to {
    parameter vol, start.
    if defined console {
        walk(vol, start, console:info@).
    }
}.

modules:add("fs", fs).