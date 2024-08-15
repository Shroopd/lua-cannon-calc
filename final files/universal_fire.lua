local args = { ... }

local p = {}
p.x, p.y, p.z = table.unpack(args)

do
    local userPos = {}
    local function pos()
        if not (userPos.x or userPos.y or userPos.z) then
            userPos.x, userPos.y, userPos.z = gps.locate()
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
    for k, v in pairs(p) do
        if string.sub(v, 1, 1) == "~" then
            p[k] = pos()[k] + tonumber(string.sub(v, 2))
        elseif string.sub(v, 1, 1) == "^" then
            local scale = tonumber(string.sub(v, 2))
            local offset = newPos()[k] - pos()[k]
            p[k] = pos()[k] + (scale * offset)
        else
            p[k] = tonumber(v)
        end
    end
    -- Coords processed, p is now accurate

    -- Generating list of cannons in range
    local all_cannons = table.pack(rednet.lookup("CANNON"))
    local range_cannons = {}
    for _, id in ipairs(all_cannons) do
        rednet.send(id, { type = "TRY", x = p.x, y = p.y, z = p.z }, "CANNON")
        local _, message = rednet.receive("CANNON_RESPONSE")
        if message then
            rednet.send(id, { type = "STATUS" }, "CANNON")
            local _, status = rednet.receive("CANNON_RESPONSE")
            range_cannons[id] = status
        end
    end
    -- List of all cannons in range created

    -- Menu time
end
