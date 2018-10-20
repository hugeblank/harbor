-- HARBOR - By hugeblank
-- Like docker, but bad and for a very specific group of people.
if not drive_id then
    _G.drive_id = 0 -- Globally keep track of the hvfs volume IDs
end

mountString = function(treeString) -- Mount a container string
    local treeTbl = textutils.unserialize(treeString)
    if treeTbl and type(treeTbl.tree) == "table" and type(treeTbl.meta) == "table" then -- If it unserialized, set the container and meta variables
        local container = treeTbl.tree -- Tree
        local meta = treeTbl.meta -- Tree meta information (read only, etc.)
        local combine = _G.fs.combine
        local fsys = {} -- Mountable File system functions
        local vfs_id = drive_id -- vfs drive ID
        drive_id = drive_id+1 -- Adding 1 to it for the next mount

        local function formatDir(str) -- Formats a directory path to a table
            local dir = {}
            str = combine(str, "").."/" -- use fs.combine magic
            while str ~= "" do -- iterate over each /
                local pos = str:find("/")
                dir[#dir+1] = str:sub(1, pos-1) -- add directory/file to table
                str = str:sub(pos+1, -1) -- remove it and the '/' off the string
            end
            if dir[1] == "" then -- If the path is / this happens so just remove it.
                table.remove(dir)
            end
            return dir
        end

        local function genDir(tree, meta, temp) -- Generates/follows a path and returns it
            local path = {}
            for i = 1, #temp do
                path[i] = temp[i]
            end
            if #path == 0 then -- If the end of the path is reached exit
                return tree, meta
            end
            if not tree[ path[1] ] then -- If there isn't a directory in path, make it
                tree[ path[1] ] = {}
            end
            local temp = tree[ path[1] ]
            if type(temp) == "string" then -- If selected path is a file return the table it's in so that it can be edited
                return tree, meta
            end
            if meta and meta[ path[1] ] then -- If there is a meta for this path let's check it
                if meta.readOnly then -- If it's read only let's stop right here, we can't descend any deeper.
                    return false
                end
                meta = meta[ path[1] ] -- Continue deeper into the meta tree
            end
            table.remove(path, 1) -- remove the path from the stack
            return genDir(temp, meta, path)
        end

        local function exists(dir) -- Check if a directory/file exists and return it
            local harbor = container
            for i = 1, #dir do
                if harbor[dir[i]] then -- If the next directory exists in the currently scoped directory, set the currently scoped dir to it
                    harbor = harbor[dir[i]]
                else -- Otherwise exit
                    return false
                end
            end
            return true, harbor -- Return successful and provide the directory table.
        end

        local function checkPaths(pathStr) -- Check the read only meta information of the contents below this location
            if fsys.exists(pathStr) and fsys.isDir(pathStr) then -- If exists and is a directory
                local list = fsys.list(pathStr) -- List it
                for i = 1, #list do
                    if fsys.isReadOnly(pathStr) then -- If this directory read only exit
                        return false, pathStr
                    end
                    return checkPaths(pathStr.."/"..list[i]) -- Recursion! Check the contents of this directory
                end
            else
                if fsys.isReadOnly(pathStr) then -- If this file is read only exit
                    return false, pathStr
                end
            end
        end

        fsys.exists = function(path) -- Check if path exists within the container
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path)
            local out = exists(dir)
            return out
        end
        
        fsys.isDir = function(path) -- Check if a directory exists within the container
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path)
            local ex, harbor = exists(dir)
            if ex then 
                return type(harbor) == "table" -- Check if path is a table
            else
                return ex
            end
        end
        
        fsys.isReadOnly = function(path) -- Check if the file/directory is read only. If a parent is read only, everything else contained will be too
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path)
            local ex = exists(dir)
            if ex then 
                local i = #dir
                while i > 1 do -- Check read only status of path leading up to the end
                    if meta[dir[i]] then
                        if meta[dir[i]].readOnly then
                            return true
                        end
                    end
                    i = i-1
                end
                return false
            else
                return ex
            end
        end
        
        fsys.getName = function(path) -- Gets the name of the last path component
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path) 
            if #dir == 0 then -- If this is the root directory, return root. shocker.
                return "root"
            else
                return dir[#dir]
            end
        end
        
        fsys.getDrive = function(path) -- Gets the name of the drive path is in
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path)
            if dir[1] == "rom" and fsys.exists(path) then -- If the drive is read only memory, return rom
                return "rom"
            elseif fsys.exists(path) then -- Otherwise return hvfs(id). hvfs stands for Harbor Virtual File System
                return "hvfs"..vfs_id
            end
        end

        fsys.getFreeSpace = function() -- Gets the free space of the computer
            return "unlimited" -- It's a variable so I'm not wrong... 
            --but there's some potential here for a meta "size" functionality that limits the amount of data allocated to each directory
        end

        fsys.getSize = function(path) -- Gets the size of the file at path
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path)
            local ex, file = exists(dir)
            if ex then
                return #file -- Length of file == Amount of bytes
            else
                error("/"..table.concat(dir, "/")..": No such file", 2)
            end
        end
         
        fsys.list = function(path) -- Lists the contents of path
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)..")")
            end
            local dir = formatDir(path)
            local ex, path = exists(dir)
            if not ex then
                error("/"..table.concat(dir, "/")..": Not a directory", 2)
            end
            if type(path) == "table" then --if the path is a table, read the keys into a table and return it
                local out = {}
                for k, _ in pairs(path) do 
                    out[#out+1] = k
                end
                return out
            else
                error("/"..table.concat(dir, "/")..": Not a directory", 2)
            end
        end

        fsys.getDir = function(path) -- Gets the parent directory of path
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path)
            if #dir > 1 then -- If it's not just '/' iterate over each path directory, adding it to the string
                local str = dir[1]
                for i = 2, #dir-1 do 
                    str = str.."/"..dir[i]
                end
                return str
            elseif #dir == 0 then -- Following convention. '/' returns '..'
                return ".."
            else
                return ""
            end
        end

        fsys.makeDir = function(path) -- Makes a new directory at path
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path)
            local tree = genDir(container, meta, dir)
            if not tree then
                error("/"..table.concat(dir, "/")..": Access denied", 2)
            end
        end

        fsys.move = function(fromPath, toPath) -- Move a directory from one place to another while also obeying read only laws
            if type(fromPath) ~= "string" then
                error("bad argument #1 (string expected, got "..type(fromPath)")", 2)
            elseif type(toPath) ~= "string" then
                error("bad argument #2 (string expected, got "..type(toPath)")", 2)
            end
            local fromPath = formatDir(fromPath)
            local toPath = formatDir(toPath)
            if not exists(fromPath) then -- Checking existence
                error("No such file", 2)
            elseif exists(toPath) then
                error("File exists", 2)
            end
            local toTree = genDir(container, meta, toPath) -- Scoping to directories
            local fromTree = genDir(container, meta, fromPath)
            if not toTree then -- Bad touch
                error(error("/"..table.concat(toPath, "/")..": Access denied", 2))
            elseif not fromTree then
                error("/"..table.concat(fromPath, "/")..": Access denied", 2)
            end
            local pass, pstr = checkPaths(table.concat(dir, "/"))
                if not pass then -- Make sure all contents are not read only
                    error(pstr..": Access denied", 2)
                end
            for k, v in pairs(fromTree) do
                toTree[k] = v
            end
            local dirName = table.remove(fromPath)
            local stepUp = genDir(container, meta, fromPath)
            stepUp[dirName] = nil
        end

        fsys.copy = function(fromPath, toPath) -- Copy a directory from one place to another while also obeying the read only laws of the land
            if type(fromPath) ~= "string" then
                error("bad argument #1 (string expected, got "..type(fromPath)")", 2)
            elseif type(toPath) ~= "string" then
                error("bad argument #2 (string expected, got "..type(toPath)")", 2)
            end
            local fromPath = formatDir(fromPath)
            local toPath = formatDir(toPath)
            if not exists(fromPath) then
                error("No such file", 2)
            elseif exists(toPath) then
                error("File exists", 2)
            end
            local toTree = genDir(container, meta, toPath)
            local fromTree = genDir(container, meta, fromPath)
            if not toTree then
                error(error("/"..table.concat(toPath, "/")..": Access denied", 2))
            end
            for k, v in pairs(fromTree) do -- Moving it all
                toTree.k = v
            end
        end

        fsys.delete = function(path) -- Delete a file or directory on the condition that it and its contents aren't read only
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            end
            local dir = formatDir(path)
            if exists(dir) then
                local tree = genDir(container, meta, dir)
                if not tree then
                    error("/"..table.concat(dir, "/")..": Access denied", 2)
                end
                local pass, pstr = checkPaths(table.concat(dir, "/"))
                if not pass then -- Make sure all contents are not read only
                    error(pstr..": Access denied", 2)
                end
                local dirName = table.remove(dir) -- Scope up one, and set the key to nil
                local stepUp = genDir(container, meta, dir)
                stepUp[dirName] = nil
            end
        end

        fsys.combine = combine -- Combine two paths to make a single coherent path string

        fsys.find = function(wildcard) -- Find a path/paths to a file using wildcard magic
            if type(wildcard) ~= "string" then
                error("bad argument #1 (string expected, got "..type(wildcard)")", 2)
            end
            wildcard = table.concat(formatDir(wildcard), "/") -- Body donated to harbor by gollark, from PotatOS, and apparently indirectly from cclite:
            local function recurse_spec(results, path, spec) -- From here: https://github.com/Sorroko/cclite/blob/62677542ed63bd4db212f83da1357cb953e82ce3/src/emulator/native_api.lua
                local segment = spec:match('([^/]*)'):gsub('/', '')
                local pattern = '^' .. segment:gsub('[*]', '.+'):gsub('?', '.') .. '$'
     
                if fsys.isDir(path) then
                    for _, file in ipairs(fsys.list(path)) do
                        if file:match(pattern) then
                            local f = fsys.combine(path, file)
     
                            if fsys.isDir(f) then
                                recurse_spec(results, f, spec:sub(#segment + 2))
                            end
                            if spec == segment then
                                table.insert(results, f)
                            end
                        end
                    end
                end
            end
            local results = {}
            recurse_spec(results, '', wildcard)
            return results
        end

        fsys.complete = function(str, path, files, slashes) -- Provide a table of suggetions for the string given based off of what is in the path
            if type(str) ~= "string" then
                error("bad argument #1 (string expected, got "..type(str)")", 2)
            elseif type(path) ~= "string" then
                error("bad argument #2 (string expected, got "..type(path)")", 2)
            end
            if files == nil then files = true end -- Making sure files and slashes are set to default, true
            if slashes == nil then slashes = true end
            local out = {}
            local ex, tree = exists(formatDir(path))
            if ex then
                for k, v in pairs(tree) do -- for each key that can complete the string, remove the partial string, add to table
                    local ma, mb = k:find(str)
                    if ma == 1 then
                        if type(v) == "table" or files then
                            out[#out+1] = k:sub(mb+1, -1)
                            if slashes then
                                out[#out+1] = k:sub(mb+1, -1).."/"
                            end
                        end

                    end
                end
            end
            return out
        end

        fsys.open = function(path, mode) -- Open a file
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)")", 2)
            elseif type(mode) ~= "string" then
                error("bad argument #2 (string expected, got "..type(mode)")", 2)
            end
            local path = formatDir(path)
            local harbor = container
            local closed = false
            if mode == "r" then
                for i = 1, #path do -- Scope down into the file, stop before the file name is reached because immutable strings are immutable
                    if harbor[ path[i] ] then
                        harbor = harbor[ path[i] ]
                    else 
                        return nil
                    end
                end
                local start = 1
                local file = harbor

                local rTable = { -- Table for reading files
                    close = function()
                        closed = true
                    end,
                    read = function(num)
                        if closed then 
                            error("attempt to use closed file", 2)
                        end
                        if not num then num = 1 end
                        local out = file:sub(start, num)
                        start = start + num
                        if start < #file then
                            return out
                        else
                            return nil
                        end
                    end,
                    readAll = function()
                        if closed then 
                            error("attempt to use closed file", 2)
                        end
                        local out = file:sub(start, -1)
                        start = #file
                        return out
                    end,
                    readLine = function()
                        if closed then 
                            error("attempt to use closed file", 2)
                        end
                        local out = file:sub(start, -1)
                        local loc = out:find("\n")
                        if loc then
                            start = start + loc
                        end
                        local str = out:sub(start, loc)
                        if str == "" then
                            return nil
                        else
                            return str
                        end
                    end
                }
                return rTable
            elseif mode == "w" or mode == "a" then
                local fileName = table.remove(path) -- Remove the file so genDir doesn't assume its type as a table and scope into it (Did you just assume my genDir?!)
                local dir, meta = genDir(harbor, meta, path) -- Path to the directory
                path[#path] = fileName -- United again
                local buffer = ""
                local buffed = false -- Prevent write mode flushing overwriting the already saved buffer
                if not dir then
                    return nil
                elseif meta and meta.fileName and meta.fileName.readOnly then
                    return nil
                end
                local wTable = { -- Table for writing files
                    flush = function()
                        if closed then 
                            error("attempt to use closed file", 2)
                        end
                        if mode == "w" and not buffed then
                            dir[fileName] = buffer
                            buffed = true
                        else
                            dir[fileName] = dir[fileName]..buffer
                        end
                    end,
                    close = function()
                        if not closed then
                            if mode == "w" then
                                dir[fileName] = buffer
                            else
                                dir[fileName] = dir[fileName]..buffer
                            end
                        end
                        closed = true
                    end,
                    write = function(str)
                        buffer = buffer..str
                    end,
                    writeLine = function(str)
                        write(str.."\n")
                    end
                }
                return wTable
            end
        end
        return {fs = fsys, dir = treeTbl}
    else -- Or error
        error("Invalid harbor object", 2)
    end
end

mountFile = function(treePath) -- Mount a container file
    if fs.exists(treePath) and not fs.isDir(treePath) then -- Check it actually exists and isn't a directory
        local harbor = fs.open(treePath, "r") -- Read it
        local tree = harbor:readAll()
        harbor:close()
        return mountString(tree) -- Mount it as a string
    else -- Or error
        error("Path to harbor is not a valid file or does not exist", 2)
    end
end

convert = function(path)
    path = fs.combine(path, "")
    local function r(path, har, met, orig)
        local _, pos = path:find(orig)
        local relPath = path:sub(pos, -1)
        local list = fs.list(path)
        local tree = {}
        local meta = {}
        for i = 1, #list do
            if fs.isReadOnly(path.."/"..list[i]) then
                local m
                local str = ""
                if relPath ~= "" then
                    str = relPath.."/"..list[i].."/"
                else
                    str = list[i].."/"
                end
                while str ~= "" do 
                    local pos = str:find("/")
                    local k = str:sub(1, pos-1)
                    meta[k] = {}
                    m = meta[k]
                    str = str:sub(pos+1, -1)
                end
                m.readOnly = true
            end
            if fs.isDir(path.."/"..list[i]) then
                tree[ list[i] ], meta[ list[i] ] = r(path.."/"..list[i], tree, meta, orig)
            else
                local file = fs.open(path.."/"..list[i], "r")
                tree[ list[i] ] = file:readAll()
                meta[ list[i] ] = {} -- For consistencies sake
                file:close()
            end
        end
        return tree, meta
    end
    local tree, meta = r(path, {}, {}, path)
    return textutils.serialize({tree=tree, meta=meta})
end

bootVFS = function(hvfs)
    if type(hvfs) ~= "table" then
        error("bad argument #1 (table expected, got "..type(hvfs)..")", 2)
    end
    for k, _ in pairs(_G.fs) do
        if not hvfs.fs[k] then
            error("invalid harbor virtual filesystem API", 2)
        end
    end
    if fs.exists("/startup.lua") then
        fs.move("/startup.lua", "/.harbor/startup.lua") -- Move your oh so precious startup out of the way
    end
    file = fs.open("/startup.lua", "w") -- Write our not so precious startup file where yours once was
    --[[READABLE FORMAT of startup.lua
        local hvfs = textutils.serialize({*insert your hvfs here*}) -- Serialize the table given by the serialized table hvfs.dir in parent creator
        os.loadAPI('/harbor.lua') -- Load up harbor for a moment
        local out = harbor.mountString(hvfs) -- Mount the VFS
        os.unloadAPI('harbor.lua') -- Begone Harbor!
        if term.isColor() then -- If this is an advanced computer
            os.run({},'/.harbor/multishell.lua') -- Run harbor's modified multishell environment
        end
        os.run({}, '/.harbor/shell.lua') -- Run harbor's modified shell environment
        fs.move('/.harbor/startup.lua', '/startup.lua') -- Move your oh so preciousl startup back to its rightful position, overwriting this file
        _G.fs = out.fs -- Set the global FS to the VFS
        shell.run('/startup.lua') -- Run the startup file in the VFS (there better be one)
        os.reboot() -- Reboot when execution has been completed
    ]]
    file.write("local hvfs = textutils.serialize("..textutils.serialize(hvfs.dir)..")\nos.loadAPI('/harbor.lua')\nlocal out = harbor.mountString(hvfs)\nos.unloadAPI('harbor.lua')\nif term.isColor() then\n  os.run({},'/.harbor/multishell.lua')\nend\nos.run({}, '/.harbor/shell.lua')\nfs.delete('/startup.lua')\nif fs.exists('/.harbor/startup.lua') then\n  fs.move('/.harbor/startup.lua', '/startup.lua')\nend\n_G.fs = out.fs\nshell.run('/startup.lua')\nos.reboot()")
    file.close()
    os.reboot() -- Let's begin execution
end
