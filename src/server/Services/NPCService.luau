--[[
	NPCService
	Inimigos controlados pelo servidor:
	- Goblins, Esqueletos e Orcs na Floresta Sombria
	- O chefe "Rei Caído" nas Ruínas (golpe no chão + fase de fúria)
	- Bonecos de treino na Vila (regeneram a vida)
	Os modelos ficam em ServerStorage.NPCs e os pontos de nascimento em
	Workspace.NPCSpawns (peças com o atributo "NPC").
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CombatService
local DataService
local ZoneService

local NPCService = {}

-- Animações padrão R6 da própria Roblox
local ANIMATIONS = {
	Idle = { Id = 180435571, Priority = Enum.AnimationPriority.Idle, Looped = true },
	Walk = { Id = 180426354, Priority = Enum.AnimationPriority.Movement, Looped = true },
	ToolNone = { Id = 182393478, Priority = Enum.AnimationPriority.Action, Looped = true },
	Slash = { Id = 129967390, Priority = Enum.AnimationPriority.Action2, Looped = false },
	Lunge = { Id = 129967478, Priority = Enum.AnimationPriority.Action2, Looped = false },
}

local THINK_INTERVAL = 0.2

type NPC = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Kind: string,
	Config: any,
	Element: string,
	SpawnPart: BasePart?,
	Home: Vector3,
	Target: Model?,
	LastAttack: number,
	LastSlam: number,
	NextWander: number,
	Returning: boolean,
	Slamming: boolean,
	Enraged: boolean,
	Tracks: { [string]: AnimationTrack },
	Damage: { [Player]: number },
	StuckTime: number,
	LastBossUpdate: number,
}

local npcs: { [Model]: NPC } = {}
local npcFolder: Folder
local activeBoss: NPC? = nil

--------------------------------------------------------------------------
-- Visual
--------------------------------------------------------------------------
function NPCService.CreateBillboard(model: Model, title: string, isBoss: boolean)
	local head = model:FindFirstChild("Head")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end
	local scale = model:GetAttribute("Scale") or 1

	local gui = Instance.new("BillboardGui")
	gui.Name = "NPCBar"
	gui.Size = UDim2.fromOffset(isBoss and 240 or 170, 44)
	gui.StudsOffset = Vector3.new(0, 1.6 * scale + 1, 0)
	gui.MaxDistance = isBoss and 200 or 90
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 22)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = title
	label.TextColor3 = isBoss and Color3.fromRGB(255, 80, 90) or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.new(0, 0, 0, 26)
	back.Size = UDim2.new(1, 0, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = isBoss and Color3.fromRGB(220, 40, 60) or Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	fillGradient.Rotation = 90
	fillGradient.Parent = fill

	gui.Parent = head

	local function update()
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		if not isBoss then
			fill.BackgroundColor3 = Color3.fromRGB(230, 70, 60):Lerp(Color3.fromRGB(90, 220, 90), ratio)
		end
	end
	humanoid.HealthChanged:Connect(update)
	update()
end

local function loadTracks(humanoid: Humanoid): { [string]: AnimationTrack }
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local tracks = {}
	for name, data in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. data.Id
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(animation)
		end)
		if ok and track then
			track.Priority = data.Priority
			track.Looped = data.Looped
			tracks[name] = track
		end
	end
	return tracks
end

local function playWeaponSound(model: Model, soundName: string)
	local weapon = model:FindFirstChild("Weapon")
	local handle = weapon and weapon:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = 0.85 + math.random() * 0.2
		sound:Play()
	end
	local trail = handle and handle:FindFirstChild("SwordTrail")
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		task.delay(0.35, function()
			if trail.Parent then
				trail.Enabled = false
			end
		end)
	end
end

--------------------------------------------------------------------------
-- Recompensas
--------------------------------------------------------------------------
local function reward(player: Player, cfg, xpMultiplier: number?)
	local multiplier = xpMultiplier or 1
	local coins = math.floor(cfg.Coins * multiplier)
	local xp = math.floor(cfg.XP * multiplier)
	DataService.AddCoins(player, coins)
	DataService.AddXP(player, xp)
	DataService.Increment(player, "NPCKills", 1)
	Remotes.Notify:FireClient(player, {
		Small = true,
		Text = ("+%d moedas   +%d XP"):format(coins, xp),
		Sub = cfg.DisplayName .. " derrotado",
		Color = { 255, 215, 80 },
	})
