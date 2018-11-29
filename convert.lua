local args = {...}
local convert = loadfile("/.harbor/harbor.lua")().convert -- loadfile in the only necessary harbor function

-- Executable compression 
if not fs.exists("/.harbor/bbpack.lua") then -- If we don't have BBPack installed
    local bbpdown = http.get("https://pastebin.com/raw/cUYTGbpb") -- get it via http
    local bbpfile = fs.open("/.harbor/bbpack.lua", "w") -- open a file for it
    bbpfile.write(bbpdown:readAll()) -- write contents of request
    bbpfile:close() -- close and close
    bbpdown:close()
end

local genExec = function(path)
    os.loadAPI("/.harbor/bbpack.lua") -- Load the LZW compression algorithm by BombBloke
    local bbpack = {}
    bbpack = _G.bbpack
    _G.bbpack = nil
    return 
[[os.loadAPI("/.harbor/bbpack.lua") -- Load the LZW compression algorithm by BombBloke
local bbpack = {}
bbpack = _G.bbpack
_G.bbpack = nil    
local boot = ]]..textutils.serialize([[ -- Create the boot function, as a string for recursion
os.loadAPI("/.harbor/bbpack.lua") -- Load the LZW compression algorithm by BombBloke
local bbpack = {}
bbpack = _G.bbpack
_G.bbpack = nil
local args = {...} -- Pull the arguments into a table
local hvfs = args[1] -- The first argument is the virtual file system
table.remove(args, 1) -- Removing it so that we can just unpack the arguments and send them to the executing startup program
local vfs = loadfile("/.harbor/harbor.lua")().mountTable(hvfs) -- Mount the virtual filesystem object
local str = "this title is deliberately unique such that it's a pain to replicate" -- Create a multishell title that's unique
multishell.setTitle(multishell.getCurrent(), str) -- Set the current window to that title 
while multishell.getCount() ~= 1 do -- While the current window isn't the only one open
    if multishell.getTitle(1) ~= str then -- If the title of the first window isn't the unique one
        multishell.setFocus(1) -- Set focus to it
        os.queueEvent("terminate") -- Attempt to terminate
    else -- OTHERWISE the first window is the one we want to keep
        multishell.setFocus(2) -- So set the focus to the second one
        os.queueEvent("terminate") -- And attempt to terminate it
    end
    sleep() -- Rest for a moment
end
if term.isColor() then -- If this is an advanced computer load multishell API
    os.run({},'/.harbor/multishell.lua')
end
os.run({}, '/.harbor/shell.lua') -- Then load the shell API
local old = _G.fs -- Hang onto the core fs API
_G.fs = vfs -- Set the fs API to the one we want to use
shell.run('startup.lua', unpack(args)) -- Load up the startup program
_G.fs = old -- After the program completes execution reset the fs API
fs.delete(shell.getRunningProgram()) -- Delete the vfs file
local file = fs.open(shell.getRunningProgram(), "w") -- Recreate the vfs file so that we can update it
file.write([=[os.loadAPI("/.harbor/bbpack.lua") -- Write to the file this string | Load the bbpack API locally
local bbpack = {}
bbpack = _G.bbpack
_G.bbpack = nil
local boot = ]=]..textutils.serialize(boot)..[=[ -- Set the boot variable in this string to the already existing boot string
boot = 'local boot = '..textutils.serialise(boot)..'\n'..boot]=]..[=[ -- Add the boot string to this string as a variable. String with in a string fun
load(boot, 'hvfs bootloader', nil, _ENV)( -- Load and execute the boot function 
    textutils.unserialize( -- Unserialize the decompressed contents
        bbpack.decompress( -- decompress the output of the base64 decoder
            bbpack.fromBase64("]=]..bbpack.toBase64( -- Convert the contents to a base64 string
                    bbpack.compress( -- Compress the table
                        textutils.serialise(hvfs), 128)) --[=[ Serialize the vfs ]=] ..[=["),true, 128)), ...)]=])
file.close() --[=[ Close the file ]=] ]])..'\n'..[[ -- Everything beyond this point is for initial setup, varies insignificantly from line 567 down to here
boot = 'local boot = '..textutils.serialise(boot)..'\n'..boot -- Set the boot variable to the current boot string, appended to the top of the program
local exe = textutils.unserialize( -- Unserialize the decompressed contents
    bbpack.decompress( -- Decompress the table spat out from the base64 conversion
        bbpack.fromBase64("]]..bbpack.toBase64( -- Convert contents to a base64 string
            bbpack.compress( -- Compress the table
                textutils.serialise( -- Serialize the vfs
                    convert(path)), 128)) --[[ Convert the path into a vfs ]]..[["), true, 128)) -- Convert from base64
load(boot, "hvfs bootloader", nil, _ENV)(exe, ...) -- Load and execute the boot function
]]
end

if fs.exists(args[1]) then
    if fs.isDir(args[1]) then
        local file = fs.open(fs.getName(args[1])..".hvfs", "w")
        file.write(genExec(args[1]))
        file.close()
        print(fs.combine(args[1], "").." converted")
    else
        print("Not a convertible directory")
    end
else
    print("harbor convert <directory>")
end


