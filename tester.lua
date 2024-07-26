local B = require("ballistics")
-- local L = require("loader")

B.setCharges(8)
B.setLength(32)

local x, y = 500, -1000

--source test
local v = { true, false }
for i = 1, #v do
    B.setTarget(x, y)
    B.setHighSolution(v[i])
    local errory, angle = B.calc()
    print(errory, angle / 8)
end