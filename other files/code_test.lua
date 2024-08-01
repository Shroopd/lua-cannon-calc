local foo = string.pack("nnn", 10, 20.1, -3)

print(string.unpack("nnn", foo))
