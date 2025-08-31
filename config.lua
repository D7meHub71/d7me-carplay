Config = {}

Config.DriverOnly = true

Config.DefaultVolume    = 0.35 
Config.DefaultDistance  = 25.0  
Config.MaxDistance      = 40.0 

Config.CommandsUse = false
Config.Commands = { main = 'carplay' }

Config.CanUse = function(src) return true end
