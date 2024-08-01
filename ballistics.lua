--for require
local M = {}


--iter depth limit
local ITER_LIMIT = 48
--T value that is never reached in realistic use
local T_LIMIT = 500


--gravity per tick
local GRAV_CONST = -0.05
--gravity per tick
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
local cannonx, cannony, cannonz
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
    cannonlength = length + 1
    updateC()
end

--optional
function M.setDrag(drag_multiplier)
    D = DRAG_CONST * drag_multiplier
end

--optional
function M.setGrav(gravity_multiplier)
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
    local TofPeak = threePointMethod(0, T_LIMIT, YofT)
    local function foo(n)
        return YofT(n) - targety
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

local function overshoot(lowbound, highbound)
    local function foo(a)
        setAngle(a)
        return XofY(targety)
    end
    return threePointMethod(lowbound, highbound, foo)
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
        tempHigh.error = (errorX * errorX) + (errorY * errorY)
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
        tempLow.error = (errorX * errorX) + (errorY * errorY)
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
function M.init(cannon_X, cannon_Y, cannon_Z, charges, cannon_length)
    --store values
    cannonx, cannony, cannonz = cannon_X, cannon_Y, cannon_Z
    setCharges(charges)
    setLength(cannon_length)
    -- --find yawShift
    -- rest_axis = string.upper(rest_axis)
    -- if rest_axis == "Y" then
    --     startYaw = 0
    --     minAngle, maxAngle = HIGH_MAX, HIGH_MAX
    --     highMount = true
    -- else
    --     highMount = false
    --     minAngle, maxAngle = LOW_MIN, LOW_MAX
    --     if rest_axis == "-Z" then
    --         startYaw = 0
    --     elseif rest_axis == "X" then
    --         startYaw = 90
    --     elseif rest_axis == "Z" then
    --         startYaw = 180
    --     elseif rest_axis == "-X" then
    --         startYaw = 270
    --     else
    --         error("Not a valid axis")
    --     end
    -- end
end

---comment
---@param target_x any
---@param target_y any
---@param target_z any
---@return table | nil
function M.solve(target_x, target_y, target_z)
    local diffx, diffy, diffz = target_x - cannonx, target_y - cannony, target_z - cannonz
    targetx, targety = math.sqrt((diffx * diffx) + (diffz * diffz)), diffy
    local outDict = calc()
    if not outDict then
        return nil
    end
    -- Brain x and brain z for the poor meat calculator behind the screen
    -- I imagine cos as x, sin as z, (x,z), starting at (1,0) progressing towards (0,1) and around counterclockwise.
    local bx, by = -diffz, diffx
    local tempyaw = math.deg(math.atan(by, bx))
    --Yaw in degrees
    outDict.high.yaw = tempyaw
    outDict.low.yaw = tempyaw
    return outDict
end

return M
