--[[
	PlayerService
	Cuida do jogador: entrar/sair, nascer com a espada equipada,
	vida por nível, abates, sequência de abates (recompensa pela cabeça)
	e o feed de abates.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwordsFolder = ReplicatedStorage:WaitForChild("Swords")

local DataService
local CombatService

local PlayerService = {}

local function removeSwords(player: Player): boolean
	local wasEquipped = false
	local containers: { Instance } = {}
	if player.Character then
		table.insert(containers, player.Character)
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("SwordId") then
				if container == player.Character then
					wasEquipped = true
				end
				child:Destroy()
			end
		end
	end
	return wasEquipped
end

-- Dá ao jogador a espada que ele tem equipada (nos dados)
function PlayerService.GiveSword(player: Player, forceEquip: boolean?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local template = SwordsFolder:FindFirstChild(data.Equipped) or SwordsFolder:FindFirstChild(Config.DefaultSword)
	if not template then
		warn("[PlayerService] Espada não encontrada: " .. tostring(data.Equipped))
		return
	end
	CombatService.SetBlocking(player, false)
	local wasEquipped = removeSwords(player)
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	local tool = template:Clone() :: Tool
	local sword = Config.SwordById[template.Name]
	if sword then
		tool.Name = sword.Name
	end
	tool.Equipped:Connect(function()
		local handle = tool:FindFirstChild("Handle")
		local sound = handle and handle:FindFirstChild("Unsheath")
		if sound and sound:IsA("Sound") then
			sound:Play()
		end
	end)
	tool.Parent = backpack

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and (wasEquipped or forceEquip) then
		humanoid:EquipTool(tool)
	end
end

local function onPlayerDied(player: Player, humanoid: Humanoid)
	local data = DataService.Get(player)
	DataService.Increment(player, "Deaths", 1)
	local victimStreak = (player:GetAttribute("Streak") :: number?) or 0
	player:SetAttribute("Streak", 0)

	local hit = CombatService.GetLastAttacker(humanoid)
	local killerName = hit and hit.Name or nil
	local killer: Player? = hit and hit.Player or nil
	local R = Config.Rewards

	if killer and killer ~= player and killer.Parent then
		DataService.Increment(killer, "Kills", 1)
		local streak = ((killer:GetAttribute("Streak") :: number?) or 0) + 1
		killer:SetAttribute("Streak", streak)

		local victimLevel = data and data.Level or 1
		local xp = R.PlayerKillXP + victimLevel * R.PlayerKillXPPerLevel
		local coins = R.PlayerKillCoins + victimLevel * R.PlayerKillCoinsPerLevel + victimStreak * R.BountyPerStreak
		DataService.AddCoins(killer, coins)
		DataService.AddXP(killer, xp)

		Remotes.Notify:FireClient(killer, {
			Small = true,
			Text = ("+%d moedas   +%d XP"):format(coins, xp),
			Sub = "Você derrotou " .. player.DisplayName,
			Color = { 255, 215, 80 },
		})

		if R.StreakAnnounce[streak] then
			Remotes.Notify:FireAllClients({
				Text = killer.DisplayName .. " ESTÁ IMPARÁVEL!",
				Sub = streak .. " abates seguidos - derrote-o para ganhar a recompensa!",
				Color = { 255, 120, 60 },
			})
		end
		if victimStreak >= 3 then
			Remotes.Notify:FireAllClients({
				Small = true,
				Text = killer.DisplayName .. " encerrou a sequência de " .. player.DisplayName,
				Sub = ("Recompensa: +%d moedas"):format(victimStreak * R.BountyPerStreak),
				Color = { 255, 200, 90 },
			})
		end
	end

	Remotes.KillFeed:FireAllClients({
		Killer = killerName,
		Victim = player.DisplayName,
		KillerIsPlayer = killer ~= nil,
	})

	Remotes.Notify:FireClient(player, {
		Text = "VOCÊ CAIU",
		Sub = killerName and ("Derrotado por " .. killerName) or "Levante-se, guerreiro!",
		Color = { 255, 70, 70 },
	})
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	-- Espera os dados carregarem
	local start = os.clock()
	while not DataService.Get(player) and player.Parent and os.clock() - start < 15 do
		task.wait(0.1)
	end
	local data = DataService.Get(player)
	if not data or not player.Parent or player.Character ~= character then
		return
	end

	humanoid.MaxHealth = Config.MaxHealthForLevel(data.Level)
	humanoid.Health = humanoid.MaxHealth
	CombatService.ResetPlayer(player)

	humanoid.Died:Connect(function()
		onPlayerDied(player, humanoid)
	end)

	PlayerService.GiveSword(player, true)
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("Streak", 0)
	player:SetAttribute("Zone", Config.DefaultZone)
	player:SetAttribute("Safe", true)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end

	DataService.Load(player)
end

function PlayerService.Init(services)
	DataService = services.DataService
	CombatService = services.CombatService

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		DataService.Release(player)
	end)
end

return PlayerService
