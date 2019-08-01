fennel = require("fennel")
local gears = require("gears")
fennel.path = fennel.path .. ";.config/awesome/?.fnl"
table.insert(package.loaders or package.searchers, fennel.searcher)

require("config") -- load ~/.config/awesome/config.fnl