end

local function sendBossBar(npc: NPC?, target: Player?)
	local payload
	if npc and npc.Humanoid.Health > 0 then
		payload = {
			Active = true,
			Name = npc.Config.DisplayName,
			Health = npc.Humanoid.Health,
			MaxHealth = npc.Humanoid.MaxHealth,
			Enraged = npc.Enraged,
		}
	else
		payload = { Active = false }
	end
	if target then
		Remotes.BossBar:FireClient(target, payload)
	else
		Remotes.BossBar:FireAllClients(payload)
	end
end

local spawnNPC -- declarado abaixo

local function onNPCDied(npc: NPC)
	if npcs[npc.Model] == nil then
		return
	end
	npcs[npc.Model] = nil
	local cfg = npc.Config
	for _, track in npc.Tracks do
		track:Stop()
	end

	Remotes.Effect:FireAllClients({ Type = "Death", Position = npc.Root.Position })

	if cfg.IsBoss then
		activeBoss = nil
		sendBossBar(nil)
		local winners = {}
		for player, damage in npc.Damage do
			if player.Parent and damage >= npc.Humanoid.MaxHealth * cfg.MinContribution then
				table.insert(winners, player)
			end
		end
		local names = {}
		for _, player in winners do
			table.insert(names, player.DisplayName)
			reward(player, cfg)
			DataService.Increment(player, "BossKills", 1)
			local dropId = cfg.DropSword
			if dropId and not DataService.Owns(player, dropId) and math.random() < cfg.DropChance then
				DataService.AddOwned(player, dropId)
				local sword = Config.SwordById[dropId]
				Remotes.Notify:FireClient(player, {
					Text = "ITEM LENDÁRIO!",
					Sub = "Você obteve: " .. sword.Name .. " (equipe na loja)",
					Color = { 255, 60, 80 },
				})
				Remotes.Notify:FireAllClients({
					Small = true,
					Text = player.DisplayName .. " obteve " .. sword.Name .. "!",
					Color = { 255, 80, 90 },
				})
			end
		end
		Remotes.Notify:FireAllClients({
			Text = "O REI CAÍDO FOI DERROTADO!",
			Sub = #names > 0 and ("Heróis: " .. table.concat(names, ", ")) or "",
			Color = { 255, 215, 80 },
		})
	else
		local hit = CombatService.GetLastAttacker(npc.Humanoid)
		if hit and hit.Player and hit.Player.Parent then
			reward(hit.Player, cfg, npc.Model:GetAttribute("Minion") and 0.5 or 1)
		end
	end

	task.delay(3, function()
		npc.Model:Destroy()
	end)

	local spawnPart = npc.SpawnPart
	if spawnPart then
		task.delay(cfg.RespawnTime, function()
			spawnNPC(npc.Kind, spawnPart, nil)
		end)
	end
end

local function enrage(npc: NPC)
	npc.Enraged = true
	local cfg = npc.Config
	npc.Model:SetAttribute("BaseSpeed", cfg.WalkSpeed + 4)
	CombatService.UpdateSpeed(npc.Model)

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 30, 40)
	highlight.FillTransparency = 0.75
	highlight.OutlineColor = Color3.fromRGB(255, 80, 80)
	highlight.Parent = npc.Model

	local torso = npc.Model:FindFirstChild("Torso")
	if torso then
		local fire = Instance.new("Fire")
		fire.Color = Color3.fromRGB(200, 20, 40)
		fire.SecondaryColor = Color3.fromRGB(40, 0, 0)
		fire.Size = 10
		fire.Parent = torso
	end

	Remotes.Notify:FireAllClients({
		Text = "O REI CAÍDO ESTÁ FURIOSO!",
		Sub = "Ele invocou seus guardas",
		Color = { 255, 60, 70 },
	})
	if cfg.MinionKind then
		for i = 1, cfg.MinionCount do
			local angle = (i / cfg.MinionCount) * math.pi * 2
			local offset = Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
			local groundY = npc.Root.Position.Y - ((npc.Model:GetAttribute("SpawnHeight") :: number?) or 3)
			local position = Vector3.new(npc.Root.Position.X, groundY, npc.Root.Position.Z) + offset
			spawnNPC(cfg.MinionKind, nil, CFrame.new(position), npc.Home)
		end
	end
	sendBossBar(npc)
