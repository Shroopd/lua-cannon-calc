local args = { ... }

-- a unit of sleep
local wink = 0.2

local function printUsage()
    local programName = arg[0] or fs.getName(shell.getRunningProgram())
    print("Usages:")
    print(programName .. " <x> <y> <z>")
    print(programName .. " <x> <y> <z> [options] <rate>")
    print(
        [[options:
    Concatenate all letters for options. Eg: ]] .. programName .. [[ 10 30 -12 -SAQ 15

    Only for screw breach cannons:
    -S    sync mode: all cannons will start with delay, to hit in sync

    Disables screw breach cannons, fires on loop
    -A    use autocannons --Requires rate
    -Q    use quickfire breach cannons
    <rate>    Value from 1 to 15, determines autocannon fire rate
]]
    )
end

if #args >= 3 then
    rednet.open("back")
    local x, y, z, options, rate = table.unpack(args)
    local sync, auto, quick
    for i = 1, #options - 1 do
        local letter = string.upper(string.sub(options, i, i + 1))
        if letter == "S" then
            sync = true
        elseif letter == "A" then
            auto = true
        elseif letter == "Q" then
            quick = true
        end
        if rate then
            if rate < 1 or rate > 15 then
                error("Rate out of bounds, please choose a value 1-15")
            end
        end
        if sync and (auto or quick) then
            error("Cannot synchronize repeat fire cannons")
        end
    end

    local xyz = string.pack("nnn", x, y, z)
    if not (auto or quick) then
        rednet.broadcast(xyz, "CANNON_REGISTER")
    else
        if auto then
            rednet.broadcast(xyz, "CANNON_REGISTER_AUTO")
        end
        if quick then
            rednet.broadcast(xyz, "CANNON_REGISTER_QUICK")
        end
    end

    os.sleep(wink)

    if not (auto or quick) then
        repeat
            rednet.broadcast(nil, "CANNON_QUERY_UNREADY" .. xyz)
        until not rednet.receive("CANNON_RESPONSE_UNREADY" .. xyz, wink)
        print("READY")

        os.sleep(wink)
    end

    repeat
        rednet.broadcast(nil, "CANNON_QUERY_AIMING" .. xyz)
    until not rednet.receive("CANNON_RESPONSE_AIMING" .. xyz, wink)
    print("AIMED")

    os.sleep(wink)

    local delay
    if sync then
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
    if auto then
        rednet.broadcast(rate, "CANNON_LOOP" .. xyz)
        print("Hit enter to end barage")
        read()
        rednet.broadcast(rate, "CANNON_STOP" .. xyz)
    end
    print("FIRED")
else
    printUsage()
end
