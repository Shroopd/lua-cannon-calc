local function dump(o, foo)
    if foo then
        print("More stuff", foo)
    end
    if type(o) == 'table' then
        local s = '{'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. ' ' .. k .. ' = ' .. dump(v) .. ','
        end
        return s .. '}'
    else
        return tostring(o)
    end
end

local function ballistics(config)
    --for require
    local M = {}


    --iter depth limit
    local ITER_LIMIT = 64
    --T value that is never reached in realistic use
    local T_LIMIT = 500


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


    local function signum(number)
        if number > 0 then
            return 1
        elseif number < 0 then
            return -1
        else
            return 0
        end
    end

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

    --- Rest axis can be "x", "-x", "z", "-z", "y"
    ---@param cannon_X number
    ---@param cannon_Y number
    ---@param cannon_Z number
    ---@param charges number
    ---@param cannon_length number
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

    local gears = { "pitch", "yaw" }
    local nums = { "x", "y", "z", "charges", "cannonlength", "aim_reduction" }
    local names = {
        rest_axis = "(X,Z,-X,-Z,Y)",
        dimension = "(E/O/N)",
        is_autocannon = "(Y/N)",
        assemble = "(direction)",
        fire = "(direction)",
        ender_modem =
        "(direction)"
    }
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

    if fs.exists("config.txt") then
        local file = fs.open("config.txt", "r")
        local line = file.readLine()
        while line do
            local first, last = string.match(line, "([^=]+)="), string.match(line, "=([^=]+)")
            M[first] = last
            line = file.readLine()
        end
        file.close()
    else
        for _, name in ipairs(gears) do
            print("Waiting for: " .. name)
            while true do
                local list = peripheral.getNames()
                filter(list, "Create_SequencedGearshift")
                local foo = oneDiff(M, list)
                if foo then
                    M[name] = foo
                    print("assigned to " .. foo)
                    break
                else
                    os.sleep(0.05)
                end
            end
        end
        for _, num in ipairs(nums) do
            print("Please input: " .. num)
            M[num] = read()
        end
        for name, guide in pairs(names) do
            print("Please input: " .. name, guide)
            M[name] = read()
        end
        local file = fs.open("config.txt", "w")
        for k, v in pairs(M) do
            file.writeLine(k .. "=" .. v)
        end
        file.close()
    end

    for _, k in pairs(gears) do
        M[k] = peripheral.wrap(M[k])
    end

    for _, k in pairs(nums) do
        M[k] = tonumber(M[k])
    end

    -- for _, k in pairs(nums) do
    --     M[k] = string.upper(M[k])
    -- end

    return M
end

