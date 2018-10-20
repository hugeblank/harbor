local args = {...}
os.loadAPI("/.harbor/harbor.lua")
if args[1] == "convert" or args[1] == "c" then
    if not args[2] then
        print("harbor convert <directory>")
    end
    if fs.exists(args[2]) then
        if fs.isDir(args[2]) then
            local file = fs.open(fs.getName(args[2])..".hvfs", "w")
            file.write(harbor.convert(args[2]))
            file.close()
            print(fs.combine(args[2], "").." converted")
        else
            print("Not a convertible directory")
        end
    else
        print("Directory does not exist")
    end
elseif args[1] == "boot" or args[1] == "b" then
    if not args[2] then
        print("harbor boot <harbor VFS>")
    end
    if fs.exists(args[2]) then
        if not fs.isDir(args[2]) then
            harbor.bootVFS(harbor.mountFile(args[2]))
        else
            print("Not a bootable harbor VFS")
        end
    else
        print("Volume does not exist")
    end
else
    print("harbor convert <directory>")
    print("harbor boot <harbor VFS>")
end