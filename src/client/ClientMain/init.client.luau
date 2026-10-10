--[[
	LÂMINAS DO REINO - Cliente
	Inicia interface, controles de combate e efeitos visuais.
]]

local EffectsController = require(script:WaitForChild("EffectsController"))
local UIController = require(script:WaitForChild("UIController"))
local CombatController = require(script:WaitForChild("CombatController"))

EffectsController.Init()
UIController.Init()
CombatController.Init()