local function cannon()
    -- local args = { ... }

    -- local C = require("config")
    -- local B = require("ballistics")
    local C = config()
    local B = ballistics(C)

    -- min and max values for high and low mounts
    local LOW_MIN, LOW_MAX = -30, 60
    local HIGH_MIN, HIGH_MAX = 30, 90
    local AUTO_LOW_MIN, AUTO_LOW_MAX = -45, 90
    local AUTO_HIGH_MIN, AUTO_HIGH_MAX = 0, 90
    -- is the cannon built vertical?
    local highMount
    -- what is the effective starting yaw of the cannon?
    local startYaw
    -- min and max value for current mount
    local minAngle, maxAngle

    local auto = string.upper(C.is_autocannon) == "Y"

    -- minimum unit of sleep (sleep a wink)
    local wink = 0.05
    -- major unit of time, for cannon assembly and such major delays
    local bigWink = 4 * wink

    local function init()
        --find yawShift
        local rest_axis = string.upper(C.rest_axis)
        -- local highMount
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
        if string.upper(C.is_autocannon) == "Y" then
            if highMount then
                minAngle, maxAngle = AUTO_HIGH_MIN, AUTO_HIGH_MAX
            else
                minAngle, maxAngle = AUTO_LOW_MIN, AUTO_LOW_MAX
            end
        else
            if highMount then
                minAngle, maxAngle = HIGH_MIN, HIGH_MAX
            else
                minAngle, maxAngle = LOW_MIN, LOW_MAX
            end
        end
    end

    local function check(x, y, z)
        local maxTime
        if auto then
            maxTime = 60
        else
            maxTime = 600
        end
        print("checking", x, y, z)
        local dx, dy, dz = x - C.x, y - C.y, z - C.z
        if dx * dx + dy * dy + dz * dz < C.cannonlength * C.cannonlength then
            print("out of range")
            return false
        end
        local solves = B.solve(dx, dy, dz)
        if not solves then
            print("check failed no solutions")
            return false
        end
        if solves.high.error < 1 and (not (solves.high.time > maxTime and auto)) and minAngle <= solves.high.pitch and solves.high.pitch <= maxAngle then
            return solves.high
        elseif solves.low.error < 1 and (not (solves.low.time > maxTime and auto)) and minAngle <= solves.low.pitch and solves.low.pitch <= maxAngle then
            return solves.low
        else
            -- print(x, y, z, solves.high.pitch, solves.low.pitch) --not to do
            print("check failed no solutions")
            return false
        end
        error("how it get here")
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

    local function register()
        while true do
            -- print("waiting for register")
            local registerMessage = "CANNON_REGISTER"
            if auto then
                registerMessage = registerMessage .. "_AUTO"
            else
                registerMessage = registerMessage .. "_QUICK"
            end
            local _, message = rednet.receive(registerMessage)
            local tempx, tempy, tempz = string.unpack("nnn", message)
            local solve = check(tempx, tempy, tempz)
            if solve then
                -- xyz, validSolve = message, solve
                return message, solve
            end
        end
    end

    -- MAIN CODE START

    init()

    rednet.open(C.ender_modem)

    while true do
        redstone.setOutput(C.fire, false)
        redstone.setOutput(C.assemble, true)
        os.sleep(bigWink)
        print("READY")
        -- print(string.upper(C.is_autocannon) == "Y")
        local xyz, validSolve = register()
        os.sleep(wink)
        parallel.waitForAny(
            function()
                while true do
                    local sender = rednet.receive("CANNON_QUERY_AIMING" .. xyz)
                    os.sleep(wink)
                    rednet.send(sender, true, "CANNON_RESPONSE_AIMING" .. xyz)
                end
            end,
            function()
                local pitch, yaw = translate(validSolve.pitch, validSolve.yaw)
                local pitchmod, yawmod = signum(pitch), signum(yaw)
                -- print(validSolve.pitch, validSolve.yaw)
                -- print(pitch, yaw)
                if pitchmod ~= 0 then
                    -- print(pitch / 8, pitchmod)
                    C.pitch.rotate(pitch, pitchmod)
                end
                if yawmod ~= 0 then
                    -- print(yaw / 8, yawmod)
                    C.yaw.rotate(yaw, yawmod)
                end
                print("AIMING")
                while not noRunningGears() do
                    os.sleep(wink)
                end
            end
        )
        print("WAITING")
        local _, rate = rednet.receive("CANNON_LOOP" .. xyz)
        print("FIRING")
        parallel.waitForAny(
            function()
                if auto then
                    redstone.setAnalogOutput(C.fire, rate)
                    while true do
                        os.sleep(0.1)
                    end
                else
                    while true do
                        redstone.setOutput(C.fire, true)
                        os.sleep(0.1)
                        redstone.setOutput(C.fire, false)
                        os.sleep(0.1)
                    end
                end
            end,
            function()
                rednet.receive("CANNON_STOP" .. xyz)
            end
        )
        print("STOPPING")
        redstone.setAnalogOutput(C.fire, 0)
        redstone.setOutput(C.assemble, false)
        os.sleep(bigWink)
    end
end

cannon()
