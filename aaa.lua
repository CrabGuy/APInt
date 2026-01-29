local APInt = require("./APInt")


local a = (APInt(10) ^ 100 / 10 ^ 15)
print(APInt.format(a))
