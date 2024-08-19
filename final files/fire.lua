local shell_args = { ... }

local completion = require "cc.completion"

--[[ for VS caret notation, TODO later
local function mult(q, p)
    return {
        -- W is real, minus imaginary squared
        w = q.w * p.w - q.x * p.x - q.y * p.y - q.z * p.z,
        --imaginary is real * imaginary + imaginary * real + forwards imaginary pair - backwards imaginary pair
        x = q.w * p.x + q.x * p.w + q.y * p.z - q.z * p.y,
        y = q.w * p.y + q.y * p.w + q.z * p.x - q.x * p.z,
        z = q.w * p.z + q.z * p.w + q.x * p.y - q.y * p.x
    }
end

local function conj(q)
    return { w = q.w, x = -q.x, y = -q.y, z = -q.z }
end
]]
rednet.open("back")

-- cached term size, since it ain't changeing
local _, height = term.getSize()
-- number of lines at the bottom that the menu ignores
local gap = 2
-- top and bottom lines of listing
local top, bottom = 2, height - gap

local wink = 0.1

local P = {}
-- Salt for protocol
local network_name
P.x, P.y, P.z, network_name = table.unpack(shell_args)
if not network_name then
    network_name = ""
end

local function printMenu(statusList, topEntry)
    local original_x, original_y = term.getCursorPos()
    -- line 1 is reserved for labels and scroll status
    term.setCursorPos(1, 1)
    term.write(" hostname | type | status ")
    -- line height is reserved for user input
    -- line height - 1 is reserved for info readout, and static instructions
    -- term.setCursorPos(1, height - 1)
    -- term.write("--------------------------")
    -- lines 2 to height - 2 are reserved for status list


    for i = top, bottom do
        local statusEntry = statusList[i + topEntry - top]
        term.setCursorPos(1, i)
        term.clearLine()
        if statusEntry then
            term.write(statusEntry.config.cannon_name)
            term.setCursorPos(17, i)
            term.write(statusEntry.config.cannon_type)
            term.setCursorPos(19, i)
            term.write(statusEntry.status)
        end
    end

    -- term.setCursorPos(1, 1)
    -- for k, v in pairs(statusList) do
    --     print(k, v.config.cannon_name, v.config.cannon_type, v.status)
    -- end
    term.setCursorPos(original_x, original_y)
end

local userPos = {}
local function pos()
    if not (userPos.x or userPos.y or userPos.z) then
        userPos.x, userPos.y, userPos.z = gps.locate()
    end
    if not (userPos.x or userPos.y or userPos.z) then
        error("GPS failed!")
    end
    return userPos
end
local secondPos = {}
local function newPos()
    if not (secondPos.x or secondPos.y or secondPos.z) then
        write("Hit enter to define second pos")
        secondPos.x, secondPos.y, secondPos.z = gps.locate()
    end
    return secondPos
end

-- Process direct, tilde, and caret notation coords (caret is my own special blend)
for k, v in pairs(P) do
    if string.sub(v, 1, 1) == "~" then
        P[k] = pos()[k] + (tonumber(string.sub(v, 2)) or 0)
    elseif string.sub(v, 1, 1) == "^" then
        if pocket then
            local scale = tonumber(string.sub(v, 2))
            local offset = newPos()[k] - pos()[k]
            P[k] = pos()[k] + (scale * offset)
        else
            print("Block computer detected!")
            if ship then
                print("Ship detected!")
            end
        end
    else
        P[k] = tonumber(v)
    end
end


P.x, P.y, P.z = tonumber(P.x), tonumber(P.y), tonumber(P.z)
if not (P.x and P.y and P.z) then
    print(shell.getRunningProgram() .. " <x> <y> <z>")
    return
end
-- Coords processed, p is now accurate

