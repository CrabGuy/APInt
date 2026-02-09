local APInt = require("./APInt")

local a = (APInt(10) ^ 100) / (10 ^ 15)
print(APInt.format(a))
-- correct = 0, 4419942254379008, 1218062511332401, 2252745923636380, 1562451958731451, 5397605