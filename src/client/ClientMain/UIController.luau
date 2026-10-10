--[[
	UIController
	Toda a interface do jogo é criada por código aqui:
	  - Painel do jogador (nível, XP, moedas)
	  - Barras de vida e estamina + habilidade especial
	  - Nome da zona atual
	  - Feed de abates e notificações
	  - Barra de vida do chefe
	  - Loja (Ferraria) e janela de controles
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwordsFolder = ReplicatedStorage:WaitForChild("Swords")
local player = Players.LocalPlayer

local UIController = {}

--------------------------------------------------------------------------
-- Tema
--------------------------------------------------------------------------
local THEME = {
	Panel = Color3.fromRGB(22, 24, 34),
	PanelLight = Color3.fromRGB(38, 41, 56),
	Stroke = Color3.fromRGB(90, 80, 60),
	Gold = Color3.fromRGB(255, 205, 85),
	Text = Color3.fromRGB(240, 240, 245),
	SubText = Color3.fromRGB(170, 175, 190),
	Health = Color3.fromRGB(80, 220, 100),
	HealthLow = Color3.fromRGB(235, 60, 60),
	Stamina = Color3.fromRGB(255, 200, 60),
	XP = Color3.fromRGB(120, 140, 255),
	Green = Color3.fromRGB(70, 190, 100),
	Red = Color3.fromRGB(200, 60, 60),
	Gray = Color3.fromRGB(90, 92, 105),
}

local function make(className: string, properties, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in properties do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if properties.Parent then
		instance.Parent = properties.Parent
	end
	return instance
end

local function corner(radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function stroke(color: Color3?, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color or THEME.Stroke,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function panel(properties, children: { Instance }?)
	properties.BackgroundColor3 = properties.BackgroundColor3 or THEME.Panel
	properties.BackgroundTransparency = properties.BackgroundTransparency or 0.15
	properties.BorderSizePixel = 0
	local frame = make("Frame", properties, children)
	corner(10).Parent = frame
	stroke().Parent = frame
	return frame
end

local function label(properties)
	properties.BackgroundTransparency = 1
	properties.Font = properties.Font or Enum.Font.GothamBold
	properties.TextColor3 = properties.TextColor3 or THEME.Text
	properties.TextScaled = properties.TextScaled ~= false
	return make("TextLabel", properties)
end

local function button(properties)
	properties.AutoButtonColor = true
	properties.BorderSizePixel = 0
	properties.Font = properties.Font or Enum.Font.GothamBlack
	properties.TextColor3 = properties.TextColor3 or THEME.Text
	properties.TextScaled = true
	local btn = make("TextButton", properties)
	corner(8).Parent = btn
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = btn,
	})
	return btn
end

local function bar(parent: Instance, properties, fillColor: Color3)
	properties.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	properties.BorderSizePixel = 0
	properties.Parent = parent
	local back = make("Frame", properties)
	corner(6).Parent = back
	stroke(Color3.fromRGB(0, 0, 0), 1.5).Parent = back
	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Parent = back,
	})
	corner(6).Parent = fill
	make("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		Rotation = 90,
		Parent = fill,
	})
	local text = label({
		Name = "Label",
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromOffset(4, 2),
		Text = "",
		ZIndex = 3,
		TextStrokeTransparency = 0.4,
		Parent = back,
	})
	return back, fill, text
end

local function tween(instance: Instance, seconds: number, properties, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), properties)
	t:Play()
	return t
end

--------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------
local screen: ScreenGui
local hud = {} :: any
local shop = {} :: any
local controlsWindow: Frame
local bigQueue = {}
local showingBig = false
local orderCounter = 0

local function nextOrder(): number
	orderCounter += 1
	return orderCounter
end

local function getOwned(): { [string]: boolean }
	local raw = player:GetAttribute("Owned")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return ok and decoded or {}
end

--------------------------------------------------------------------------
-- Notificações
--------------------------------------------------------------------------
local function colorFrom(value): Color3
	if typeof(value) == "Color3" then
		return value
	elseif type(value) == "table" then
		return Util.Color(value)
	end
	return THEME.Gold
