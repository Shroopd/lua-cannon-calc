local source = peripheral.wrap("create:toolbox_5")
local C = { charges = 8 }
local wink = 0.05

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
    for _, v in pairs(table.pack(peripheral.find("minecraft:hopper"))) do
        if type(v) == "table" then
            if loadHopper(v, "shell") then
                if not loadHopper(v, "fuze") then
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
end

local function nothingInHoppers()
    for _, v in pairs(table.pack(peripheral.find("minecraft:hopper"))) do
        if type(v) == "table" then
            if #(v.list()) ~= 0 then
                return false
            end
        end
    end
    return true
end

print(nothingInHoppers())
loadHoppers()
print(nothingInHoppers())
