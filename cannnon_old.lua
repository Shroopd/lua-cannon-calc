local args = { ... }

local this = {}

local C = require("config")
local B = require("ballistics")

-- min and max values for high and low mounts
local LOW_MIN, LOW_MAX, HIGH_MIN, HIGH_MAX = -30, 60, 30, 90
-- is the cannon built vertical?
local highMount
-- what is the effective starting yaw of the cannon?
local startYaw
-- Wrapped inventory source of charges and such
local source
-- the coords we have registered for, as well as their solve
-- local xyz, x, y, z, validSolve, registered
-- min and max value for current mount
local minAngle, maxAngle

-- a unit of sleep
local wink = 0.05

local function init()
    B.init(C.x, C.y, C.z, C.charges, C.cannonlength)
    --find yawShift
    local rest_axis = string.upper(C.rest_axis)
    if rest_axis == "Y" then
        startYaw = 270
        minAngle, maxAngle = HIGH_MIN, HIGH_MAX
        highMount = true
    else
        highMount = false
        minAngle, maxAngle = LOW_MIN, LOW_MAX
        if rest_axis == "-Z" then
            startYaw = 0
        elseif rest_axis == "X" then
            startYaw = 90
        elseif rest_axis == "Z" then
            startYaw = 180
        elseif rest_axis == "-X" then
            startYaw = 270
        else
            error("Not a valid axis")
        end
    end
    --set dimension
    local dimension = string.upper(C.dimension)
    if dimension == "E" then
        B.setDrag(0.00001)
        B.setGrav(0.9)
    elseif dimension == "N" then
        B.setDrag(1.1)
        B.setGrav(1.1)
    elseif dimension ~= "O" then
        error("What kind of dimension is " .. dimension .. "?")
    end
    --set item source
    source = C.storage
end

local function check(x, y, z)
    local dx, dy, dz = C.x - x, C.x - y, C.z - z
    if dx * dx + dy * dy + dz * dz < C.cannonlength * C.cannonlength then
        return false
    end
    local solves = B.solve(x, y, z)
    if not solves then
        return false
    end
    if solves.high.error < 1 then
        if minAngle <= solves.high.pitch and solves.high.pitch <= maxAngle then
            return solves.high
        end
    elseif solves.low.error < 1 then
        if minAngle <= solves.low.pitch and solves.low.pitch <= maxAngle then
            return solves.low
        end
    else
        return false
    end
end

local function translate(pitch, yaw)
    --correct for highMount
    if (highMount) then
        pitch = HIGH_MAX - pitch
    end
    --multiply by 8, loop to 180 degree yaw moves
    return pitch * 8, (((yaw - startYaw + 180) % 360) - 180) * 8
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

local function setState(state)
    local file = fs.open("state.txt", "w")
    file.write(state)
    file.close()
    print(state)
end

local function getState()
    local file = fs.open("state.txt", "r")
    local foo = file.readAll()
    file.close()
    return foo
end

local function noRunningGears()
    for k, v in pairs(peripheral.find("Create_SequencedGearshift")) do
        if v.isRunning() then
            return false
        end
    end
    return true
end

local function loadHopper(hopper, item, count)
    if not count then
        count = 1
    end
    local remainingItems = count
    local tally = 0
    for _, v in pairs(source.list()) do
        if string.find(v.name, item) then
            tally = tally + v.count
        end
    end
    if tally < count then
        return false
    else
        for k, v in pairs(source.list()) do
            if string.find(v.name, item) then
                hopper.pullItems(peripheral.getName(source), k, remainingItems)
                remainingItems = remainingItems - v.count
            end
        end
    end
end

local function loadHoppers()
    for _, v in pairs(peripheral.find("minecraft:hopper")) do
        loadHopper(v, "(shell)|(shot)")
        loadHopper(v, "fuze")
        loadHopper(v, "charge", C.charges)
    end
end

local function nothingInHoppers()
    for _, v in pairs(peripheral.find("minecraft:hopper")) do
        if #(v.list()) ~= 0 then
            return false
        end
    end
    return true
end

function this.UNREADY()
    C.flip.rotate(180)
    setState("DISMOUNTED")
end

function this.DISMOUNTED()
    C.screw.move(1, -1)
    setState("UNSCREWED")
end

function this.UNSCREWED()
    loadHoppers()
    setState("HOPPERED")
    while not nothingInHoppers() do
        os.sleep(wink)
    end
end

function this.HOPPERED()
    while not nothingInHoppers() do
        os.sleep(wink)
    end
    C.gantry.move(C.charges + 1, -1)
    setState("PLACED")
end

function this.PLACED()
    C.align.rotate(90)
    setState("ALIGNED")
end

function this.ALIGNED()
    C.gantry.move(C.charges + 1)
    setState("INSERTED")
end

function this.INSERTED()
    C.screw.move(1)
    setState("SCREWED")
end

function this.SCREWED()
    C.flip.rotate(180)
    setState("READY")
end

local function stateCycle()
    local state = getState()
    while state ~= "READY" do
        if noRunningGears() then
            this[state]()
            state = getState()
        end
        os.sleep(wink)
    end
end

local function register()
    while true do
        local _, message = rednet.receive("CANNON_REGISTER")
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

rednet.open("bottom")

while true do
    local xyz, validSolve
    --  = nil, nil, nil, nil, nil, nil
    redstone.setOutput(C.fire, false)
    redstone.setOutput(C.assemble, false)
    --loading
    parallel.waitForAny(
        function()
            xyz, validSolve = register()
            while true do
                local sender = rednet.receive("CANNON_QUERY_UNREADY" .. xyz)
                os.sleep(wink)
                rednet.send(sender, true, "CANNON_RESPONSE_UNREADY" .. xyz)
            end
        end,
        stateCycle
    )
    if not xyz and validSolve then
        xyz, validSolve = register()
    end
    parallel.waitForAny(
        function()
            while true do
                local sender = rednet.receive("CANNON_QUERY_AIMING" .. xyz)
                os.sleep(wink)
                rednet.send(sender, true, "CANNON_RESPONSE_AIMING" .. xyz)
            end
        end,
        function()
            redstone.setOutput(C.assemble, true)
            local pitch, yaw = translate(validSolve.pitch, validSolve.yaw)
            local pitchmod, yawmod = signum(pitch), signum(yaw)
            pitch, yaw = math.abs(pitch), math.abs(yaw)
            pitch, yaw = math.floor(pitch + 0.5), math.floor(yaw + 0.5)
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
    )
    print("WAITING")
    local message, _
    parallel.waitForAny(
        function()
            _, message = rednet.receive("CANNON_FIRE" .. xyz)
        end,
        function()
            rednet.host("CANNON_READY" .. xyz, os.getComputerID())
            while true do
                local id = rednet.receive("CANNON_QUERY_TIME" .. xyz)
                os.sleep(wink)
                rednet.send(id, validSolve.time, "CANNON_RESPONSE_TIME" .. xyz)
            end
        end
    )
    rednet.unhost("CANNON_READY" .. xyz)
    local delay = string.unpack("n", message)
    print("SYNCING")
    os.sleep((delay - validSolve.time) / 20)
    print("FIRING")
    redstone.setOutput(C.fire, true)
    setState("UNREADY")
    os.sleep(1.0)
end

--[[
    Load the cannon if unloaded
    Register if in range: Once registered, respond to filtered queries.
]]