end

local function showNextBig()
	if showingBig or #bigQueue == 0 then
		return
	end
	showingBig = true
	local data = table.remove(bigQueue, 1)
	local holder = hud.BigNotify
	holder.Title.Text = data.Text or ""
	holder.Title.TextColor3 = colorFrom(data.Color)
	holder.Sub.Text = data.Sub or ""
	holder.Visible = true
	holder.Title.TextTransparency = 1
	holder.Sub.TextTransparency = 1
	holder.Scale.Scale = 0.6
	tween(holder.Scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(holder.Title, 0.2, { TextTransparency = 0 })
	tween(holder.Sub, 0.2, { TextTransparency = 0 })
	task.delay(2.6, function()
		tween(holder.Title, 0.4, { TextTransparency = 1 })
		tween(holder.Sub, 0.4, { TextTransparency = 1 })
		task.wait(0.45)
		holder.Visible = false
		showingBig = false
		showNextBig()
	end)
end

function UIController.Notify(data)
	if type(data) ~= "table" then
		return
	end
	if data.Small then
		local toast = panel({
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 0.2,
			Parent = hud.Toasts,
		})
		label({
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 4),
			Text = data.Text or "",
			TextColor3 = colorFrom(data.Color),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toast,
		})
		label({
			Size = UDim2.new(1, -16, 0, 18),
			Position = UDim2.fromOffset(8, 28),
			Text = data.Sub or "",
			TextColor3 = THEME.SubText,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toast,
		})
		task.delay(4, function()
			for _, child in toast:GetDescendants() do
				if child:IsA("TextLabel") then
					tween(child, 0.4, { TextTransparency = 1 })
				elseif child:IsA("UIStroke") then
					tween(child, 0.4, { Transparency = 1 })
				end
			end
			tween(toast, 0.4, { BackgroundTransparency = 1 })
			task.wait(0.45)
			toast:Destroy()
		end)
		return
	end
	table.insert(bigQueue, data)
	showNextBig()
end