local function get_cannon_status_list(cannon_ids, do_autocomplete)
    -- Generating list of cannons in range
    -- local all_cannon_ids = table.pack(rednet.lookup("CANNON" .. network_name))
    local in_range_cannons = {}
    for _, id in ipairs(cannon_ids) do
        rednet.send(id, { type = "TRY", x = P.x, y = P.y, z = P.z }, "CANNON" .. network_name)
        local _, message = rednet.receive("CANNON_TRY" .. network_name, wink)
        if message then
            rednet.send(id, { type = "STATUS" }, "CANNON" .. network_name)
            local _, status = rednet.receive("CANNON_STATUS" .. network_name, wink)
            status.time = message.time
            in_range_cannons[id] = status
        end
    end
    -- List of all cannons in range created

    -- Generate ordered list of cannons
    local list_cannon_status = {}
    for id, status in pairs(in_range_cannons) do
        status.id = id
        table.insert(list_cannon_status, status)
    end
    -- Ordered list of cannons generated
    local autocomplete_map = {}
    if do_autocomplete then
        local dash_args = { "-sync", "-loop", "-rate", "-halt", "-kill", "-auto", "-mech", "-quick", }
        -- Generate autocomplete list
        for _, v in pairs(list_cannon_status) do
            autocomplete_map[v.config.cannon_name] = true
        end
        for _, v in pairs(dash_args) do
            autocomplete_map[v] = true
        end
        table.sort(list_cannon_status, function(a, b)
            return a.time < b.time
        end)
    end
    return list_cannon_status, autocomplete_map
end

local list_cannon_status, autocomplete_map = get_cannon_status_list(
    table.pack(rednet.lookup("CANNON" .. network_name)), true
)

local function fire_command_autocomplete(text)
    local _, index = string.find(text, ".+%s")
    if not index then
        index = 0
    end
    local used_args = {}
    local last_arg
    for v in string.gmatch(text, "(%S+)%s") do
        table.insert(used_args, v)
        last_arg = v
    end
    if last_arg == "-rate" then
        return nil
    end
    local autocomplete_map_copy = {}
    for k, v in pairs(autocomplete_map) do
        autocomplete_map_copy[k] = v
    end

    for _, v in ipairs(used_args) do
        if autocomplete_map_copy[v] then
            autocomplete_map_copy[v] = nil
        end
        if v == "-sync" or v == "-loop" or v == "-rate" then
            for _, w in pairs({ "-kill", "-halt" }) do
                autocomplete_map_copy[w] = nil
            end
        elseif v == "-kill" then
            for _, w in pairs({ "-sync", "-loop", "-halt" }) do
                autocomplete_map_copy[w] = nil
            end
        elseif v == "-halt" then
            for _, w in pairs({ "-sync", "-loop", "-kill" }) do
                autocomplete_map_copy[w] = nil
            end
        end
    end
    local autocomplete = {}
    for k, v in pairs(autocomplete_map_copy) do
        if v then
            table.insert(autocomplete, k)
        end
    end
    return completion.choice(string.sub(text, index + 1), autocomplete, true)
end

-- Menu time
local string_choice
local history_file = fs.open("fire_history.txt", "r")
local fire_history = {}
if history_file then
    while true do
        local line = history_file.readLine()
        if not line then
            break
        else
            if line ~= "" then
                table.insert(fire_history, line)
            end
        end
    end
    history_file.close()
end

local top_entry = 1
local function scrollMenu()
    local step = height - gap - top
    printMenu(list_cannon_status, top_entry)
    while true do
        local _, inputKey = os.pullEvent("key")
        if inputKey == keys.pageUp and list_cannon_status[top_entry - step] then
            top_entry = top_entry - step
            printMenu(list_cannon_status, top_entry)
        elseif inputKey == keys.pageDown and list_cannon_status[top_entry + step] then
            top_entry = top_entry + step
            printMenu(list_cannon_status, top_entry)
        end
    end
end
term.clear()
parallel.waitForAny(
    function()
        while true do
            list_cannon_status, autocomplete_map = get_cannon_status_list(
                table.pack(rednet.lookup("CANNON" .. network_name)), true
            )
            printMenu(list_cannon_status, top_entry)
            os.sleep(wink)
        end
    end,
    scrollMenu,
    function()
        os.sleep(wink)
        term.setCursorPos(1, height - 1)
        term.write("--------------------------")
        term.setCursorPos(1, height)
        term.write("fire> ")
        string_choice = read(nil, fire_history, fire_command_autocomplete)
    end
)
history_file = fs.open("fire_history.txt", "w")
for _, v in ipairs(fire_history) do
    if string_choice ~= v then
        history_file.writeLine(v)
    end
