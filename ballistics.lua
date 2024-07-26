--for require
local M = {}


--iter depth limit
local ITER_LIMIT = 48
--T value that is never reached in realistic use
local T_LIMIT = 500


--gravity per tick
local GRAV_CONST = -0.05
--effective gravity
local G = GRAV_CONST * 1.0 --dimgrav init value
--drag per tick (retained velocity)
local D = 0.99
--cannon angle limits
local LOW, HIGH = -240, 480


--dimensional gravity farofc
local dimgrav = 1.0


--total number of barrel blocks, including mounted chamber
local cannonlength = 0
--angle of cannon in 1/8 degrees
local octangle = 0
--angle of cannon in radians, 0 is level
local angle = 0
--tick velocity of projectile
local speed = 0
-- Target x and y position
local targetx, targety
-- Do we want the high solution? If true, we get the high arc solution. If false, we get the low arc solution.
local highsolution


--cached from angle, speed, and barrel length
local vx, vy, cx, cy



local function xor(a, b)
    return not (not a == not b)
end

local function updateV()
    vx = math.cos(angle) * speed
    vy = math.sin(angle) * speed
end

local function updateC()
    cx = math.cos(angle) * cannonlength
    cy = math.sin(angle) * cannonlength
end

--optional
function M.setGrav(gravity_multiplier)
    dimgrav = gravity_multiplier
    G = GRAV_CONST * dimgrav
end

function M.getOctAngle()
    return octangle
end

local function setAngle(a)
    octangle = a
    angle = math.rad(a / 8)
    updateV()
    updateC()
end

function M.setCharges(count)
    speed = count * 2
    updateV()
end

function M.setLength(length)
    cannonlength = length + 1
    updateC()
end

--optional
function M.setDrag(drag)
    D = 1 - drag
    updateV()
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
    setAngle(HIGH)
    T = TofX(targetx)
    if (T == T) then
        notnil = HIGH
    else
        low, high = 0, HIGH
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
    return math.max(-notnil, LOW), notnil
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

function M.setTarget(target_x, target_y)
    targetx = target_x
    targety = target_y
end

function M.setHighSolution(high_solution)
    highsolution = high_solution
end

function M.calc()
    local low, mid, high, lownotnil, highnotnil, lowy, midy, highy
    --first check
    setAngle(0)
    local T = TofX(targetx)
    if (T ~= T) then
        setAngle(nil)
        return (1 / 0)
    else
        --find nilbounds
        lownotnil, highnotnil = findNilBounds()

        --find furthest overshoot
        local farangle = overshoot(lownotnil, highnotnil)

        --find final angle
        local lastangle
        if (highsolution) then
            lastangle = finalAngle(farangle, highnotnil)
        else
            lastangle = finalAngle(lownotnil, farangle)
        end

        --store to angle
        setAngle(lastangle)
        return M.getErrorY(), lastangle
    end
end

function M.getErrorY()
    return YofX(targetx) - targety
end

return M