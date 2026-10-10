--[[
	LÂMINAS DO REINO - Servidor
	Inicia todos os serviços do jogo na ordem certa.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")

local services = {
	DataService = require(Services.DataService),
	ZoneService = require(Services.ZoneService),
	CombatService = require(Services.CombatService),
	PlayerService = require(Services.PlayerService),
	ShopService = require(Services.ShopService),
	NPCService = require(Services.NPCService),
	WorldService = require(Services.WorldService),
}

local order = {
	"DataService",
	"ZoneService",
	"CombatService",
	"PlayerService",
	"ShopService",
	"NPCService",
	"WorldService",
}

for _, name in order do
	local ok, err = pcall(services[name].Init, services)
	if not ok then
		warn(("[GameServer] Erro ao iniciar %s: %s"):format(name, tostring(err)))
	end
end

print("[Lâminas do Reino] Servidor iniciado!")
