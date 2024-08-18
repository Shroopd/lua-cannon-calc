local arg = "foo Bar 7 WEEEEE nay"

local choices = {}
for v in string.gmatch(arg, "%S+") do
    table.insert(choices, v)
end
table.insert(choices, nil)
print(choices)
local i = 1
while choices[i] do
    print(i, choices[i])
    i = i + 1
end

for i = 1, string.len(arg) + 3 do
    print(string.sub(arg, i))
end

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

local a, b = { w = 1, x = 5, y = 7, z = -6 }, { w = 0, x = -2, y = -3, z = 1 }
local c = mult(a, b)
for _, k in pairs({ 'w', 'x', 'y', 'z' }) do
    print(k, c[k])
end
