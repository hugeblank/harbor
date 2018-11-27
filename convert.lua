local args = {...}
local convert = require("harbor").convert
if fs.exists(args[1]) then
    if fs.isDir(args[1]) then
        local file = fs.open(fs.getName(args[1])..".hvfs", "w")
        file.write(convert(args[1]))
        file.close()
        print(fs.combine(args[1], "").." converted")
    else
        print("Not a convertible directory")
    end
else
    print("harbor convert <directory>")
end