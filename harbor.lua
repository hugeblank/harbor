--[[ Hugeblank's bad enchat harbor
{
    tree = {
        .enchat = {
            settings = "{
                enchatSettings = ...
            }"
            api = {
                aes = "Someone else's bad code",
                skynet = "Gollark's bad code"
            }
        }
        enchat3beta = "LDD's bad code",
        json = "Someone else's bad API"
    }
    meta = {
        .enchat = { 
            readOnly = true -- I don't want this to be effed with.
        }
    }
}
]]

local drive_id = 0

mountString = function(treeString) -- Mount a container string
    local treeTbl = textutils.unserialize(treeString)
    if treeTbl and type(treeTbl.tree) == "table" and type(treeTbl.meta) == "table" then -- If it unserialized, set the container and meta variables
        local container = treeTbl.tree -- Tree
        local meta = treeTbl.meta -- Tree meta information (read only, etc.)
        local fsys = {} -- Mountable File system functions
        local vfs_id = drive_id -- vfs drive ID
        drive_id = drive_id+1 -- Adding 1 to it for the next mount

        local function formatDir(str)
            local dir = {}
            while true do
                local pos = str:find("/") or str:find("\\") or str:find("*") -- Find slashes and asterisks
                if pos == 1 then -- Remove leading slashes/asterisks
                    str = str:sub(2, -1)
                elseif pos then -- Add directory to list and remove it from the string
                    dir[#dir+1] = str:sub(1, pos-1)
                    str = str:sub(pos+1, -1)
                else -- Add remaning file/directory to list and return list
                    if str == ".." then
                        dir[#dir] = nil
                    else
                        dir[#dir+1] = str
                    end
                    for i = 1, #dir do
                        if dir[i] == "" then
                            table.remove(dir, i)
                        end
                        if dir[i] == ".." and dir[i-1] then
                            table.remove(dir, i-1)
                            table.remove(dir, i)
                        end
                    end
                    if dir[1] == "." then
                        table.remove(dir, 1)
                    end
                    return dir
                end
            end
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

        local function checkPaths(pathStr)
            local list = fsys.list(pathStr)
            for i = 1, #list do
                if fsys.isReadOnly(pathStr) then
                    error(pathStr..": Access denied", 3)
                end
                if fsys.isDir(pathStr.."/"..list[i]) then
                    checkPaths(pathStr.."/"..list[i])
                end
            end
        end

        fsys.exists = function(path) -- Check if path exists within the container
            local dir = formatDir(path)
            local out = exists(dir)
            return out
        end
        
        fsys.isDir = function(path) -- Check if a directory exists within the container
            local dir = formatDir(path)
            local ex, harbor = exists(dir)
            if ex then 
                return type(harbor) == "table"
            else
                return ex
            end
        end
        
        fsys.isReadOnly = function(path) -- Check if the file/directory is read only. If a parent is read only, everything else contained will be too
            local dir = formatDir(path)
            local ex = exists(dir)
            if ex then 
                local i = #dir
                while i > 1 do
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
            local dir = formatDir(path)
            if #dir == 0 then 
                return "root"
            else
                return dir[#dir]
            end
        end
        
        fsys.getDrive = function(path) -- Gets the name of the drive path is in
            local dir = formatDir(path)
            if dir[1] == "rom" and fsys.exists(path) then
                return "rom"
            elseif fsys.exists(path) then
                return "hvfs"..vfs_id
            end
        end

        fsys.getFreeSpace = function() -- Gets the free space of the computer
            return "unlimited" -- It's a variable so I'm not wrong... 
            --but there's some potential here for a meta "size" functionality that limits the amount of data allocated to each directory
        end

        fsys.getSize = function(path) -- Gets the size of the file at path
            local dir = formatDir(path)
            local ex, file = exists(dir)
            if ex then
                return #file
            else
                error("/"..table.concat(dir, "/")..": No such file", 2)
            end
        end
         
        fsys.list = function(path) -- Lists the path
            if type(path) ~= "string" then
                error("bad argument #1 (string expected, got "..type(path)..")")
            end
            local dir = formatDir(path)
            local ex, path = exists(dir)
            if not ex then
                error("/"..table.concat(dir, "/")..": Not a directory", 2)
            end
            if type(path) == "table" then
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
            local dir = formatDir(path)
            if #dir > 1 then
                local str = dir[1]
                for i = 2, #dir-1 do 
                    str = str.."/"..dir[i]
                end
                return str
            elseif #dir == 0 then
                return ".."
            else
                return ""
            end
        end

        fsys.makeDir = function(path) -- Makes a new directory at path
            local dir = formatDir(path)
            local tree = genDir(container, meta, dir)
            if not tree then
                error("/"..table.concat(dir, "/")..": Access denied", 2)
            end
        end

        fsys.move = function(fromPath, toPath) -- Move a directory from one place to another while also obeying read only laws
            local fromPath = formatDir(fromPath)
            local toPath = formatDir(toPath)
            if not exists(fromPath) then -- Checking existence
                error("No such file", 2)
            elseif exists(toPath) then
                error("File exists", 2)
            end
            local toTree = genDir(container, meta, toPath) -- Scoping to directory
            local fromTree = genDir(container, meta, fromPath)
            if not toTree then -- Bad touch
                error(error("/"..table.concat(toPath, "/")..": Access denied", 2))
            elseif not fromTree then
                error("/"..table.concat(fromPath, "/")..": Access denied", 2)
            end
            checkPaths(table.concat(fromPath, "/")) -- Make sure all contents are not read only
            for k, v in pairs(fromTree) do
                toTree[k] = v
            end
            local dirName = table.remove(fromPath)
            local stepUp = genDir(container, meta, fromPath)
            stepUp[dirName] = nil
        end

        fsys.copy = function(fromPath, toPath) -- Copy a directory from one place to another while also obeying the read only laws of the land
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
            for k, v in pairs(fromTree) do -- Then moving it all
                toTree.k = v
            end
        end

        fsys.delete = function(path) -- Delete a file or directory on the condition that it and its contents aren't read only
            local dir = formatDir(path)
            if exists(dir) then
                local tree = genDir(container, meta, dir)
                if not tree then
                    error("/"..table.concat(dir, "/")..": Access denied", 2)
                end
                checkPaths(table.concat(dir, "/")) -- Make sure all contents are not read only
                local dirName = table.remove(dir) -- Scope up one, and set the key to nil
                local stepUp = genDir(container, meta, dir)
                stepUp[dirName] = nil
            end
        end

        fsys.combine = function(pathA, pathB) -- Combine two paths to make a single coherent path string
            local dirA = formatDir(pathA)
            local dirB = formatDir(pathB)
            for i = 1, #dirB do 
                dirA[#dirA+1] = dirB[i]
            end
            return "/"..table.concat(dirA, "/")
        end

        fsys.find = function(wildcard) -- Find a path/paths to a file using wildcard magic
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
            if files == nil then files = true end
            if slashes == nil then slashes = true end
            local out = {}
            local ex, tree = exists(formatDir(path))
            if ex then
                for k, v in pairs(tree) do
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

                local rTable = {
                    close = function()
                        closed = true
                    end,
                    read = function(num)
                        if closed then 
                            error("attempt to use closed file", 2)
                        end
                        if not num then num = 1 end
                        local out = file:sub(start, num)
                        start = num
                        return out
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
                        return out:sub(1, loc)
                    end
                }
                return rTable
            elseif mode == "w" or mode == "a" then
                local fileName = table.remove(path) -- Remove the file so genDir doesn't assume its type as a table and scope into it (Did you just assume my genDir?!)
                local dir, meta = genDir(harbor, meta, path) -- Path to the directory
                path[#path] = fileName -- United again
                local buffer = ""
                if not dir then
                    return nil
                elseif meta and meta.fileName and meta.fileName.readOnly then
                    return nil
                end
                local wTable = {
                    flush = function()
                        if closed then 
                            error("attempt to use closed file", 2)
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
        return fsys
    else -- Or error
        error("Invalid harbor object", 2)
    end
end

mountFile = function(treePath) -- Mount a container file
    if fs.exists(treePath) and not fs.isDir(treePath) then -- Check it actually exists and isn't a directory
        local harbor = fs.open(treePath, "r") -- Read it
        local tree = harbor:readAll()
        harbor:close()
        mountString(tree) -- Mount it as a string
    else -- Or error
        error("Path to harbor is not a valid file or does not exist", 2)
    end
end