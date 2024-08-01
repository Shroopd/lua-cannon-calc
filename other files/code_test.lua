--bump
local diffx, diffz = 100, 100


local tempyaw = math.deg(math.atan(diffz, diffx))
print(diffx, diffz, tempyaw)
tempyaw = 180 - tempyaw
print(tempyaw)
tempyaw = ((tempyaw + 180) % 360) - 180
print(tempyaw)


print(math.atan(1, 2))