local function addKillFeed(data)
	if type(data) ~= "table" then
		return
	end
	local text
	if data.Killer then
		text = ("%s  derrotou  %s"):format(data.Killer, data.Victim or "?")
	else
		text = ("%s caiu"):format(data.Victim or "?")
	end
	local entry = panel({
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 0.3,
		Parent = hud.KillFeed,
	})
	label({
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromOffset(6, 4),
		Text = text,
		TextColor3 = data.KillerIsPlayer and Color3.fromRGB(255, 120, 110) or THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = entry,
	})
	local entries = {}
	for _, child in hud.KillFeed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(entries, child)
		end
	end
	table.sort(entries, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	if #entries > 5 then
		entries[1]:Destroy()
	end
	task.delay(7, function()
		if entry.Parent then
			entry:Destroy()
		end
	end)
end

--------------------------------------------------------------------------
-- HUD
--------------------------------------------------------------------------
local function buildHUD()
	-- Painel do jogador
	local stats = panel({
		Name = "Stats",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(270, 78),
		Parent = screen,
	})
	local badge = make("Frame", {
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(9, 9),
		BackgroundColor3 = THEME.Gold,
		Parent = stats,
	})
	corner(30).Parent = badge
	stroke(Color3.fromRGB(120, 80, 20), 2).Parent = badge
	label({
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 8),
		Text = "NÍVEL",
		TextColor3 = Color3.fromRGB(80, 50, 10),
		Font = Enum.Font.GothamBlack,
		Parent = badge,
	})
	hud.Level = label({
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 24),
		Text = "1",
		TextColor3 = Color3.fromRGB(60, 35, 5),
		Font = Enum.Font.GothamBlack,
		Parent = badge,
	})
	label({
		Size = UDim2.fromOffset(185, 20),
		Position = UDim2.fromOffset(78, 8),
		Text = player.DisplayName,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stats,
	})
	local _, xpFill, xpText = bar(stats, {
		Size = UDim2.fromOffset(182, 16),
		Position = UDim2.fromOffset(78, 32),
	}, THEME.XP)
	hud.XPFill = xpFill
	hud.XPText = xpText
	hud.Coins = label({
		Size = UDim2.fromOffset(182, 20),
		Position = UDim2.fromOffset(78, 52),
		Text = "0 moedas",
		TextColor3 = THEME.Gold,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stats,
	})

	-- Botões laterais
	hud.ShopButton = button({
		Name = "ShopButton",
		Text = "LOJA  [B]",
		Size = UDim2.fromOffset(130, 40),
		Position = UDim2.new(0, 12, 0, 100),
		BackgroundColor3 = Color3.fromRGB(170, 110, 30),
		Parent = screen,
	})
	hud.ControlsButton = button({
		Name = "ControlsButton",
		Text = "CONTROLES  [H]",
		Size = UDim2.fromOffset(130, 34),
		Position = UDim2.new(0, 12, 0, 146),
		BackgroundColor3 = THEME.PanelLight,
		Parent = screen,
	})

	-- Zona
	local zone = make("Frame", {
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(360, 54),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	hud.ZoneTitle = label({
		Size = UDim2.new(1, 0, 0, 30),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.3,
		Parent = zone,
	})
	hud.ZoneSub = label({
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 32),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextColor3 = THEME.SubText,
		TextStrokeTransparency = 0.5,
		Parent = zone,
	})

	-- Barra do chefe
	local boss = panel({
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(460, 54),
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(35, 10, 15),
		Parent = screen,
	})
	hud.BossName = label({
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 4),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 90, 100),
		Parent = boss,
	})
	local _, bossFill, bossText = bar(boss, {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 28),
	}, Color3.fromRGB(210, 30, 50))
	hud.Boss = boss
	hud.BossFill = bossFill
	hud.BossText = bossText
	hud.BossData = nil

	-- Barras inferiores
	local bottom = make("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(420, 64),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	local _, hpFill, hpText = bar(bottom, {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 24),
	}, THEME.Health)
	hud.HPFill = hpFill
	hud.HPText = hpText
	local _, stFill, stText = bar(bottom, {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.fromOffset(0, 54),
	}, THEME.Stamina)
	stText.Visible = false
	hud.StaminaFill = stFill
	hud.Status = label({
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 0),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.3,
		Parent = bottom,
	})

	-- Habilidade especial
	local specialBox = panel({
		Name = "Special",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 12, 1, 0),
		Size = UDim2.fromOffset(150, 64),
		Parent = bottom,
	})
	local key = make("Frame", {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(8, 12),
		BackgroundColor3 = THEME.Gold,
		Parent = specialBox,
	})
	corner(8).Parent = key
	label({
		Size = UDim2.fromScale(1, 1),
		Text = "R",
		TextColor3 = Color3.fromRGB(60, 35, 5),
		Font = Enum.Font.GothamBlack,
		Parent = key,
	})
	hud.SpecialName = label({
		Size = UDim2.fromOffset(92, 30),
		Position = UDim2.fromOffset(54, 6),
		Text = "Especial",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = specialBox,
	})
	hud.SpecialCooldown = label({
		Size = UDim2.fromOffset(92, 20),
		Position = UDim2.fromOffset(54, 38),
		Text = "PRONTO",
		TextColor3 = THEME.Health,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = specialBox,
	})
	hud.SpecialKey = key

	-- Combo
	hud.Combo = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.fromOffset(220, 34),
		Text = "",
		TextColor3 = THEME.Gold,
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.2,
		Parent = screen,
	})
	hud.ComboScale = make("UIScale", { Parent = hud.Combo })

	-- Feed de abates
	hud.KillFeed = make("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(330, 220),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})

	-- Notificações pequenas
	hud.Toasts = make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -110),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		make("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})

	-- Notificação grande
	local big = make("Frame", {
		Name = "BigNotify",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(640, 90),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	make("UIScale", { Name = "Scale", Parent = big })
	label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 56),
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.1,
		Parent = big,
	})
	label({
		Name = "Sub",
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 60),
		Text = "",
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.3,
		Parent = big,
	})
	hud.BigNotify = big

	-- Flash vermelho ao levar dano
	hud.DamageFlash = make("Frame", {
		Name = "DamageFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = screen,
	})
