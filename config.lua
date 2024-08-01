local M = {}

local gears = { "pitch", "flip", "yaw", "align", "screw", "gantry" }
local nums = { "x", "y", "z", "charges", "cannonlength" }
local names = { "rest_axis", "dimension", "assemble", "fire", "ender_modem" }
local stores = { "storage" }

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
        local first, last = string.match(line, "([^:]+):"), string.match(line, ":([^:]+)")
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
    for _, name in ipairs(names) do
        print("Please input: " .. name)
        M[name] = read()
    end
    local file = fs.open("config.txt", "w")
    for k, v in pairs(M) do
        file.writeLine(k .. ":" .. v)
    end
    for _, name in ipairs(stores) do
        print("Waiting for: " .. name)
        while true do
            local list = peripheral.getNames()
            filter(list, "create:toolbox")
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
    file.close()
end

for _, k in pairs(gears) do
    M[k] = peripheral.wrap(M[k])
end

for _, k in pairs(nums) do
    M[k] = tonumber(M[k])
end

for _, k in pairs(nums) do
    M[k] = string.upper(M[k])
end

for _, k in pairs(stores) do
    M[k] = peripheral.wrap(M[k])
end

return M
