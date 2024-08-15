local function tabledump(o, foo)
    if foo then
        print("More stuff", foo)
    end
    if type(o) == 'table' then
        local s = '{'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. ' ' .. k .. ' = ' .. tabledump(v) .. ','
        end
        return s .. '}'
    else
        return tostring(o)
    end
end

local function signum(number)
    if number > 0 then
        return 1
    elseif number < 0 then
        return -1
    else
        return 0
    end
end
-- minimum unit of sleep (sleep a wink)
local wink = 0.05
-- major unit of time, for cannon assembly and such major delays
local bigWink = 0.2

local function ballistics(config)
    --for require
    local M = {}


    --iter depth limit
    local ITER_LIMIT = 64
    --T value that is never reached in realistic use
    local T_LIMIT = 600


    --gravity per tick
    local GRAV_CONST = -0.05
    --drag per tick (speed retained)
    local DRAG_CONST = 0.99
    --upper angle limit (90 * 8), negate for lower limit
    local MAX = 90


    -- --dimensional gravity farofc
    -- local dimgrav = 1.0
    --drag per tick (retained velocity)
    local D = DRAG_CONST * 1.0
    --effective gravity
    local G = GRAV_CONST * 1.0 --dimgrav init value


    -- Real cannon coords
    -- local cannonx, cannony, cannonz
    -- Target x and y position
    local targetx, targety
    --total number of barrel blocks, including mounted chamber
    local cannonlength = 0
    --tick velocity of projectile
    local speed = 0

    -- -- given the start axis, this is the effective starting yaw of the cannon in octdegrees
    -- local startYaw
    -- -- are we doing highMount position? if so, returned pitch is 0 at top, increase down
    -- local highMount


    --angle of cannon in radians, 0 is level
    local trueangle = 0
    -- --cannon angle limits, cached from highMount
    -- local minAngle, maxAngle
    --cached from angle, speed, and barrel length
    local vx, vy, cx, cy

    local function xor(a, b)
        return not (not a == not b)
    end

    local function updateV()
        vx = math.cos(trueangle) * speed
        vy = math.sin(trueangle) * speed
    end

    local function updateC()
        cx = math.cos(trueangle) * cannonlength
        cy = math.sin(trueangle) * cannonlength
    end

    ---comment
    ---@param a number angle in degrees
    local function setAngle(a)
        -- trueangle = math.rad(a / 8)
        trueangle = math.rad(a)
        updateV()
        updateC()
    end

    local function setCharges(count)
        speed = count * 2
        updateV()
    end

    local function setLength(length)
        --Projectile exits one block past barrel
        cannonlength = length + 1.5
        updateC()
    end

    --optional
    local function setDrag(drag_multiplier)
        D = DRAG_CONST * drag_multiplier
    end

    --optional
    local function setGrav(gravity_multiplier)
        G = GRAV_CONST * gravity_multiplier
    end

    local function XofT(T)
        local L = math.log(D)
        return ((D ^ T - 1) * ((D - 1) * vx) / ((D - 1) * L)) + cx
    end

    local function YofT(T)
        local L = math.log(D)
        return (((D ^ T - 1) * ((D - 1) * vy + G) - G * T * L) / ((D - 1) * L)) + cy
    end

    local function TofX(x)
        x = x - cx
        return math.log((x * (D - 1) * math.log(D)) / ((D - 1) * vx) + 1, D)
    end

    local function threePointMethod(lowbound, highbound, f)
        local low, mid, high = lowbound, nil, highbound
        local lowf, midf, highf
        local whilei = 0
        while whilei < ITER_LIMIT do
            if (mid == nil) then
                mid = (low + high) / 2
            end
            if (lowf == nil) then
                lowf = f(low)
            end
            if (midf == nil) then
                midf = f(mid)
            end
            if (highf == nil) then
                highf = f(high)
            end
            -- os.sleep(1.0)
            -- print()
            -- print("low", low, lowf)
            -- print("mid", mid, midf)
            -- print("high", high, highf)
            --iterate
            if (lowf > midf) then
                high, highf = mid, midf
                mid, midf   = low, lowf
                low, lowf   = low + (mid - high), nil
            elseif (highf > midf) then
                low, lowf = mid, midf
                mid, midf = high, highf
                high, highf = high + (mid - low), nil
            elseif (lowf > highf) then
                high, highf = mid, midf
                mid, midf = nil, nil
                whilei = whilei + 1
            else
                low, lowf = mid, midf
                mid, midf = nil, nil
                whilei = whilei + 1
            end
        end
        return (low + high) / 2
    end

    local function bisectionMethod(lowbound, highbound, f)
        local low, mid, high = lowbound, nil, highbound
        local lowf, midf, highf
        local lowy, midy, highy, mid
        for i = 1, ITER_LIMIT do
            mid = (low + high) / 2
            midy = f(mid)
            if (lowy == nil) then
                lowy = f(low)
            end
            if (highy == nil) then
                highy = f(high)
            end
            if (xor(lowy > 0, midy > 0)) then
                high, highy = mid, midy
            else
                low, lowy = mid, midy
            end
        end
        return (low + high) / 2
    end

    local function TofY(y)
        local function foo(t)
            return YofT(t) - targety
        end
        local TofPeak
        if trueangle > 0 then
            TofPeak = threePointMethod(0, T_LIMIT, foo)
        else
            TofPeak = 0
        end
        return bisectionMethod(TofPeak, T_LIMIT, foo)
    end

    local function XofY(y)
        return XofT(TofY(y))
    end

    local function YofX(x)
        return YofT(TofX(x))
    end

    local function findNilBounds()
        local low, high, notnil, T
        --find nil bounds via binary search
        --HIGH bounds
        setAngle(MAX)
        T = TofX(targetx)
        if (T == T) then
            notnil = MAX
        else
            low, high = 0, MAX
            for i = 1, ITER_LIMIT do
                local mid = (low + high) / 2
                setAngle(mid)
                T = TofX(targetx)
                if (T == T) then
                    notnil, low = mid, mid
                else
                    high = mid
                end
            end
        end
        --nilbounds found
        return -notnil, notnil
    end

    local function farshoot(lowbound, highbound)
        local function foo(a)
            setAngle(a)
            return XofY(targety)
        end
        return threePointMethod(lowbound, highbound, foo)
    end

    local function highshoot(lowbound, highbound)
        local function foo(a)
            setAngle(a)
            return YofX(targetx)
        end
        return threePointMethod(lowbound, highbound, foo)
    end

    local function overshoot(lowbound, highbound)
        return highshoot(lowbound, highbound)
    end

    local function finalAngle(low, high)
        local function foo(val)
            setAngle(val)
            return YofX(targetx) - targety
        end
        return bisectionMethod(low, high, foo)
    end

    -- function M.setHighSolution(high_solution)
    --     highsolution = high_solution
    -- end

    local function calc()
        local lownotnil, highnotnil
        --first check
        setAngle(0)
        local T = TofX(targetx)
        if (T ~= T) then
            -- setAngle(nil)
            return nil
        else
            --find nilbounds
            lownotnil, highnotnil = findNilBounds()
            -- print(lownotnil, highnotnil)

            --find furthest overshoot
            local farangle = overshoot(lownotnil, highnotnil)
            setAngle(farangle)

            --find final angle
            local tempAngle, errorX, errorY
            local outDict = {}

            --find for high
            local tempHigh = {}
            tempAngle = finalAngle(farangle, highnotnil)
            setAngle(tempAngle)
            errorY = YofX(targetx) - targety
            errorX = XofY(targety) - targetx
            --Error squared
            tempHigh.error = math.min(math.abs(errorX), math.abs(errorY))
            --Pitch in degrees
            tempHigh.pitch = tempAngle
            tempHigh.time = TofX(targetx)

            outDict.high = tempHigh

            --find for low
            local tempLow = {}
            tempAngle = finalAngle(lownotnil, farangle)
            setAngle(tempAngle)
            errorY = YofX(targetx) - targety
            errorX = XofY(targety) - targetx
            --Error squared
            tempLow.error = math.min(math.abs(errorX), math.abs(errorY))
            --Pitch in degrees
            tempLow.pitch = tempAngle
            tempLow.time = TofX(targetx)

            outDict.low = tempLow

            return outDict
        end
    end

    local function init(C)
        setCharges(C.charges)
        setLength(C.cannonlength)
        --set dimension
        local dimension = string.upper(C.dimension)
        local grav, drag = 1.0, 1.0
        if dimension == "E" then
            drag = 0.00001
            grav = 0.9
        elseif dimension == "N" then
            drag = 1.1
            grav = 1.1
        elseif dimension ~= "O" then
            error("What kind of dimension is " .. dimension .. "?")
        end
        local is_autocannon = string.upper(C.is_autocannon)
        if is_autocannon == "Y" then
            grav = grav / 2
        end
        setDrag(drag)
        setGrav(grav)
    end

    ---comment
    ---@param target_x any
    ---@param target_y any
    ---@param target_z any
    ---@return table | nil
    function M.solve(target_x, target_y, target_z)
        local diffx, diffy, diffz = target_x --[[ - cannonx]], target_y --[[ - cannony]], target_z --[[ - cannonz]]
        targetx, targety = math.sqrt((diffx * diffx) + (diffz * diffz)), diffy
        local outDict = calc()
        if not outDict then
            return nil
        end
        -- Brain x and brain z for the poor meat calculator behind the screen
        -- I imagine cos as x, sin as z, (x,z), starting at (1,0) progressing towards (0,1) and around counterclockwise.
        local sx, sz = signum(diffx), signum(diffz)
        local tempyaw
        if sx == 0 then
            tempyaw = 90 * sz
        elseif sz == 0 then
            tempyaw = 90 - (90 * sx)
        else
            tempyaw = math.deg(math.atan(diffz / diffx))
            if (sx < 0) then
                tempyaw = tempyaw + 180
            end
        end
        tempyaw = 180 + tempyaw
        tempyaw = ((tempyaw + 180) % 360) - 180

        --Yaw in degrees
        outDict.high.yaw = tempyaw
        outDict.low.yaw = tempyaw
        return outDict
    end

    init(config)

    return M