end

--------------------------------------------------------------------------
-- Nascimento
--------------------------------------------------------------------------
spawnNPC = function(kind: string, spawnPart: BasePart?, groundCFrame: CFrame?, home: Vector3?)
	local cfg = Config.NPCs[kind]
	local template = ServerStorage.NPCs:FindFirstChild(kind)
	if not cfg or not template then
		warn("[NPCService] NPC desconhecido: " .. tostring(kind))
		return
	end
	local model = template:Clone() :: Model
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local spawnHeight = model:GetAttribute("SpawnHeight") or 3

	local baseCFrame = groundCFrame or (spawnPart and spawnPart.CFrame) or CFrame.new()
	local groundPosition = baseCFrame.Position
	if spawnPart then
		groundPosition = Vector3.new(groundPosition.X, spawnPart.Position.Y - spawnPart.Size.Y / 2, groundPosition.Z)
	end
	local yaw = math.random() * math.pi * 2
	model:PivotTo(CFrame.new(groundPosition + Vector3.new(0, spawnHeight + 0.2, 0)) * CFrame.Angles(0, yaw, 0))

	humanoid.MaxHealth = cfg.MaxHealth
	humanoid.Health = cfg.MaxHealth
	humanoid.WalkSpeed = cfg.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	model:SetAttribute("NPC", kind)
	model:SetAttribute("DisplayName", cfg.DisplayName)
	model:SetAttribute("BaseSpeed", cfg.WalkSpeed)
	if not spawnPart then
		model:SetAttribute("Minion", true)
	end
	model.Parent = npcFolder
	CollectionService:AddTag(model, "NPC")

	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	NPCService.CreateBillboard(model, ("%s  Nv.%d"):format(cfg.DisplayName, cfg.Level), cfg.IsBoss == true)

	local sword = Config.SwordById[cfg.Sword or ""]
	local npc: NPC = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Kind = kind,
		Config = cfg,
		Element = sword and sword.Element or "none",
		SpawnPart = spawnPart,
		Home = home or groundPosition,
		Target = nil,
		LastAttack = 0,
		LastSlam = os.clock(),
		NextWander = os.clock() + math.random() * 4,
		Returning = false,
		Slamming = false,
		Enraged = false,
		Tracks = loadTracks(humanoid),
		Damage = {},
		StuckTime = 0,
		LastBossUpdate = 0,
	}
	npcs[model] = npc

	if npc.Tracks.Idle then
		npc.Tracks.Idle:Play()
	end
	if npc.Tracks.ToolNone then
		npc.Tracks.ToolNone:Play()
	end

	humanoid.Running:Connect(function(speed)
		local walk = npc.Tracks.Walk
		if not walk then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.2)
			end
			walk:AdjustSpeed(math.max(speed / 14, 0.5))
		elseif walk.IsPlaying then
			walk:Stop(0.2)
		end
	end)

	humanoid.HealthChanged:Connect(function(health)
		if cfg.IsBoss and health > 0 then
			if not npc.Enraged and health / humanoid.MaxHealth <= cfg.EnrageAt then
				enrage(npc)
			end
			if os.clock() - npc.LastBossUpdate > 0.2 then
				npc.LastBossUpdate = os.clock()
				sendBossBar(npc)
			end
		end
	end)

	humanoid.Died:Connect(function()
		onNPCDied(npc)
	end)

	if cfg.IsBoss then
		activeBoss = npc
		sendBossBar(npc)
		Remotes.Notify:FireAllClients({
			Text = "O REI CAÍDO DESPERTOU!",
			Sub = "Vá até as Ruínas (oeste) para enfrentá-lo",
			Color = { 255, 60, 70 },
		})
	end

	return npc
end

