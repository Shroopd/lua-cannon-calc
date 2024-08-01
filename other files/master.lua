local args = { ... }

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

    repeat
        rednet.broadcast(nil, "CANNON_QUERY_UNREADY" .. xyz)
    until not rednet.receive("CANNON_RESPONSE_UNREADY" .. xyz, 1.0)

    repeat
        rednet.broadcast(nil, "CANNON_QUERY_AIMING" .. xyz)
    until not rednet.receive("CANNON_RESPONSE_AIMING" .. xyz, 1.0)

    if mode == "sync" then
        local maxTime = 0
        for k, v in pairs(rednet.lookup("CANNON_READY" .. xyz)) do
            rednet.send(v, "CANNON_QUERY_TIME" .. xyz)
            local _, time = rednet.receive("CANNON_RESPONSE_TIME" .. xyz)
            maxTime = math.max(maxTime, time)
        end
        rednet.broadcast(maxTime, "CANNON_FIRE" .. xyz)
    else
        rednet.broadcast(0, "CANNON_FIRE" .. xyz)
    end
else
    printUsage()
end
