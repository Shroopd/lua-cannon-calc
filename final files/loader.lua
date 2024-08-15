local this = {}

local C = {}

local gears = { "flip", "align", "screw", "gantry" }
local source

-- CONFIG

local function hasVal(a, b)
    for k, v in pairs(a) do
        if (v == b) then
            return k
        end
    end
    return false
end

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

if fs.exists("loader_config.txt") then
    local file = fs.open("loader_config.txt", "r")
    local line = file.readLine()
    while line do
        local first, last = string.match(line, "([^=]+)="), string.match(line, "=([^=]+)")
        C[first] = last
        line = file.readLine()
    end
    file.close()
else
    for _, name in ipairs(gears) do
        print("Waiting for: " .. name)
        local oldlist = peripheral.getNames()
        while true do
            local list = peripheral.getNames()
            filter(list, "Create_SequencedGearshift")
            local foo = oneDiff(oldlist, list)
            if foo then
                C[name] = foo
                print("assigned to " .. foo)
                break
            else
                os.sleep(wink)
            end
            oldlist = list
        end
    end
    print("Waiting for: source")
            while true do
                local list = peripheral.getNames()
                filter(list, "create:toolbox")
                local foo = oneDiff(C, list)
                if foo then
                    C[name] = foo
                    print("assigned to " .. foo)
                    break
                else
                    os.sleep(0.05)
                end
            end
    local file = fs.open("loader_config.txt", "w")
    for k, v in pairs(C) do
        file.writeLine(k .. "=" .. v)
    end
    file.close()
end

for k,v in pairs(C) do
    C[k] = peripheral.wrap(v)
end
--LOADER

local function setState(state)
    local file = fs.open("loader_state.txt", "w")
    file.write(state)
    file.close()
    -- print(state)
end

local function getState()
    if not fs.exists("loader_state.txt") then
        setState("UNREADY")
    end
    local file = fs.open("loader_state.txt", "r")
    local foo = file.readAll()
    file.close()
    return string.match(foo, "[A-Z]+")
end

local function noRunningGears()
    for k, v in ipairs(table.pack(peripheral.find("Create_SequencedGearshift"))) do
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
                os.sleep(wink)
                remainingItems = remainingItems - v.count
            end
        end
        return true
    end
end

local function loadHoppers()
    for _, v in ipairs(table.pack(peripheral.find("minecraft:hopper"))) do
        local try
        try = loadHopper(v, "shell")
        if try then
            try = loadHopper(v, "fuze")
            if not try then
                error("Shells but no fuze")
            end
        elseif not loadHopper(v, "shot") then
            error("No shells or shot")
        end
        if not loadHopper(v, "charge", C.charges) then
            error("No charges")
        end
    end
end

local function nothingInHoppers()
    for _, hopper in ipairs(table.pack(peripheral.find("minecraft:hopper"))) do
        for k, v in pairs(hopper.list()) do
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
    os.sleep(wink)
    while not nothingInHoppers() do
        os.sleep(wink)
    end
end

function this.HOPPERED()
    while not nothingInHoppers() do
        os.sleep(wink)
    end
    C.gantry.move(C.charges + 1 + 1, -1)
    setState("PLACED")
end

function this.PLACED()
    C.align.rotate(90)
    setState("ALIGNED")
end

function this.ALIGNED()
    C.gantry.move(C.charges + 1 + 1)
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

function this.load()
    local state = getState()
    while state ~= "READY" do
        if noRunningGears() then
            this[state]()
            state = getState()
        end
        os.sleep(0.05)
    end
    while not noRunningGears() do
        os.sleep(0.05)
    end
end

function this.unload()
    setState("UNREADY")
end

function this.loaded()
    return getState() == "READY" and noRunningGears()
end