--------------------------------------------------------------------------
-- Inteligência artificial
--------------------------------------------------------------------------
local function isValidTarget(npc: NPC, character: Model?): boolean
	if not character or not Util.IsAlive(character) then
		return false
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player or ZoneService.IsSafe(player) then
		return false
	end
	local root = Util.GetRoot(character) :: BasePart
	local fromHome = (root.Position - npc.Home).Magnitude
	return fromHome <= npc.Config.LeashRange
end

local function findTarget(npc: NPC): Model?
	local best, bestDistance = nil, npc.Config.AggroRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and isValidTarget(npc, character) then
			local root = Util.GetRoot(character) :: BasePart
			local distance = (root.Position - npc.Root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = character, distance
			end
		end
	end
	return best
end

local function attack(npc: NPC, target: Model)
	npc.LastAttack = os.clock()
	local cfg = npc.Config
	local track = (cfg.IsBoss and math.random() < 0.4) and npc.Tracks.Lunge or npc.Tracks.Slash
	if track then
		track:Play(0.05)
	end
	playWeaponSound(npc.Model, "Slash")

	task.delay(0.35, function()
		if npc.Humanoid.Health <= 0 or CombatService.IsStunned(npc.Model) then
			return
		end
		local targetRoot = Util.GetRoot(target)
		if not targetRoot or not Util.IsAlive(target) then
			return
		end
		if (targetRoot.Position - npc.Root.Position).Magnitude <= cfg.AttackRange + 2 then
			CombatService.DealDamage(npc.Model, target, cfg.Damage * (npc.Enraged and 1.25 or 1), {
				Source = "melee",
				Element = npc.Element,
				Knockback = cfg.IsBoss == true,
			})
		end
	end)
end

local function slam(npc: NPC)
	local cfg = npc.Config
	npc.LastSlam = os.clock()
	npc.Slamming = true
	npc.Humanoid:MoveTo(npc.Root.Position)
	local groundY = npc.Root.Position.Y - ((npc.Model:GetAttribute("SpawnHeight") :: number?) or 3)
	local center = Vector3.new(npc.Root.Position.X, groundY, npc.Root.Position.Z)

	Remotes.Effect:FireAllClients({
		Type = "Telegraph",
		Position = center,
		Radius = cfg.SlamRadius,
		Duration = cfg.SlamWarning,
	})
	if npc.Tracks.Lunge then
		npc.Tracks.Lunge:Play(0.1, 1, 0.6)
	end

	task.delay(cfg.SlamWarning, function()
		npc.Slamming = false
		if npc.Humanoid.Health <= 0 then
			return
		end
		Remotes.Effect:FireAllClients({
			Type = "Ring",
			Position = center,
			Radius = cfg.SlamRadius,
			Color = Color3.fromRGB(230, 30, 50),
			Element = "void",
		})
		playWeaponSound(npc.Model, "Lunge")
		for _, target in CombatService.QueryRadius(center, cfg.SlamRadius, { npc.Model }) do
			if Players:GetPlayerFromCharacter(target) then
				CombatService.DealDamage(npc.Model, target, cfg.SlamDamage, {
					Source = "slam",
					Knockback = true,
				})
			end
		end
	end)
end

local function think(npc: NPC, dt: number)
	local humanoid, root, cfg = npc.Humanoid, npc.Root, npc.Config
	if humanoid.Health <= 0 or not root.Parent then
		return
	end
	if npc.Slamming then
		return
	end
	if CombatService.IsStunned(npc.Model) then
		humanoid:MoveTo(root.Position)
		return
	end

	local fromHome = (root.Position - npc.Home).Magnitude

	-- Voltando para casa (perdeu o alvo / foi longe demais)
	if fromHome > cfg.LeashRange then
		npc.Returning = true
		npc.Target = nil
	end
	if npc.Returning then
		humanoid:MoveTo(npc.Home)
		if fromHome < 8 then
			npc.Returning = false
			humanoid.Health = humanoid.MaxHealth
			table.clear(npc.Damage)
		end
		return
	end

	if not isValidTarget(npc, npc.Target) then
		npc.Target = findTarget(npc)
	end
	local target = npc.Target

	if not target then
		-- Passeia perto de casa
		if os.clock() >= npc.NextWander then
			npc.NextWander = os.clock() + 4 + math.random() * 5
			local angle = math.random() * math.pi * 2
			local distance = math.random() * 12
			humanoid:MoveTo(npc.Home + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		end
		-- Recupera vida fora de combate
		if humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * 0.05 * dt)
		end
		return
	end

	local targetRoot = Util.GetRoot(target) :: BasePart
	local offset = targetRoot.Position - root.Position
	local distance = offset.Magnitude

	if cfg.IsBoss and os.clock() - npc.LastSlam >= cfg.SlamInterval and distance < cfg.SlamRadius + 6 then
		slam(npc)
		return
	end

	if distance > cfg.AttackRange then
		humanoid:MoveTo(targetRoot.Position)
		-- Pula se ficar preso
		if root.AssemblyLinearVelocity.Magnitude < 1 then
			npc.StuckTime += dt
			if npc.StuckTime > 1 then
				humanoid.Jump = true
				npc.StuckTime = 0
			end
		else
			npc.StuckTime = 0
		end
	else
		humanoid:MoveTo(root.Position)
		local look = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
		if (look - root.Position).Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, look)
		end
		local cooldown = cfg.AttackCooldown * (npc.Enraged and 0.75 or 1)
		if os.clock() - npc.LastAttack >= cooldown then
			attack(npc, target)
		end
	end
