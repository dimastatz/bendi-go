local CollisionGroups = require(script.Parent.CollisionGroups)
local TownBuilder = require(script.Parent.TownBuilder)
local CarSpawner = require(script.Parent.CarSpawner)

CollisionGroups.setup()
TownBuilder.build()
CarSpawner.start()