end

local function config()
    local M = {}

    -- local gears = { "pitch", "yaw" }
    local names = {
        cannon_type = "(Quick fire breach: Q / Autocannon: A / Mechanically loaded: M)",
        rest_axis = "( X / Z / -X / -Z / Y )",
        dimension = "( E / O / N )",
        assemble = "(direction)",
        fire = "(direction)",
        ender_modem = "(direction or peripheral id)",
        x = "(x of cannon's rotational center)",
        y = "(y of cannon's rotational center)",
        z = "(z of cannon's rotational center)",
        charges = "(number of powder charges, or muzzle velocity in meters / second divided by 40)",
        aim_reduction = "(gear down after sequenced gearshift: (aim_reduction * x degrees) -> x degrees)",
        cannon_name = "(cannon's hostname)"
    }
    local peripheral_seek_list = {
        pitch = "Create_SequencedGearshift",
        yaw = "Create_SequencedGearshift",
    }
    local nums = { "x", "y", "z", "charges", "cannonlength", "aim_reduction" }
    local peripheral_names = { "pitch", "yaw", "ender_modem" }
    -- local stores = { "storage" }

    local function hasVal(a, b)
        for k, v in pairs(a) do
            if (v == b) then
                return k
            end
        end
        return false
    end

    ---comment
    ---@param a table smaller table
    ---@param b table bigger table
    ---@return unknown
    local function oneDiff(a, b)
        for k, v in pairs(b) do
            if not hasVal(a, v) then
                return v
            end
        end
        return false
    end

    local function filter(t, s)
        for index, value in ipairs(t) do
            if not string.match(value, s) then
                t[index] = nil
            end
        end
    end

    if fs.exists("cannon_config.txt") then
        local file = fs.open("cannon_config.txt", "r")
        local line = file.readLine()
        while line do
            local first, last = string.match(line, "([^=]+)="), string.match(line, "=([^=]+)")
            M[first] = last
            line = file.readLine()
        end
        file.close()
    else
        for name, peripheral_type in pairs(peripheral_seek_list) do
            print("Waiting for: " .. name)
            local oldlist = peripheral.getNames()
            while true do
                local list = peripheral.getNames()
                filter(list, peripheral_type)
                local foo = oneDiff(oldlist, list)
                if foo then
                    M[name] = foo
                    print("assigned to " .. foo)
                    break
                else
                    os.sleep(wink)
                end
                oldlist = list
            end
        end
        for name, guide in pairs(names) do
            print("Please input: " .. name, guide)
            M[name] = read()
        end
        local file = fs.open("cannon_config.txt", "w")
        for k, v in pairs(M) do
            file.writeLine(k .. "=" .. v)
        end
        file.close()
    end

    for _, k in pairs(peripheral_names) do
        M[k] = peripheral.wrap(M[k])
    end

    for _, k in pairs(nums) do
        M[k] = tonumber(M[k])
    end

    if M.cannon_type == "M" then
        print("Cannon is mechanically loaded, requiring loader.lua...")
        print(
            "Note: loader.lua should provide functions loaded() -> boolean, load() -> nil which must be interrupt-safe, and unload() -> nil which resets the state after firing")
        M.loader = require("loader")
        print("Loader accquired complete")
    else
        M.loader = {
            loaded = function()
                return true
            end,
            load = function()
                return true
            end,
            unload = function()
                return true
            end
        }
    end

    return M
