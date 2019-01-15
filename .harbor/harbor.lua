-- Harbor - By hugeblank

local harbor = {}
harbor.mountTable = function(treeTbl) -- Mount a harbor table
    if treeTbl and type(treeTbl.tree) == "table" and type(treeTbl.meta) == "table" then -- If it unserialized, set the container and meta variables
        local container = treeTbl.tree -- Tree
        local meta = treeTbl.meta -- Tree meta information (read only, etc.)
        local combine = _G.fs.combine -- fs.combine ain't anything crazy
        local fsys = {} -- Mountable File system functions

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
            if fsys.isDir(pathStr) then -- If exists and is a directory
                local list = fsys.list(pathStr) -- List it
                for i = 1, #list do
                    if fsys.isReadOnly(pathStr) then -- If this directory is read only, exit
                        return false, pathStr
                    end
                    return ({checkPaths(pathStr.."/"..list[i])})[1], pathStr -- Recursion! Check the contents of this directory
                end
            else
                if fsys.isReadOnly(pathStr) then -- If this file is read only, exit
                    return false, pathStr
                end
            end
            return true, pathStr
        end

        fsys.exists = function(path) -- Check if path exists within the container
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
            end
            local dir = formatDir(path)
            local out = exists(dir)
            return out
        end
        
        fsys.isDir = function(path) -- Check if a directory exists within the container
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
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
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
            end
            local dir = formatDir(path)
            local ex = exists(dir)
            if ex then 
                local i = #dir
                while i > 0 do -- Check read only status of path leading up to the end
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
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
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
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
            end
            local dir = formatDir(path)
            if dir[1] == "rom" and fsys.exists(path) then -- If the drive is read only memory, return rom
                return "rom"
            elseif fsys.exists(path) then -- Otherwise return hvfs. hvfs stands for Harbor Virtual File System
                return "hvfs"
            end
        end

        fsys.getFreeSpace = function() -- Gets the free space of the computer
            return 0 -- It's a variable so I'm not wrong... 
            --but there's some potential here for a meta "size" functionality that limits the amount of data allocated to each directory
        end

        fsys.getSize = function(path) -- Gets the size of the file at path
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
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
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
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
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
            end
            local dir = formatDir(path)
            local tree = genDir(container, meta, dir)
            if not tree then
                error(fs.combine(table.concat(dir, "/"), "")..": Access denied", 2)
            end
        end

        fsys.move = function(fromPath, toPath) -- Move a directory from one place to another while also obeying read only laws
            if type(fromPath) ~= "string" then
                error("bad argument #1 (string expected, got "..type(fromPath)..")", 2)
            elseif type(toPath) ~= "string" then
                error("bad argument #2 (string expected, got "..type(toPath)..")", 2)
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
                error(error(fs.combine(table.concat(toPath, "/"), "")..": Access denied", 2))
            elseif not fromTree then
                error(fs.combine(table.concat(fromPath, "/"), "")..": Access denied", 2)
            end
            local pass, pstr = checkPaths(table.concat(dir, "/"))
                if not pass then -- Make sure all contents are not read only
                    error(fs.combine(pstr, "")..": Access denied", 2)
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
                error("bad argument #1 (string expected, got "..type(fromPath)..")", 2)
            elseif type(toPath) ~= "string" then
                error("bad argument #2 (string expected, got "..type(toPath)..")", 2)
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
                error(fs.combine(table.concat(toPath, "/"), " ")..": Access denied", 2)
            end
            for k, v in pairs(fromTree) do -- Moving it all
                toTree.k = v
            end
        end

        fsys.delete = function(path) -- Delete a file or directory on the condition that it and its contents aren't read only
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
            end
            local dir = formatDir(path)
            if exists(dir) then
                local tree = genDir(container, meta, dir)
                if not tree then
                    error(fs.combine(table.concat(dir, "/"), "")..": Access denied", 2)
                end
                local pass, pstr = checkPaths(table.concat(dir, "/"))
                if not pass then -- Make sure all contents are not read only
                    error(fs.combine(pstr, "")..": Access denied", 2)
                end
                local dirName = table.remove(dir) -- Scope up one, and set the key to nil
                local stepUp = genDir(container, meta, dir)
                stepUp[dirName] = nil
            end
        end

        fsys.combine = combine -- Combine two paths to make a single coherent path string

        fsys.find = function(wildcard) -- Find a path/paths to a file using wildcard magic
            if type(wildcard) ~= "string" then
                error("bad argument #1 (string expected, got "..type(wildcard)..")", 2)
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
                error("bad argument #1 (string expected, got "..type(str)..")", 2)
            elseif type(path) ~= "string" then
                error("bad argument #2 (string expected, got "..type(path)..")", 2)
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
                            if slashes then
                                out[#out+1] = k:sub(mb+1, -1).."/"
                            end
                            out[#out+1] = k:sub(mb+1, -1)
                        end

                    end
                end
            end
            return out
        end

        fsys.open = function(path, mode) -- Open a file
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)..")", 2)
            elseif type(mode) ~= "string" then
                error("bad argument #2 (string expected, got "..type(mode)..")", 2)
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
                        local loc = out:find('\n')
                        local str = ""
                        if loc then
                            str = out:sub(1, loc-1)
                            start = start + loc
                            return str
                        else
                            start = #file+1
                            if out ~= "" then
                                return out
                            end
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
                        buffer = buffer..str.."\n"
                    end
                }
                return wTable
            end
        end
        return fsys
    else -- Or error
        error("Invalid harbor object", 2)
    end