end

--------------------------------------------------------------------------
-- Bonecos de treino
--------------------------------------------------------------------------
local function setupDummy(dummy: Model)
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local backup = dummy:Clone()
	local parent = dummy.Parent
	local lastHit = 0
	local lastHealth = humanoid.Health

	NPCService.CreateBillboard(dummy, "Boneco de Treino", false)

	humanoid.HealthChanged:Connect(function(health)
		if health < lastHealth then
			lastHit = os.clock()
		end
		lastHealth = health
	end)

	humanoid.Died:Connect(function()
		task.delay(2, function()
			local clone = backup:Clone()
			dummy:Destroy()
			clone.Parent = parent
			setupDummy(clone)
		end)
	end)

	task.spawn(function()
		while dummy.Parent and humanoid.Health > 0 do
			if os.clock() - lastHit > 3 and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
			task.wait(0.5)
		end
	end)
end

--------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------
function NPCService.Init(services)
	CombatService = services.CombatService
	DataService = services.DataService
	ZoneService = services.ZoneService

	local existing = workspace:FindFirstChild("NPCs")
	if existing and existing:IsA("Folder") then
		npcFolder = existing
	else
		npcFolder = Instance.new("Folder")
		npcFolder.Name = "NPCs"
		npcFolder.Parent = workspace
	end

	-- Quem bate num NPC vira o alvo dele / conta para o chefe
	table.insert(CombatService.DamageListeners, function(target, attackerPlayer, amount)
		local npc = npcs[target]
		if not npc or not attackerPlayer then
			return
		end
		npc.Damage[attackerPlayer] = (npc.Damage[attackerPlayer] or 0) + amount
		if attackerPlayer.Character and isValidTarget(npc, attackerPlayer.Character) then
			npc.Target = attackerPlayer.Character
		end
	end)

	for _, dummy in CollectionService:GetTagged("Dummy") do
		if dummy:IsA("Model") then
			setupDummy(dummy)
		end
	end

	local spawnFolder = workspace:WaitForChild("NPCSpawns")
	for _, spawnPart in spawnFolder:GetChildren() do
		if spawnPart:IsA("BasePart") and spawnPart:GetAttribute("NPC") then
			task.spawn(spawnNPC, spawnPart:GetAttribute("NPC"), spawnPart, nil)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		task.delay(3, function()
			if activeBoss and player.Parent then
				sendBossBar(activeBoss, player)
			end
		end)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < THINK_INTERVAL then
			return
		end
		local step = accumulator
		accumulator = 0
		for _, npc in npcs do
			local ok, err = pcall(think, npc, step)
			if not ok then
				warn("[NPCService] " .. tostring(err))
			end
		end
	end)
end

return NPCService
