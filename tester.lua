local B = require("ballistics")
-- local L = require("loader")


print(math.deg(math.atan(-1, -0.01)))


B.init(1, 1, 1, 2, 4)
local result = B.solve(-10, 10, 0)
if (result ~= nil) then
    print("Yaw:", result.high.yaw or result.low.yaw)
    print("Pitch:", result.high.pitch)
    print("Error:", result.high.error)
    print("Pitch:", result.low.pitch)
    print("Error:", result.low.error)
end