end

harbor.mountString = function(treeString) -- Mount a container string 
    return harbor.mountTable(textutils.unserialize(treeString))
end

harbor.mountFile = function(treePath) -- Mount a container file
    if fs.exists(treePath) and not fs.isDir(treePath) then -- Check it actually exists and isn't a directory
        local harbor = fs.open(treePath, "r") -- Read it
        local tree = harbor:readAll()
        harbor:close()
        return mountString(tree) -- Mount it as a string
    else -- Or error
        error("Path to harbor is not a valid file or does not exist", 2)
    end
end

harbor.convert = function(path) -- Convert a directory path into a harbor tree and meta table for VFS mounting
    path = fs.combine(path, "") -- Make the path a program readable path
    local function r(path, har, met, orig) -- Recursive function taking in the path table, current tree, current meta, and the original path to compare to
        local _, pos = path:find(orig) -- Find where the base path is in relation to the actual path string
        local relPath = path:sub(pos, -1) -- Remove it to get the relative path
        local list = fs.list(path) -- List all the contents on path
        local tree = {} -- Blank tree table
        local meta = {} -- Blank meta table
        for i = 1, #list do -- for each thing in list
            if fs.isDir(path.."/"..list[i]) then -- If the thing is a directory
                tree[ list[i] ], meta[ list[i] ] = r(path.."/"..list[i], tree, meta, orig) -- Recurse into it
            else -- If the thing is a file
                local file = fs.open(path.."/"..list[i], "r") -- Open it
                tree[ list[i] ] = file:readAll() -- Read it into the tree as its name
                meta[ list[i] ] = {} -- For consistencies sake
                file:close() -- And close
            end
            if fs.isReadOnly(fs.combine(path, list[i])) then -- If it's read only
                meta[list[i]].readOnly = true -- Make it read only, shocker right?
            end
        end
        return tree, meta -- Return the completed tree and meta tables
    end
    local tree, meta = r(path, {}, {}, path) -- Get the base tree and meta tables
    return {tree=tree, meta=meta} -- Return the result as a virtual filesystem
end

harbor.revert = function(hfs, path) -- Convert a harbor virtual filesystem to a normal directory structure in the desired path
    path = fs.combine(path, "") -- Make the path a valid scopable string
    local function scope(path) -- Recursive function to scope into all parts of the file structure
        local stuff = hfs.list(path) -- List the contents in the directory
        for i = 1, #stuff do -- For each item
            local sPath = hfs.combine(path, stuff[i]) -- Combine the path with the item name
            if hfs.isDir(sPath) then -- If it's a directory
                scope(sPath) -- Scope into it
            else -- OTHERWISE
                local string = hfs.open(sPath, "r") -- Open the virtual file
                local file = fs.open(sPath, "w") -- Open a file in the parent fs
                file.write(string.readAll()) -- Write the contents of the virtual file to the parent file
                string.close() -- Close one
                file.close() -- And then the other
            end
        end
    end
    if not fs.isReadOnly(path) then
        scope(path) -- Scope into the desired path
        return true
    else
        return false
    end
end

return harbor