end
history_file.writeLine(string_choice)
local fire_args = {}
for v in string.gmatch(string_choice, "%S+") do
    table.insert(fire_args, v)
end

local live_cannons_set = {}
-- parse args
do
    local i = 1
    while fire_args[i] do
        local arg = fire_args[i]
        if string.sub(arg, 1, 1) == "-" then
            arg = string.sub(arg, 2)
            if arg == "rate" then
                i = i + 1
                local rate = tonumber(fire_args[i]) or 15
                fire_args[arg] = rate
            else
                fire_args[arg] = true
            end
        else
            local cannon_id = rednet.lookup("CANNON" .. network_name, arg)
            if cannon_id then
                live_cannons_set[cannon_id] = true
            end
        end
        i = i + 1
    end
end

-- error invalid args
if ((fire_args.sync or fire_args.loop or fire_args.rate) and 1 or 0) + (fire_args.halt and 1 or 0) + (fire_args.kill and 1 or 0) > 1 then
    error("Incompatible args! Cannot more than of these groups: [sync/loop/rate], [halt], [kill]")
end

-- Group selection
for _, cannon in ipairs(list_cannon_status) do
    if
        (fire_args.auto and cannon.config.cannon_type == "A")
        or (fire_args.mech and cannon.config.cannon_type == "M")
        or (fire_args.quick and cannon.config.cannon_type == "Q")
    then
        live_cannons_set[cannon.id] = true
    end
end


local live_cannons_list = {}
for cannon_id in pairs(live_cannons_set) do
    table.insert(live_cannons_list, cannon_id)
end
top_entry = 1
parallel.waitForAny(
    function()
        while true do
            list_cannon_status = get_cannon_status_list(live_cannons_list)
            printMenu(list_cannon_status, top_entry)
            os.sleep(wink)
        end
    end,
    scrollMenu,
    function()
        if fire_args.halt then
            write("halting ")
            for cannon_id in pairs(live_cannons_set) do
                rednet.send(cannon_id, { type = "HALT" }, "CANNON" .. network_name)
            end
        elseif fire_args.kill then
            write("aborting ")
            for cannon_id in pairs(live_cannons_set) do
                rednet.send(cannon_id, { type = "ABORT" }, "CANNON" .. network_name)
            end
        else
            local someRemain = true
            local last_status = {}
            while someRemain do
                if last_status == list_cannon_status then
                    os.sleep(wink)
                else
                    someRemain = false
                    for _, cannon in ipairs(list_cannon_status) do
                        if not cannon.registered then
                            rednet.send(cannon.id, { type = "REGISTER", x = P.x, y = P.y, z = P.z },
                                "CANNON" .. network_name)
                        end
                        if cannon.status ~= "AIMED" then
                            someRemain = true
                        end
                    end
                    last_status = list_cannon_status
                end
            end
            local delay = 0
            local last = 600

            if fire_args.sync then
                print("syncing ")
                for _, cannon in ipairs(list_cannon_status) do
                    delay = math.max(delay, cannon.time)
                    last = math.min(last, cannon.time)
                end
            end

            -- fire the dang cannons
            for _, cannon in ipairs(list_cannon_status) do
                rednet.send(cannon.id, { delay = delay, rate = fire_args.rate or 15 }, "CANNON_FIRE" .. network_name)
            end

            -- if loop then wait for input before halting
            if fire_args.loop then
                print("Press end to halt firing, or enter to remain firing ")
                while true do
                    local _, key = os.pullEvent("key")
                    if key == keys["enter"] then
                        break
                    elseif key == keys["end"] then
                        print("halting ")
                        for cannon_id in pairs(live_cannons_set) do
                            rednet.send(cannon_id, { type = "HALT" }, "CANNON" .. network_name)
                        end
                        break
                    end
                end
            else
                os.sleep(wink + math.max(0, delay - last))
                for cannon_id in pairs(live_cannons_set) do
                    rednet.send(cannon_id, { type = "HALT" }, "CANNON" .. network_name)
                end
            end
        end
    end
)
