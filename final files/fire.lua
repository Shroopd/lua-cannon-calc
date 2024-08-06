local args = { ... }

-- a unit of sleep
local wink = 0.2

local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " <x> <y> <z>")
    print(programName .. " <x> <y> <z> sync")
    print(programName .. " <x> <y> <z> now")
end

if #args == 3 or #args == 4 then
    rednet.open("back")
    local x, y, z, mode = table.unpack(args)

    local xyz = string.pack("nnn", x, y, z)
    rednet.broadcast(xyz, "CANNON_REGISTER")

    os.sleep(wink)

    repeat
        rednet.broadcast(nil, "CANNON_QUERY_UNREADY" .. xyz)
    until not rednet.receive("CANNON_RESPONSE_UNREADY" .. xyz, wink)
    print("READY")

    os.sleep(wink)

    repeat
        rednet.broadcast(nil, "CANNON_QUERY_AIMING" .. xyz)
    until not rednet.receive("CANNON_RESPONSE_AIMING" .. xyz, wink)
    print("AIMED")

    os.sleep(wink)
    local delay
    if mode == "sync" then
        print("SYNCING")
        local maxTime = 0
        for _, v in ipairs(table.pack(rednet.lookup("CANNON_READY" .. xyz))) do
            print("querying " .. v)
            rednet.send(v, nil, "CANNON_QUERY_TIME" .. xyz)
            print("queried " .. v)
            local id, time = rednet.receive("CANNON_RESPONSE_TIME" .. xyz, wink)
            maxTime = math.max(maxTime, time)
        end
        delay = maxTime
    else
        delay = 0
    end
    print("FIRING")
        rednet.broadcast(delay, "CANNON_FIRE" .. xyz)
    print("FIRED")
else
    printUsage()
end