end

--------------------------------------------------------------------------
-- Atualizações do HUD
--------------------------------------------------------------------------
local function refreshStats()
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local needed = player:GetAttribute("XPNeeded") or Config.XPForLevel(level)
	hud.Level.Text = tostring(level)
	hud.XPFill.Size = UDim2.fromScale(math.clamp(xp / math.max(needed, 1), 0, 1), 1)
	hud.XPText.Text = ("%s / %s XP"):format(Util.FormatNumber(xp), Util.FormatNumber(needed))
	hud.Coins.Text = Util.FormatNumber(player:GetAttribute("Coins") or 0) .. " moedas"

	local sword = Config.SwordById[player:GetAttribute("Equipped") or ""]
	hud.SpecialName.Text = sword and sword.SpecialName or "Especial"
end

local function refreshZone()
	local zoneName = player:GetAttribute("Zone") or Config.DefaultZone
	local zone = Config.Zones[zoneName] or Config.Zones[Config.DefaultZone]
	hud.ZoneTitle.Text = zone.DisplayName
	hud.ZoneTitle.TextColor3 = Util.Color(zone.Color)
	hud.ZoneSub.Text = zone.Subtitle
	hud.ZoneTitle.TextTransparency = 1
	tween(hud.ZoneTitle, 0.5, { TextTransparency = 0 })
	if hud.BossData then
		hud.Boss.Visible = hud.BossData.Active and zoneName == "Ruinas"
	end
end

local lastHealth = nil
local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if lastHealth and health < lastHealth - 0.5 then
			hud.DamageFlash.BackgroundTransparency = 0.8
			tween(hud.DamageFlash, 0.4, { BackgroundTransparency = 1 })
		end
		lastHealth = health
	end)
end

local function updateEveryFrame()
	-- Vida
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		hud.HPFill.Size = UDim2.fromScale(ratio, 1)
		hud.HPFill.BackgroundColor3 = THEME.HealthLow:Lerp(THEME.Health, ratio)
		hud.HPText.Text = ("%d / %d"):format(math.ceil(humanoid.Health), humanoid.MaxHealth)
	end

	-- Estamina
	local stamina = player:GetAttribute("Stamina") or 100
	local staminaMax = player:GetAttribute("StaminaMax") or 100
	hud.StaminaFill.Size = UDim2.fromScale(math.clamp(stamina / staminaMax, 0, 1), 1)

	-- Habilidade especial
	local readyAt = player:GetAttribute("SpecialReadyAt") or 0
	local remaining = readyAt - workspace:GetServerTimeNow()
	if remaining > 0 then
		hud.SpecialCooldown.Text = ("%.1fs"):format(remaining)
		hud.SpecialCooldown.TextColor3 = THEME.SubText
		hud.SpecialKey.BackgroundColor3 = THEME.Gray
	else
		hud.SpecialCooldown.Text = "PRONTO"
		hud.SpecialCooldown.TextColor3 = THEME.Health
		hud.SpecialKey.BackgroundColor3 = THEME.Gold
	end

	-- Estado
	local status, color = "", THEME.Text
	if character then
		if character:GetAttribute("Stunned") then
			status, color = "ATORDOADO!", Color3.fromRGB(255, 200, 80)
		elseif character:GetAttribute("Blocking") then
			status, color = "BLOQUEANDO", Color3.fromRGB(140, 200, 255)
		elseif character:GetAttribute("Burning") then
			status, color = "QUEIMANDO", Color3.fromRGB(255, 130, 40)
		elseif character:GetAttribute("Slowed") then
			status, color = "CONGELADO", Color3.fromRGB(150, 220, 255)
		elseif player:GetAttribute("Safe") then
			status, color = "ZONA SEGURA - sem PvP", Color3.fromRGB(120, 230, 140)
		end
	end
	hud.Status.Text = status
	hud.Status.TextColor3 = color
