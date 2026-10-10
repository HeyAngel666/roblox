--[[
	CombatService
	Todo o combate acontece aqui, no servidor (seguro contra exploits):
	- Ataques com combo de 3 golpes (o 3º empurra o inimigo)
	- Bloqueio (F) e Parry (bloquear no momento certo atordoa o atacante)
	- Esquiva (Q) com invencibilidade curta
	- Habilidade especial (E) de cada espada
	- Efeitos de elemento: Fogo, Gelo, Sombra, Raio e Abismo
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local ZoneService -- definido em Init (evita dependência circular)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = Config.Combat

local CombatService = {}

type PlayerState = {
	Combo: number,
	LastAttack: number,
	Blocking: boolean,
	BlockStart: number,
	Stamina: number,
	LastStaminaUse: number,
	LastStaminaSent: number,
	LastDash: number,
	InvulnUntil: number,
	SpecialReadyAt: number,
}

type Status = {
	StunUntil: number,
	SlowUntil: number,
	SlowMult: number,
	BurnUntil: number,
	BurnNext: number,
	BurnAttacker: Model?,
}

local playerStates: { [Player]: PlayerState } = {}
local statuses: { [Model]: Status } = {}
local lastHits = (setmetatable({}, { __mode = "k" }) :: any) :: { [Humanoid]: { Player: Player?, Model: Model?, Name: string, Time: number } }

CombatService.DamageListeners = {} :: { (target: Model, attackerPlayer: Player?, amount: number) -> () }

local BLOCK_GRIP_ROTATION = CFrame.Angles(0, 0, math.rad(90))

--------------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------------
local function now(): number
	return os.clock()
end

local function getState(player: Player): PlayerState
	local state = playerStates[player]
	if not state then
		state = {
			Combo = 0,
			LastAttack = 0,
			Blocking = false,
			BlockStart = 0,
			Stamina = C.StaminaMax,
			LastStaminaUse = 0,
			LastStaminaSent = C.StaminaMax,
			LastDash = 0,
			InvulnUntil = 0,
			SpecialReadyAt = 0,
		}
		playerStates[player] = state
	end
	return state
end

local function getStatus(model: Model): Status
	local status = statuses[model]
	if not status then
		status = {
			StunUntil = 0,
			SlowUntil = 0,
			SlowMult = 1,
			BurnUntil = 0,
			BurnNext = 0,
			BurnAttacker = nil,
		}
		statuses[model] = status
	end
	return status
end

local function elementColor(element: string?): Color3
	local data = Config.Elements[element or "none"] or Config.Elements.none
	return Util.Color(data.Color)
end

local function fireEffect(payload)
	Remotes.Effect:FireAllClients(payload)
end

local function floatingText(position: Vector3, text: string, color: Color3)
	fireEffect({ Type = "Text", Position = position, Text = text, Color = color })
end

function CombatService.GetEquippedSword(character: Model?): (Tool?, any)
	if not character then
		return nil, nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil, nil
	end
	local swordId = tool:GetAttribute("SwordId")
	local sword = swordId and Config.SwordById[swordId]
	if not sword then
		return nil, nil
	end
	return tool, sword
end

local function playToolAnim(tool: Tool, animName: string)
	local value = Instance.new("StringValue")
	value.Name = "toolanim"
	value.Value = animName
	value.Parent = tool
	Debris:AddItem(value, 0.5)
end

local function playToolSound(tool: Tool, soundName: string)
	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound.PlaybackSpeed = 0.9 + math.random() * 0.2
		sound:Play()
	end
end

local function flashTrail(tool: Tool, duration: number)
	local handle = tool:FindFirstChild("Handle")
	local trail = handle and handle:FindFirstChild("SwordTrail")
	if trail and trail:IsA("Trail") then
		trail.Enabled = true
		task.delay(duration, function()
			if trail.Parent then
				trail.Enabled = false
			end
		end)
	end
end

local function useStamina(state: PlayerState, amount: number)
	state.Stamina = math.max(0, state.Stamina - amount)
	state.LastStaminaUse = now()
end

--------------------------------------------------------------------------
-- Velocidade / Atordoamento / Lentidão
--------------------------------------------------------------------------
function CombatService.UpdateSpeed(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local base = model:GetAttribute("BaseSpeed") or C.BaseWalkSpeed
	local jump = model:GetAttribute("BaseJump") or C.BaseJumpHeight
	local status = statuses[model]
	local t = now()

	if status and status.StunUntil > t then
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
		return
	end

	local multiplier = 1
	if model:GetAttribute("Blocking") then
		multiplier *= C.BlockSpeedMultiplier
	end
	if status and status.SlowUntil > t then
		multiplier *= status.SlowMult
	end
	humanoid.WalkSpeed = base * multiplier
	humanoid.JumpHeight = jump
end

function CombatService.IsStunned(model: Model): boolean
	local status = statuses[model]
	return status ~= nil and status.StunUntil > now()
end

function CombatService.Stun(model: Model, duration: number)
	local status = getStatus(model)
	status.StunUntil = math.max(status.StunUntil, now() + duration)
	model:SetAttribute("Stunned", true)

	local player = Players:GetPlayerFromCharacter(model)
	if player then
		CombatService.SetBlocking(player, false)
	end
	CombatService.UpdateSpeed(model)
end

function CombatService.Slow(model: Model, multiplier: number, duration: number)
	local status = getStatus(model)
	status.SlowUntil = now() + duration
	status.SlowMult = multiplier
	model:SetAttribute("Slowed", true)
	CombatService.UpdateSpeed(model)
end

function CombatService.Burn(model: Model, attacker: Model?)
	local fire = Config.Elements.fire
	local status = getStatus(model)
	local t = now()
	if status.BurnUntil < t then
		status.BurnNext = t + fire.BurnInterval
	end
	status.BurnUntil = t + fire.BurnTicks * fire.BurnInterval
	status.BurnAttacker = attacker
	model:SetAttribute("Burning", true)
end

function CombatService.IsInvulnerable(player: Player): boolean
	return getState(player).InvulnUntil > now()
end

function CombatService.GetLastAttacker(humanoid: Humanoid)
	local hit = lastHits[humanoid]
	if hit and now() - hit.Time <= C.KillCreditTime then
		return hit
	end
	return nil
end

--------------------------------------------------------------------------
-- Regras de quem pode bater em quem
--------------------------------------------------------------------------
local function canDamage(attacker: Model?, target: Model): boolean
	if attacker == target or target:GetAttribute("Invulnerable") then
		return false
	end
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	local attackerPlayer = attacker and Players:GetPlayerFromCharacter(attacker)
	local attackerIsNPC = attacker ~= nil and attacker:GetAttribute("NPC") ~= nil

	if target:GetAttribute("Dummy") then
		return attackerPlayer ~= nil
	end
	if attackerIsNPC and target:GetAttribute("NPC") ~= nil then
		return false -- NPCs não brigam entre si
	end
	if targetPlayer then
		if ZoneService.IsSafe(targetPlayer) then
			return false
		end
		if attackerPlayer and ZoneService.IsSafe(attackerPlayer) then
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------
-- DANO
-- info = { Source = "melee" | "special" | "chain" | "burn" | "slam",
--          Element = string?, Knockback = boolean?, CanBeBlocked = boolean?,
--          NoCrit = boolean? }
--------------------------------------------------------------------------
function CombatService.DealDamage(attacker: Model?, target: Model, amount: number, info): number
	info = info or {}
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local root = Util.GetRoot(target)
	if not humanoid or humanoid.Health <= 0 or not root then
		return 0
	end
	if not canDamage(attacker, target) then
		return 0
	end

	local attackerPlayer = attacker and Players:GetPlayerFromCharacter(attacker)
	local targetPlayer = Players:GetPlayerFromCharacter(target)
	local attackerRoot = attacker and Util.GetRoot(attacker)
	local element = info.Element or "none"
	local source = info.Source or "melee"
	local canBeBlocked = info.CanBeBlocked ~= false
	local damage = amount
	local crit = false

	-- Esquiva (invencível durante o dash)
	if targetPlayer and CombatService.IsInvulnerable(targetPlayer) then
		floatingText(root.Position, "ESQUIVOU!", Color3.fromRGB(200, 230, 255))
		return 0
	end

	-- Bloqueio / Parry
	if targetPlayer and canBeBlocked and attackerRoot then
		local state = getState(targetPlayer)
		if state.Blocking then
			local toAttacker = attackerRoot.Position - root.Position
			local flat = Vector3.new(toAttacker.X, 0, toAttacker.Z)
			local facing = flat.Magnitude < 0.01 or root.CFrame.LookVector:Dot(flat.Unit) > -0.1
			if facing then
				if source == "melee" and now() - state.BlockStart <= C.ParryWindow and attacker then
					CombatService.Stun(attacker, C.ParryStun)
					floatingText(root.Position, "PARRY!", Color3.fromRGB(120, 200, 255))
					fireEffect({ Type = "Parry", Position = root.Position })
					return 0
				end
				if element ~= "void" then
					damage *= (1 - C.BlockReduction)
					useStamina(state, C.BlockStaminaCost)
					fireEffect({ Type = "Block", Position = root.Position })
					if state.Stamina <= 0 then
						CombatService.Stun(target, C.GuardBreakStun)
						floatingText(root.Position, "GUARDA QUEBRADA!", Color3.fromRGB(255, 160, 60))
					end
				end
			end
		end
	end

	-- Crítico (somente golpes de jogadores)
	if attackerPlayer and not info.NoCrit and (source == "melee" or source == "special") then
		if math.random() < C.CritChance then
			damage *= C.CritMultiplier
			crit = true
		end
	end

	-- Abismo executa alvos com pouca vida
	if element == "void" then
		local void = Config.Elements.void
		if humanoid.Health / humanoid.MaxHealth <= void.ExecuteThreshold then
			damage *= void.ExecuteMultiplier
		end
	end

	damage = math.max(1, math.floor(damage + 0.5))

	-- Registra quem bateu (para dar o crédito do abate)
	if attacker then
		lastHits[humanoid] = {
			Player = attackerPlayer,
			Model = attacker,
			Name = attackerPlayer and attackerPlayer.DisplayName
				or (attacker:GetAttribute("DisplayName") or attacker.Name),
			Time = now(),
		}
	end

	local before = humanoid.Health
	humanoid:TakeDamage(damage)
	local dealt = before - humanoid.Health
	if dealt <= 0 then
		return 0
	end

	for _, listener in CombatService.DamageListeners do
		task.spawn(listener, target, attackerPlayer, dealt)
	end

	-- Efeitos visuais
	local color = elementColor(element)
	if source ~= "burn" then
		fireEffect({ Type = "Hit", Position = root.Position, Color = color, Crit = crit })
	end
	if attackerPlayer then
		Remotes.Effect:FireClient(attackerPlayer, {
			Type = "Damage",
			Position = root.Position + Vector3.new(0, 2, 0),
			Amount = math.floor(dealt + 0.5),
			Crit = crit,
			Color = color,
		})
	end

	-- Efeitos de elemento
	if element == "fire" then
		CombatService.Burn(target, attacker)
	elseif element == "ice" then
		local ice = Config.Elements.ice
		CombatService.Slow(target, ice.SlowMultiplier, ice.SlowDuration)
	elseif element == "shadow" and attacker then
		local attackerHumanoid = attacker:FindFirstChildOfClass("Humanoid")
		if attackerHumanoid and attackerHumanoid.Health > 0 then
			attackerHumanoid.Health = math.min(
				attackerHumanoid.MaxHealth,
				attackerHumanoid.Health + dealt * Config.Elements.shadow.Lifesteal
			)
		end
	elseif element == "lightning" and source ~= "chain" then
		CombatService.ChainLightning(attacker, target, dealt)
	end

	-- Empurrão
	if info.Knockback and attackerRoot and humanoid.Health > 0 then
		local direction = root.Position - attackerRoot.Position
		direction = Vector3.new(direction.X, 0, direction.Z)
		if direction.Magnitude < 0.01 then
			direction = attackerRoot.CFrame.LookVector
		end
		local velocity = direction.Unit * C.KnockbackForce + Vector3.new(0, 22, 0)
		if targetPlayer then
			Remotes.Knockback:FireClient(targetPlayer, velocity)
		elseif not root.Anchored then
			root.AssemblyLinearVelocity = velocity
		end
	end

	return dealt
end

function CombatService.ChainLightning(attacker: Model?, origin: Model, baseDamage: number)
	local lightning = Config.Elements.lightning
	local originRoot = Util.GetRoot(origin)
	if not originRoot then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { origin, attacker :: any }

	local candidates = {}
	local seen = {}
	for _, part in workspace:GetPartBoundsInRadius(originRoot.Position, lightning.ChainRadius, params) do
		local model = Util.GetCharacterFromPart(part)
		if model and not seen[model] and Util.IsAlive(model) and canDamage(attacker, model) then
			seen[model] = true
			local root = Util.GetRoot(model) :: BasePart
			table.insert(candidates, { Model = model, Distance = (root.Position - originRoot.Position).Magnitude })
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	for i = 1, math.min(lightning.ChainTargets, #candidates) do
		local model = candidates[i].Model
		local root = Util.GetRoot(model)
		if root then
			fireEffect({ Type = "Lightning", From = originRoot.Position, To = root.Position })
			CombatService.DealDamage(attacker, model, baseDamage * lightning.ChainMultiplier, {
				Source = "chain",
				Element = "lightning",
				CanBeBlocked = false,
				NoCrit = true,
			})
		end
	end
end

--------------------------------------------------------------------------
-- Busca de alvos
--------------------------------------------------------------------------
local function collectTargets(parts: { BasePart }): { Model }
	local found = {}
	local list = {}
	for _, part in parts do
		local model = Util.GetCharacterFromPart(part)
		if model and not found[model] and Util.IsAlive(model) then
			found[model] = true
			table.insert(list, model)
		end
	end
	return list
end

local function queryBox(cframe: CFrame, size: Vector3, exclude: { Instance }): { Model }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return collectTargets(workspace:GetPartBoundsInBox(cframe, size, params))
end

local function queryRadius(position: Vector3, radius: number, exclude: { Instance }): { Model }
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return collectTargets(workspace:GetPartBoundsInRadius(position, radius, params))
end

CombatService.QueryRadius = queryRadius

--------------------------------------------------------------------------
-- Ações do jogador (chamadas pelos RemoteEvents)
--------------------------------------------------------------------------
local function getAliveCharacter(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and Util.GetRoot(character)
	if not character or not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil, nil
	end
	return character, humanoid, root
end

function CombatService.Attack(player: Player)
	local character, humanoid, root = getAliveCharacter(player)
	if not character or not humanoid or not root then
		return
	end
	local tool, sword = CombatService.GetEquippedSword(character)
	if not tool or not sword then
		return
	end
	local state = getState(player)
	local t = now()
	if CombatService.IsStunned(character) or state.Blocking then
		return
	end
	if t - state.LastAttack < sword.Cooldown then
		return
	end

	if t - state.LastAttack > C.ComboWindow then
		state.Combo = 0
	end
	state.Combo = state.Combo % 3 + 1
	local combo = state.Combo
	local finisher = combo == 3
	state.LastAttack = finisher and (t + C.FinisherExtraDelay) or t
	player:SetAttribute("Combo", combo)

	playToolAnim(tool, finisher and "Lunge" or "Slash")
	playToolSound(tool, finisher and "Lunge" or "Slash")
	flashTrail(tool, 0.35)

	task.delay(C.HitDelay, function()
		if not character.Parent or humanoid.Health <= 0 or tool.Parent ~= character then
			return
		end
		if CombatService.IsStunned(character) then
			return
		end
		local range = sword.Range + (finisher and 1.5 or 0)
		local boxCFrame = root.CFrame * CFrame.new(0, 0, -range / 2)
		local size = Vector3.new(C.HitboxWidth, C.HitboxHeight, range)
		local damage = sword.Damage * C.ComboMultipliers[combo]
		for _, target in queryBox(boxCFrame, size, { character }) do
			CombatService.DealDamage(character, target, damage, {
				Source = "melee",
				Element = sword.Element,
				Knockback = finisher,
			})
		end
	end)
end

function CombatService.SetBlocking(player: Player, blocking: boolean)
	local state = getState(player)
	local character = player.Character
	if not character then
		state.Blocking = false
		return
	end

	if blocking then
		if state.Blocking then
			return
		end
		local tool, sword = CombatService.GetEquippedSword(character)
		if not tool or not sword or CombatService.IsStunned(character) or state.Stamina < 5 then
			return
		end
		if not Util.IsAlive(character) then
			return
		end
		state.Blocking = true
		state.BlockStart = now()
		character:SetAttribute("Blocking", true)

		if tool:GetAttribute("BaseGrip") == nil then
			tool:SetAttribute("BaseGrip", tool.Grip)
		end
		tool.Grip = (tool:GetAttribute("BaseGrip") :: CFrame) * BLOCK_GRIP_ROTATION

		local highlight = Instance.new("Highlight")
		highlight.Name = "BlockHighlight"
		highlight.FillColor = Color3.fromRGB(120, 190, 255)
		highlight.OutlineColor = Color3.fromRGB(200, 230, 255)
		highlight.FillTransparency = 0.8
		highlight.OutlineTransparency = 0.2
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = character
	else
		if not state.Blocking then
			return
		end
		state.Blocking = false
		character:SetAttribute("Blocking", false)
		local containers: { Instance } = { character }
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			table.insert(containers, backpack)
		end
		for _, container in containers do
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("BaseGrip") then
					child.Grip = child:GetAttribute("BaseGrip") :: CFrame
				end
			end
		end
		local highlight = character:FindFirstChild("BlockHighlight")
		if highlight then
			highlight:Destroy()
		end
	end
	CombatService.UpdateSpeed(character)
end

function CombatService.Dash(player: Player)
	local character = getAliveCharacter(player)
	if not character then
		return
	end
	local state = getState(player)
	local t = now()
	if CombatService.IsStunned(character) or state.Blocking then
		return
	end
	if t - state.LastDash < C.DashCooldown or state.Stamina < C.DashCost then
		return
	end
	state.LastDash = t
	state.InvulnUntil = t + C.DashInvulnerability
	useStamina(state, C.DashCost)
	local root = Util.GetRoot(character)
	if root then
		fireEffect({ Type = "Dash", Position = root.Position })
	end
end

function CombatService.Special(player: Player)
	local character, humanoid, root = getAliveCharacter(player)
	if not character or not humanoid or not root then
		return
	end
	local tool, sword = CombatService.GetEquippedSword(character)
	if not tool or not sword then
		return
	end
	local state = getState(player)
	local t = now()
	if CombatService.IsStunned(character) or state.Blocking or t < state.SpecialReadyAt then
		return
	end
	state.SpecialReadyAt = t + sword.SpecialCooldown
	player:SetAttribute("SpecialReadyAt", workspace:GetServerTimeNow() + sword.SpecialCooldown)
	player:SetAttribute("SpecialCooldown", sword.SpecialCooldown)

	playToolAnim(tool, "Lunge")
	playToolSound(tool, "Lunge")
	flashTrail(tool, 0.5)

	local color = elementColor(sword.Element)
	fireEffect({
		Type = "Ring",
		Position = root.Position - Vector3.new(0, 2.5, 0),
		Radius = sword.SpecialRadius,
		Color = color,
		Element = sword.Element,
	})

	task.delay(0.15, function()
		if not character.Parent or humanoid.Health <= 0 then
			return
		end
		for _, target in queryRadius(root.Position, sword.SpecialRadius, { character }) do
			if sword.Element == "lightning" then
				local targetRoot = Util.GetRoot(target)
				if targetRoot then
					fireEffect({
						Type = "Lightning",
						From = targetRoot.Position + Vector3.new(0, 40, 0),
						To = targetRoot.Position,
					})
				end
			end
			CombatService.DealDamage(character, target, sword.SpecialDamage, {
				Source = "special",
				Element = sword.Element,
				Knockback = true,
			})
		end
	end)
end

--------------------------------------------------------------------------
-- Ciclo de atualização (estamina, queimadura, fim de efeitos)
--------------------------------------------------------------------------
local function clearVisual(model: Model, name: string)
	local root = Util.GetRoot(model)
	local visual = root and root:FindFirstChild(name)
	if visual then
		visual:Destroy()
	end
end

local function ensureVisual(model: Model, name: string, create: () -> Instance)
	local root = Util.GetRoot(model)
	if root and not root:FindFirstChild(name) then
		local visual = create()
		visual.Name = name
		visual.Parent = root
	end
end

local statusAccumulator = 0

local function updateStatuses()
	local t = now()
	for model, status in statuses do
		if not model.Parent then
			statuses[model] = nil
			continue
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local alive = humanoid ~= nil and humanoid.Health > 0

		-- Atordoamento
		if model:GetAttribute("Stunned") and status.StunUntil <= t then
			model:SetAttribute("Stunned", false)
			CombatService.UpdateSpeed(model)
		end

		-- Lentidão
		if model:GetAttribute("Slowed") then
			if status.SlowUntil <= t or not alive then
				model:SetAttribute("Slowed", false)
				clearVisual(model, "FrostFX")
				CombatService.UpdateSpeed(model)
			else
				ensureVisual(model, "FrostFX", function()
					local emitter = Instance.new("ParticleEmitter")
					emitter.Color = ColorSequence.new(Color3.fromRGB(170, 230, 255))
					emitter.LightEmission = 0.6
					emitter.Size = NumberSequence.new(0.35, 0)
					emitter.Lifetime = NumberRange.new(0.5, 0.9)
					emitter.Rate = 25
					emitter.Speed = NumberRange.new(1, 3)
					emitter.SpreadAngle = Vector2.new(180, 180)
					return emitter
				end)
			end
		end

		-- Queimadura
		if model:GetAttribute("Burning") then
			if status.BurnUntil <= t or not alive then
				model:SetAttribute("Burning", false)
				clearVisual(model, "BurnFX")
			else
				ensureVisual(model, "BurnFX", function()
					local fire = Instance.new("Fire")
					fire.Size = 4
					fire.Heat = 6
					fire.Color = Color3.fromRGB(255, 120, 30)
					fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
					return fire
				end)
				if t >= status.BurnNext then
					status.BurnNext = t + Config.Elements.fire.BurnInterval
					local attacker = status.BurnAttacker
					if attacker and not attacker.Parent then
						attacker = nil
					end
					CombatService.DealDamage(attacker, model, Config.Elements.fire.BurnDamage, {
						Source = "burn",
						CanBeBlocked = false,
						NoCrit = true,
					})
				end
			end
		end
	end
end

local function updateStamina(dt: number)
	local t = now()
	for player, state in playerStates do
		if not player.Parent then
			playerStates[player] = nil
			continue
		end
		if not state.Blocking and t - state.LastStaminaUse >= C.StaminaRegenDelay and state.Stamina < C.StaminaMax then
			state.Stamina = math.min(C.StaminaMax, state.Stamina + C.StaminaRegen * dt)
		end
		-- Se a espada saiu da mão, para de bloquear
		if state.Blocking then
			local tool = CombatService.GetEquippedSword(player.Character)
			if not tool then
				CombatService.SetBlocking(player, false)
			end
		end
		local rounded = math.floor(state.Stamina + 0.5)
		if rounded ~= state.LastStaminaSent then
			state.LastStaminaSent = rounded
			player:SetAttribute("Stamina", rounded)
		end
	end
end

function CombatService.ResetPlayer(player: Player)
	local state = getState(player)
	state.Combo = 0
	state.Blocking = false
	state.Stamina = C.StaminaMax
	state.InvulnUntil = 0
	player:SetAttribute("Stamina", C.StaminaMax)
	player:SetAttribute("StaminaMax", C.StaminaMax)
	player:SetAttribute("Combo", 0)
end

--------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------
function CombatService.Init(services)
	ZoneService = services.ZoneService

	Remotes.Attack.OnServerEvent:Connect(function(player)
		CombatService.Attack(player)
	end)
	Remotes.Block.OnServerEvent:Connect(function(player, blocking)
		if type(blocking) ~= "boolean" then
			return
		end
		CombatService.SetBlocking(player, blocking)
	end)
	Remotes.Dash.OnServerEvent:Connect(function(player)
		CombatService.Dash(player)
	end)
	Remotes.Special.OnServerEvent:Connect(function(player)
		CombatService.Special(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerStates[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		updateStamina(dt)
		statusAccumulator += dt
		if statusAccumulator >= 0.1 then
			statusAccumulator = 0
			updateStatuses()
		end
	end)
end

return CombatService
