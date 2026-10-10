--[[
	ShopService
	Compra e equipamento de espadas (Ferraria da Vila).
	O cliente pede pelo RemoteFunction "Shop" e o servidor valida tudo.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DataService
local PlayerService

local ShopService = {}

local function handleRequest(player: Player, action: any, swordId: any): (boolean, string)
	if type(action) ~= "string" or type(swordId) ~= "string" then
		return false, "Pedido inválido"
	end
	local sword = Config.SwordById[swordId]
	if not sword then
		return false, "Espada desconhecida"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Seus dados ainda estão carregando"
	end

	if action == "Buy" then
		if data.Owned[swordId] then
			return false, "Você já possui esta espada"
		end
		if sword.Price == nil then
			return false, "Só pode ser obtida derrotando o Rei Caído"
		end
		if data.Level < sword.Level then
			return false, "Requer nível " .. sword.Level
		end
		if not DataService.SpendCoins(player, sword.Price) then
			return false, "Moedas insuficientes"
		end
		DataService.AddOwned(player, swordId)
		DataService.SetEquipped(player, swordId)
		PlayerService.GiveSword(player, true)
		return true, "Você comprou " .. sword.Name .. "!"
	elseif action == "Equip" then
		if not data.Owned[swordId] then
			return false, "Você não possui esta espada"
		end
		DataService.SetEquipped(player, swordId)
		PlayerService.GiveSword(player, true)
		return true, sword.Name .. " equipada!"
	end
	return false, "Ação desconhecida"
end

function ShopService.Init(services)
	DataService = services.DataService
	PlayerService = services.PlayerService

	Remotes.Shop.OnServerInvoke = handleRequest

	local function hookPrompt(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				Remotes.OpenShop:FireClient(player)
			end)
		end
	end
	for _, prompt in CollectionService:GetTagged("ShopPrompt") do
		hookPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("ShopPrompt"):Connect(hookPrompt)
end

return ShopService