end

local comboToken = 0
local function showCombo()
	local combo = player:GetAttribute("Combo") or 0
	if combo <= 0 then
		return
	end
	comboToken += 1
	local token = comboToken
	hud.Combo.Text = combo == 3 and "FINALIZADOR!" or ("COMBO x%d"):format(combo)
	hud.Combo.TextTransparency = 0
	hud.ComboScale.Scale = 1.4
	tween(hud.ComboScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.9, function()
		if token == comboToken then
			tween(hud.Combo, 0.3, { TextTransparency = 1 })
		end
	end)
end

local function updateBoss(data)
	if type(data) ~= "table" then
		return
	end
	hud.BossData = data
	if not data.Active then
		hud.Boss.Visible = false
		return
	end
	hud.BossName.Text = data.Name .. (data.Enraged and "  (FURIOSO)" or "")
	local ratio = math.clamp(data.Health / math.max(data.MaxHealth, 1), 0, 1)
	tween(hud.BossFill, 0.2, { Size = UDim2.fromScale(ratio, 1) })
	hud.BossText.Text = ("%s / %s"):format(Util.FormatNumber(data.Health), Util.FormatNumber(data.MaxHealth))
	hud.Boss.Visible = player:GetAttribute("Zone") == "Ruinas"
end

--------------------------------------------------------------------------
-- Loja
--------------------------------------------------------------------------
local function buildViewport(parent: Instance, swordId: string)
	local viewport = make("ViewportFrame", {
		Size = UDim2.fromOffset(110, 110),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(14, 15, 22),
		Ambient = Color3.fromRGB(170, 170, 180),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	corner(8).Parent = viewport

	local template = SwordsFolder:FindFirstChild(swordId)
	if not template then
		return viewport
	end
	local model = Instance.new("Model")
	for _, child in template:Clone():GetChildren() do
		child.Parent = model
	end
	model.Parent = viewport
	local _, size = model:GetBoundingBox()
	local length = math.max(size.X, size.Y, size.Z)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local center = model:GetBoundingBox().Position
	local spinner = { Model = model, Center = center, Pivot = model:GetPivot() }
	table.insert(shop.Spinners, spinner)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0, length * 1.5), center)
	return viewport
end

