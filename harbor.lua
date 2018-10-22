local args = {...}
os.loadAPI("/.harbor/harbor.lua")
if args[1] == "convert" or args[1] == "c" then
    if args[2] == "file" or args[2] == "f" then
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
    else
        print("harbor convert <directory>")
    end
elseif args[1] == "boot" or args[1] == "b" then
    if not args[2] or not args[3] then
        print("harbor boot <web/file> <url/harbor VFS>")
    end
    if args[2] == "file" or args[2] == "f" then
        if fs.exists(args[3]) then
            if not fs.isDir(args[3]) then
                harbor.bootVFS(harbor.mountFile(args[3]))
            else
                print("Not a bootable harbor VFS")
            end
        else
            print("Volume does not exist")
        end
    elseif args[2] == "web" or args[2] == "w" then
        if http.checkURL(args[3]) then
            local repo = http.get(args[3])
            if repo then
                harbor.bootVFS(harbor.mountString(repo:readAll()))
                repo:close()
            else
                print("Error downloading files")
            end
        else
            print("Invalid URL")
        end
    else
        print("harbor boot <web/file> <url/harbor VFS>")
    end
else
    print("harbor convert <directory>")
    print("harbor boot <harbor VFS>")
end