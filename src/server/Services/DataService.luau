--[[
	DataService
	Carrega/salva os dados do jogador (moedas, XP, nível, espadas...)
	Se o DataStore não estiver disponível (ex.: Studio sem "Enable Studio
	Access to API Services"), o jogo funciona normalmente, só não salva.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local STORE_NAME = "LaminasDoReino_v1"
local AUTOSAVE_INTERVAL = 120

local store: DataStore? = nil
local profiles: { [Player]: any } = {}
local canSave: { [Player]: boolean } = {}
local warnedNoSave = false

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function defaultData()
	return {
		Coins = Config.StartingCoins,
		XP = 0,
		Level = 1,
		Kills = 0,
		Deaths = 0,
		NPCKills = 0,
		BossKills = 0,
		Owned = { [Config.DefaultSword] = true },
		Equipped = Config.DefaultSword,
	}
end

local function reconcile(data)
	local default = defaultData()
	if type(data) ~= "table" then
		return default
	end
	for key, value in pairs(default) do
		if data[key] == nil then
			data[key] = value
		end
	end
	if type(data.Owned) ~= "table" then
		data.Owned = default.Owned
	end
	data.Owned[Config.DefaultSword] = true
	if not Config.SwordById[data.Equipped] or not data.Owned[data.Equipped] then
		data.Equipped = Config.DefaultSword
	end
	return data
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível: " .. tostring(result))
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		local threads = 0
		for _, player in Players:GetPlayers() do
			threads += 1
			task.spawn(function()
				DataService.Save(player)
				threads -= 1
			end)
		end
		local start = os.clock()
		while threads > 0 and os.clock() - start < 20 do
			task.wait(0.1)
		end
	end)
end

function DataService.Load(player: Player)
	local data = nil
	local loaded = false

	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (store :: DataStore):GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				loaded = true
				break
			end
			warn(("[DataService] Falha ao carregar %s (tentativa %d): %s"):format(player.Name, attempt, tostring(result)))
			if RunService:IsStudio() then
				break -- no Studio não adianta tentar de novo
			end
			task.wait(1)
		end
	end

	if not loaded and not warnedNoSave then
		warnedNoSave = true
		warn(
			"[DataService] O progresso NÃO será salvo nesta sessão. "
				.. "No Studio ative: Game Settings > Security > Enable Studio Access to API Services."
		)
	end

	if not player.Parent then
		return nil
	end

	profiles[player] = reconcile(data)
	canSave[player] = loaded

	DataService.CreateLeaderstats(player)
	DataService.Sync(player)
	return profiles[player]
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data or not canSave[player] or not store then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(keyFor(player), data)
	end)
	if not ok then
		warn("[DataService] Falha ao salvar " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
	canSave[player] = nil
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.CreateLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local level = Instance.new("IntValue")
	level.Name = "Nível"
	level.Parent = leaderstats

	local kills = Instance.new("IntValue")
	kills.Name = "Abates"
	kills.Parent = leaderstats

	local coins = Instance.new("IntValue")
	coins.Name = "Moedas"
	coins.Parent = leaderstats

	leaderstats.Parent = player
end

-- Copia os dados para atributos/leaderstats (o cliente lê daqui)
function DataService.Sync(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XPNeeded", Config.XPForLevel(data.Level))
	player:SetAttribute("Kills", data.Kills)
	player:SetAttribute("Deaths", data.Deaths)
	player:SetAttribute("Equipped", data.Equipped)
	player:SetAttribute("Owned", HttpService:JSONEncode(data.Owned))

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local values = {
			["Nível"] = data.Level,
			Abates = data.Kills,
			Moedas = data.Coins,
		}
		for name, value in pairs(values) do
			local stat = leaderstats:FindFirstChild(name)
			if stat and stat:IsA("IntValue") then
				stat.Value = value
			end
		end
	end
end

function DataService.AddCoins(player: Player, amount: number)
	local data = profiles[player]
	if not data then
		return
	end
	data.Coins = math.max(0, data.Coins + math.floor(amount))
	DataService.Sync(player)
end

function DataService.SpendCoins(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	DataService.Sync(player)
	return true
end

function DataService.AddXP(player: Player, amount: number)
	local data = profiles[player]
	if not data then
		return
	end
	data.XP += math.floor(amount)
	local leveledUp = false
	while data.Level < Config.MaxLevel and data.XP >= Config.XPForLevel(data.Level) do
		data.XP -= Config.XPForLevel(data.Level)
		data.Level += 1
		leveledUp = true
	end
	if data.Level >= Config.MaxLevel then
		data.XP = math.min(data.XP, Config.XPForLevel(data.Level))
	end
	DataService.Sync(player)

	if leveledUp then
		Remotes.Notify:FireClient(player, {
			Style = "LevelUp",
			Text = "NÍVEL " .. data.Level .. "!",
			Sub = "Vida máxima aumentada",
			Color = { 255, 215, 80 },
		})
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 then
			humanoid.MaxHealth = Config.MaxHealthForLevel(data.Level)
			humanoid.Health = humanoid.MaxHealth
		end
		if root then
			Remotes.Effect:FireAllClients({ Type = "LevelUp", Position = (root :: BasePart).Position })
		end
	end
end

function DataService.Increment(player: Player, key: string, amount: number)
	local data = profiles[player]
	if not data or type(data[key]) ~= "number" then
		return
	end
	data[key] += amount
	DataService.Sync(player)
end

function DataService.Owns(player: Player, swordId: string): boolean
	local data = profiles[player]
	return data ~= nil and data.Owned[swordId] == true
end

function DataService.AddOwned(player: Player, swordId: string)
	local data = profiles[player]
	if not data then
		return
	end
	data.Owned[swordId] = true
	DataService.Sync(player)
end

function DataService.SetEquipped(player: Player, swordId: string)
	local data = profiles[player]
	if not data then
		return
	end
	data.Equipped = swordId
	DataService.Sync(player)
end

return DataService