local function shopMessage(text: string, good: boolean)
	shop.Message.Text = text
	shop.Message.TextColor3 = good and THEME.Health or Color3.fromRGB(255, 110, 100)
	shop.Message.TextTransparency = 0
	local token = os.clock()
	shop.MessageToken = token
	task.delay(3, function()
		if shop.MessageToken == token then
			tween(shop.Message, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function refreshShop()
	if not shop.Cards then
		return
	end
	local owned = getOwned()
	local equipped = player:GetAttribute("Equipped")
	local level = player:GetAttribute("Level") or 1
	local coins = player:GetAttribute("Coins") or 0
	shop.Coins.Text = Util.FormatNumber(coins) .. " moedas"

	for id, card in shop.Cards do
		local sword = Config.SwordById[id]
		local btn = card.Button
		if equipped == id then
			btn.Text = "EQUIPADA"
			btn.BackgroundColor3 = THEME.Gray
		elseif owned[id] then
			btn.Text = "EQUIPAR"
			btn.BackgroundColor3 = Color3.fromRGB(60, 120, 210)
		elseif sword.Price == nil then
			btn.Text = "DROP DO CHEFE"
			btn.BackgroundColor3 = Color3.fromRGB(120, 30, 40)
		elseif level < sword.Level then
			btn.Text = "NÍVEL " .. sword.Level
			btn.BackgroundColor3 = THEME.Gray
		else
			btn.Text = "COMPRAR " .. Util.FormatNumber(sword.Price)
			btn.BackgroundColor3 = coins >= sword.Price and THEME.Green or THEME.Red
		end
	end
end

local function buildShop()
	shop.Spinners = {}
	shop.Cards = {}

	local window = panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.85, 0),
		Visible = false,
		BackgroundTransparency = 0.05,
		ZIndex = 5,
		Parent = screen,
	})
	make("UISizeConstraint", { MaxSize = Vector2.new(820, 560), Parent = window })
	shop.Window = window

	label({
		Size = UDim2.new(1, -120, 0, 34),
		Position = UDim2.fromOffset(16, 12),
		Text = "FERRARIA DO REINO",
		TextColor3 = THEME.Gold,
		Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	shop.Coins = label({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(200, 24),
		Position = UDim2.new(1, -64, 0, 18),
		Text = "",
		TextColor3 = THEME.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = window,
	})
	local close = button({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -12, 0, 10),
		Text = "X",
		BackgroundColor3 = THEME.Red,
		Parent = window,
	})
	close.MouseButton1Click:Connect(function()
		UIController.SetShopOpen(false)
	end)

	shop.Message = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -32, 0, 24),
		Text = "",
		Parent = window,
	})

	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 1, -96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		make("UIGridLayout", {
			CellSize = UDim2.new(0.5, -6, 0, 140),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	for _, sword in Config.Swords do
		local element = Config.Elements[sword.Element] or Config.Elements.none
		local card = panel({
			Name = sword.Id,
			LayoutOrder = sword.Order,
			BackgroundColor3 = THEME.PanelLight,
			BackgroundTransparency = 0,
			Parent = list,
		})
		buildViewport(card, sword.Id)

		label({
			Size = UDim2.new(1, -134, 0, 22),
			Position = UDim2.fromOffset(126, 8),
			Text = sword.Name,
			TextColor3 = sword.Element == "none" and THEME.Text or Util.Color(element.Color),
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		label({
			Size = UDim2.new(1, -134, 0, 30),
			Position = UDim2.fromOffset(126, 31),
			Text = sword.Description,
			TextColor3 = THEME.SubText,
			Font = Enum.Font.Gotham,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		label({
			Size = UDim2.new(1, -134, 0, 16),
			Position = UDim2.fromOffset(126, 63),
			Text = ("Dano %d  |  Alcance %.1f  |  Vel %.2fs"):format(sword.Damage, sword.Range, sword.Cooldown),
			TextColor3 = THEME.Text,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		label({
			Size = UDim2.new(1, -134, 0, 16),
			Position = UDim2.fromOffset(126, 81),
			Text = ("Especial: %s (%d)%s"):format(
				sword.SpecialName,
				sword.SpecialDamage,
				sword.Element ~= "none" and ("  |  " .. element.Name) or ""
			),
			TextColor3 = THEME.Gold,
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		local btn = button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -8),
			Size = UDim2.new(1, -134, 0, 32),
			Text = "",
			BackgroundColor3 = THEME.Green,
			Parent = card,
		})
		shop.Cards[sword.Id] = { Button = btn }

		btn.MouseButton1Click:Connect(function()
			local owned = getOwned()
			local action = owned[sword.Id] and "Equip" or "Buy"
			if player:GetAttribute("Equipped") == sword.Id then
				return
			end
			local ok, success, message = pcall(function()
				return Remotes.Shop:InvokeServer(action, sword.Id)
			end)
			if ok then
				shopMessage(message or "", success == true)
			else
				shopMessage("Erro de conexão, tente de novo", false)
			end
			refreshShop()
		end)
	end

	-- Espadas girando na vitrine (inclinadas 45°, girando no próprio eixo)
	local function poseSpinners(angle: number)
		for _, spinner in shop.Spinners do
			local center = spinner.Center
			spinner.Model:PivotTo(
				CFrame.new(center)
					* CFrame.Angles(0, 0, math.rad(-45))
					* CFrame.Angles(0, angle, 0)
					* CFrame.new(-center)
					* spinner.Pivot
			)
		end
	end
	poseSpinners(0)
	RunService.RenderStepped:Connect(function(dt)
		if not window.Visible then
			return
		end
		shop.Angle = (shop.Angle or 0) + dt * 0.8
		poseSpinners(shop.Angle)
	end)

	refreshShop()
end

function UIController.SetShopOpen(open: boolean)
	shop.Window.Visible = open
	if open then
		controlsWindow.Visible = false
		refreshShop()
	end
end

--------------------------------------------------------------------------
-- Controles
--------------------------------------------------------------------------
local function buildControls()
	controlsWindow = panel({
		Name = "Controls",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 400),
		Visible = false,
		BackgroundTransparency = 0.05,
		Parent = screen,
	})
	label({
		Size = UDim2.new(1, -32, 0, 32),
		Position = UDim2.fromOffset(16, 12),
		Text = "COMO JOGAR",
		TextColor3 = THEME.Gold,
		Font = Enum.Font.GothamBlack,
		Parent = controlsWindow,
	})
	local lines = {
		{ "Clique / Toque", "Atacar (3º golpe = finalizador)" },
		{ "F (segurar)", "Bloquear: -75% de dano" },
		{ "F na hora certa", "PARRY: atordoa o inimigo" },
		{ "Q", "Esquiva (fica invencível)" },
		{ "R", "Habilidade especial da espada" },
		{ "B", "Abrir a loja" },
		{ "1", "Guardar / sacar a espada" },
		{ "", "" },
		{ "Vila", "Zona segura, loja e treino" },
		{ "Arena (norte)", "PvP valendo moedas" },
		{ "Floresta (leste)", "Monstros: XP e moedas" },
		{ "Ruínas (oeste)", "Chefe: Rei Caído" },
	}
	for i, line in lines do
		label({
			Size = UDim2.fromOffset(150, 22),
			Position = UDim2.fromOffset(20, 52 + (i - 1) * 26),
			Text = line[1],
			TextColor3 = THEME.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = controlsWindow,
		})
		label({
			Size = UDim2.fromOffset(250, 22),
			Position = UDim2.fromOffset(175, 52 + (i - 1) * 26),
			Text = line[2],
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = controlsWindow,
		})
	end
	local close = button({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -10, 0, 10),
		Text = "X",
		BackgroundColor3 = THEME.Red,
		Parent = controlsWindow,
	})
	close.MouseButton1Click:Connect(function()
		controlsWindow.Visible = false
	end)
end

--------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------
function UIController.Init()
	screen = make("ScreenGui", {
		Name = "LaminasHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	buildHUD()
	buildShop()
	buildControls()

	hud.ShopButton.MouseButton1Click:Connect(function()
		UIController.SetShopOpen(not shop.Window.Visible)
	end)
	hud.ControlsButton.MouseButton1Click:Connect(function()
		controlsWindow.Visible = not controlsWindow.Visible
		if controlsWindow.Visible then
			shop.Window.Visible = false
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			UIController.SetShopOpen(not shop.Window.Visible)
		elseif input.KeyCode == Enum.KeyCode.H then
			controlsWindow.Visible = not controlsWindow.Visible
			if controlsWindow.Visible then
				shop.Window.Visible = false
			end
		end
	end)

	for _, attribute in { "Level", "XP", "XPNeeded", "Coins", "Equipped" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refreshStats()
			refreshShop()
		end)
	end
	player:GetAttributeChangedSignal("Owned"):Connect(refreshShop)
	player:GetAttributeChangedSignal("Zone"):Connect(refreshZone)
	player:GetAttributeChangedSignal("Combo"):Connect(showCombo)

	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end

	Remotes.Notify.OnClientEvent:Connect(UIController.Notify)
	Remotes.KillFeed.OnClientEvent:Connect(addKillFeed)
	Remotes.BossBar.OnClientEvent:Connect(updateBoss)
	Remotes.OpenShop.OnClientEvent:Connect(function()
		UIController.SetShopOpen(true)
	end)

	RunService.RenderStepped:Connect(updateEveryFrame)

	refreshStats()
	refreshZone()

	task.delay(2, function()
		UIController.Notify({
			Text = "LÂMINAS DO REINO",
			Sub = "Aperte H para ver os controles. Boa sorte, guerreiro!",
			Color = THEME.Gold,
		})
	end)
end

return UIController