end

local function cannon()
    -- local C = require("config")
    -- local B = require("ballistics")
    local C = config()
    local B = ballistics(C)

    -- min and max values for high and low mounts
    local LOW_MIN, LOW_MAX, HIGH_MIN, HIGH_MAX = -30, 60, 30, 90
    -- is the cannon built vertical?
    local highMount
    -- what is the effective starting yaw of the cannon?
    local startYaw
    -- min and max value for current mount
    local minAngle, maxAngle



    local function vs_adjust(solve_in)
        if ship then
            print("VS ship detected, corrections not implemented yet!")
            return solve_in
            -- local pitch, yaw = solve_in.pitch, solve_in.yaw
        else
            return solve_in
        end
    end


    local function init()
        --find yawShift
        local rest_axis = string.upper(C.rest_axis)
        if rest_axis == "Y" then
            startYaw = 0
            highMount = true
        else
            highMount = false
            if rest_axis == "-Z" then
                startYaw = 90
            elseif rest_axis == "X" then
                startYaw = 180
            elseif rest_axis == "Z" then
                startYaw = 270
            elseif rest_axis == "-X" then
                startYaw = 360
            else
                error("Not a valid axis")
            end
        end
        if highMount then
            minAngle, maxAngle = HIGH_MIN, HIGH_MAX
        else
            minAngle, maxAngle = LOW_MIN, LOW_MAX
        end

        rednet.open(C.ender_modem)
        rednet.host("CANNON", C.cannon_name)
    end

    local function check(P)
        local dx, dy, dz = P.x - C.x, P.y - C.y, P.z - C.z
        if dx * dx + dy * dy + dz * dz < C.cannonlength * C.cannonlength then
            print("out of range")
            return false
        end
        local solves = B.solve(dx, dy, dz)
        if not solves then
            print("check failed no solutions")
            return false
        end

        local order = { "high", "low" }
        for _, k in ipairs(order) do
            local attempt = solves[k]

            vs_adjust(attempt)

            if attempt.error < 1 then
                if minAngle <= attempt.pitch and attempt.pitch <= maxAngle then
                    return attempt
                end
            end
        end

        -- print(x, y, z, solves.high.pitch, solves.low.pitch) --not to do
        print("check failed no solutions")
        return false
    end

    local function translate(pitch, yaw)
        --correct for highMount
        if (highMount) then
            pitch = HIGH_MAX - pitch
        end
        --multiply by 8 and aim_reduction in order to scale to true pitch and yaw, loop > 180 degree yaw moves
        pitch, yaw = pitch * 8 * C.aim_reduction, (((yaw - startYaw + 180) % 360) - 180) * 8 * C.aim_reduction
        local pmod, ymod = signum(pitch), signum(yaw)
        pitch, yaw = pmod * math.floor(pitch * pmod + 0.5), ymod * math.floor(yaw * ymod + 0.5)
        return pitch, yaw
    end

    local function noRunningGears()
        for k, v in ipairs(table.pack(peripheral.find("Create_SequencedGearshift"))) do
            if v.isRunning() then
                return false
            end
        end
        return true
    end

    local function ready()
        while not C.loader.loaded() do
            C.loader.load()
        end
    end

    local function aim(registered)
        redstone.setOutput(C.assemble, true)
        local pitch, yaw = translate(registered.pitch, registered.yaw)
        local pitchmod, yawmod = signum(pitch), signum(yaw)
        if pitchmod ~= 0 then
            C.pitch.rotate(pitch, pitchmod)
        end
        if yawmod ~= 0 then
            C.yaw.rotate(yaw, yawmod)
        end
        print("AIMING")
        while not noRunningGears() do
            os.sleep(wink)
        end
    end

    local function fire(fire_behavior)
        if fire_behavior.delay ~= 0 then
            print("SYNCING")
            os.sleep(math.floor((fire_behavior.delay - registered.time)) / 20)
        end
        if C.cannon_type == "M" then
            print("FIRING")
            redstone.setOutput(C.fire, true)
            os.sleep(bigWink)
        else
            if C.cannon_type == "Q" then
                while true do
                    redstone.setOutput(C.fire, true)
                    os.sleep(0.1)
                    redstone.setOutput(C.fire, false)
                    os.sleep(0.1)
                end
            elseif C.cannon_type == "A" then
                redstone.setOutput(C.fire, true)
                while true do
                    os.sleep(0.1)
                end
            else
                error("Invalid cannon type!")
            end
        end
    end

    local function register(solve, id, message, registered)
        if not registered then
            solve = check(message)
            if solve then
                rednet.send(id, solve, "CANNON_RESPONSE")
                message.solve = solve
                return message
            else
                rednet.send(id, false, "CANNON_RESPONSE")
            end
        else
            rednet.send(id, false, "CANNON_RESPONSE")
        end
    end

    local function statusOrReact(state, registered, react, reactname)
        while true do
            local solve
            local id, message = rednet.receive("CANNON")

            if message.type == "STATUS" then
                rednet.send(id, { status = state, registered = registered, config = C }, "CANNON_RESPONSE")
            elseif message.type == "TRY" then
                rednet.send(id, check(message), "CANNON_RESPONSE")
            elseif message.type == "ABORT" then
                os.reboot()
            elseif reactname and message.type == reactname then
                if react then
                    return react(solve, id, message, registered)
                else
                    return nil
                end
            else
                print("Invalid message type! How could this happen?", message.type)
            end
        end
    end
    --[[
    -- local function statusOrRegister(state, registered)
    --     while true do
    --         local solve
    --         local id, message = rednet.receive("CANNON")

    --         if message.type == "STATUS" then
    --             rednet.send(id, { status = state, registered = registered, config = C }, "CANNON_RESPONSE")
    --         elseif message.type == "TRY" then
    --             rednet.send(id, check(message), "CANNON_RESPONSE")
    --         elseif message.type == "ABORT" then
    --             os.reboot()
    --         elseif message.type == "REGISTER" then
    --             if not registered then
    --                 solve = check(message)
    --                 if solve then
    --                     rednet.send(id, solve, "CANNON_RESPONSE")
    --                     message.solve = solve
    --                     return message
    --                 else
    --                     rednet.send(id, false, "CANNON_RESPONSE")
    --                 end
    --             else
    --                 rednet.send(id, false, "CANNON_RESPONSE")
    --             end
    --         else
    --             print("Invalid message type! How could this happen?")
    --         end
    --     end
    -- end
]]

    --MAIN CODE START

    init()

    while true do
        -- load and wait for a fire computer to register the machine
        local registered = nil

        parallel.waitForAny(
            ready,
            function()
                while true do
                    registered = statusOrReact("LOADING", registered, register, "REGISTER")
                end
            end
        )

        while not registered do
            registered = statusOrReact("READY", registered, register, "REGISTER")
        end

        parallel.waitForAny(
            function()
                aim(registered)
            end,
            function()
                statusOrReact("AIMING", registered)
            end
        )

        local fire_behavior

        parallel.waitForAny(
            function()
                _, fire_behavior = rednet.receive("CANNON_FIRE")
            end,
            function()
                statusOrReact("AIMED", registered)
            end
        )

        parallel.waitForAny(
            function()
                fire(fire_behavior)
            end,
            function()
                statusOrReact("FIRING", registered, nil, "HALT")
            end
        )

        -- Clean state for next fire
        C.loader.unload()
        redstone.setOutput(C.fire, false)
        redstone.setOutput(C.assemble, false)
        os.sleep(bigWink)
    end
end

cannon()
