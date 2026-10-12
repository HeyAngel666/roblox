--[[
	LÂMINAS DO REINO - Cliente
	Inicia efeitos, dragões, interface, controles de combate e o menu inicial.
]]

local EffectsController = require(script:WaitForChild("EffectsController"))
local DragonController = require(script:WaitForChild("DragonController"))
local UIController = require(script:WaitForChild("UIController"))
local CombatController = require(script:WaitForChild("CombatController"))
local MenuController = require(script:WaitForChild("MenuController"))

EffectsController.Init()
DragonController.Init()
UIController.Init()
CombatController.Init()
local ok, err = pcall(MenuController.Init, UIController)
if not ok then
	-- Se o menu falhar, entra direto no jogo
	warn("[Menu] " .. tostring(err))
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	UIController.SetVisible(true)
end
