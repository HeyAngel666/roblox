--[[
	UIController
	HUD do jogo:
	  - Cartão do jogador (foto, nível, XP, moedas, abates)
	  - Barras de vida e estamina + habilidade especial
	  - Zona atual, minimapa, feed de abates, barra do chefe
	  - Notificações, tela de subir de nível e tela de derrota
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local ShopUI = require(script.Parent:WaitForChild("ShopUI"))
local Minimap = require(script.Parent:WaitForChild("Minimap"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local C, F = Theme.Colors, Theme.Fonts
local make, label, tween = Theme.make, Theme.label, Theme.tween

local UIController = {}

local screen: ScreenGui
local overlay: ScreenGui
local hud = {} :: any
local helpWindow: Frame
local bigQueue = {}
local showingBig = false
local orderCounter = 0

local function nextOrder(): number
	orderCounter += 1
	return orderCounter
end

local function colorFrom(value): Color3
	if typeof(value) == "Color3" then
		return value
	elseif type(value) == "table" then
		return Util.Color(value)
	end
	return C.Gold
end

--------------------------------------------------------------------------
-- Notificações
--------------------------------------------------------------------------
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
	holder.Line.BackgroundTransparency = 1
	holder.Scale.Scale = 0.5
	tween(holder.Scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(holder.Title, 0.25, { TextTransparency = 0 })
	tween(holder.Sub, 0.25, { TextTransparency = 0 })
	tween(holder.Line, 0.25, { BackgroundTransparency = 0.2 })
	task.delay(2.8, function()
		tween(holder.Title, 0.4, { TextTransparency = 1 })
		tween(holder.Sub, 0.4, { TextTransparency = 1 })
		tween(holder.Line, 0.4, { BackgroundTransparency = 1 })
		task.wait(0.45)
		holder.Visible = false
		showingBig = false
		showNextBig()
	end)
end

local function toast(data)
	local frame = Theme.panel({
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundTransparency = 0.1,
		Parent = hud.Toasts,
	})
	local accent = make("Frame", {
		Size = UDim2.new(0, 5, 1, -14),
		Position = UDim2.fromOffset(8, 7),
		BackgroundColor3 = colorFrom(data.Color),
		BorderSizePixel = 0,
		Parent = frame,
	})
	Theme.round(accent)
	label({
		Size = UDim2.new(1, -30, 0, 24),
		Position = UDim2.fromOffset(20, 6),
		Text = data.Text or "",
		TextColor3 = colorFrom(data.Color),
		Font = F.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	label({
		Size = UDim2.new(1, -30, 0, 18),
		Position = UDim2.fromOffset(20, 31),
		Text = data.Sub or "",
		TextColor3 = C.SubText,
		Font = F.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local scale = make("UIScale", { Scale = 0.6, Parent = frame })
	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(4.5, function()
		tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.3)
		frame:Destroy()
	end)
end

--------------------------------------------------------------------------
-- Tela de subir de nível
--------------------------------------------------------------------------
local function levelUp(data)
	local holder = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(420, 420),
		BackgroundTransparency = 1,
		Parent = overlay,
	})
	local rays = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = holder,
	})
	for i = 0, 11 do
		local ray = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 26, 1, 0),
			Rotation = i * 15,
			BackgroundColor3 = C.Gold,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Parent = rays,
		})
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.35),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Rotation = 90,
			Parent = ray,
		})
	end
	local badge = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(130, 130),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = holder,
	})
	Theme.round(badge)
	Theme.gradient(badge, Color3.fromRGB(255, 235, 150), Color3.fromRGB(205, 125, 20), 45)
	Theme.stroke(badge, Color3.fromRGB(120, 70, 10), 4)
	label({
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromOffset(0, 22),
		Text = "NÍVEL",
		Font = F.Title,
		TextColor3 = Color3.fromRGB(110, 60, 10),
		Parent = badge,
	})
	label({
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.fromOffset(0, 44),
		Text = tostring(player:GetAttribute("Level") or ""),
		Font = F.Title,
		TextColor3 = Color3.fromRGB(80, 40, 5),
		Parent = badge,
	})
	local title = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 80),
		Size = UDim2.fromOffset(520, 56),
		Text = "SUBIU DE NÍVEL!",
		Font = F.Title,
		TextColor3 = C.Gold,
		Parent = holder,
	})
	make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(80, 40, 0), Parent = title })
	label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 136),
		Size = UDim2.fromOffset(420, 26),
		Text = data.Sub or "",
		Font = F.Text,
		TextColor3 = C.Text,
		Parent = holder,
	})

	local scale = make("UIScale", { Scale = 0.2, Parent = holder })
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 25
	end)
	task.delay(3, function()
		tween(scale, 0.35, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.4)
		spin:Disconnect()
		holder:Destroy()
	end)
end

--------------------------------------------------------------------------
-- Tela de derrota
--------------------------------------------------------------------------
local function deathScreen(data)
	local frame = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(40, 0, 5),
		BackgroundTransparency = 1,
		Parent = overlay,
	})
	Theme.gradient(frame, Color3.fromRGB(90, 0, 10), Color3.fromRGB(10, 0, 0), 90)
	local title = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(600, 90),
		Text = "VOCÊ CAIU",
		Font = F.Title,
		TextColor3 = Color3.fromRGB(255, 80, 80),
		TextTransparency = 1,
		Parent = frame,
	})
	local titleStroke = make("UIStroke", { Thickness = 3, Transparency = 1, Parent = title })
	local sub = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 62),
		Size = UDim2.fromOffset(600, 30),
		Text = data.Sub or "",
		Font = F.Text,
		TextColor3 = C.Text,
		TextTransparency = 1,
		Parent = frame,
	})
	local countdown = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 104),
		Size = UDim2.fromOffset(400, 24),
		Text = "",
		Font = F.Number,
		TextColor3 = C.SubText,
		Parent = frame,
	})
	tween(frame, 0.6, { BackgroundTransparency = 0.35 })
	tween(title, 0.6, { TextTransparency = 0 })
	tween(titleStroke, 0.6, { Transparency = 0 })
	tween(sub, 0.6, { TextTransparency = 0 })
	local total = Players.RespawnTime
	task.spawn(function()
		for i = math.ceil(total), 1, -1 do
			countdown.Text = ("Voltando em %d..."):format(i)
			task.wait(1)
		end
		tween(frame, 0.4, { BackgroundTransparency = 1 })
		tween(title, 0.4, { TextTransparency = 1 })
		tween(titleStroke, 0.4, { Transparency = 1 })
		tween(sub, 0.4, { TextTransparency = 1 })
		countdown.Text = ""
		task.wait(0.45)
		frame:Destroy()
	end)
end

function UIController.Notify(data)
	if type(data) ~= "table" then
		return
	end
	if data.Style == "LevelUp" then
		levelUp(data)
		return
	elseif data.Style == "Death" then
		deathScreen(data)
		return
	end
	if data.Small then
		toast(data)
		return
	end
	table.insert(bigQueue, data)
	showNextBig()
end

local function addKillFeed(data)
	if type(data) ~= "table" then
		return
	end
	local entry = Theme.panel({
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 0.2,
		Radius = 8,
		Parent = hud.KillFeed,
	}, false)
	local text
	if data.Killer then
		text = ('<font color="#%s">%s</font>  derrotou  <font color="#FFFFFF">%s</font>'):format(
			data.KillerIsPlayer and "FF7A6E" or "FFD27A",
			data.Killer,
			data.Victim or "?"
		)
	else
		text = ("%s caiu"):format(data.Victim or "?")
	end
	label({
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Text = text,
		RichText = true,
		TextColor3 = C.SubText,
		Font = F.Text,
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
	task.delay(8, function()
		if entry.Parent then
			entry:Destroy()
		end
	end)
end

--------------------------------------------------------------------------
-- Construção do HUD
--------------------------------------------------------------------------
local function edgeVignette(parent: Instance, color: Color3)
	local holder = make("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local sides = {
		{ UDim2.new(0, 0, 0, 0), UDim2.new(0.18, 0, 1, 0), 0 },
		{ UDim2.new(0.82, 0, 0, 0), UDim2.new(0.18, 0, 1, 0), 180 },
		{ UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.2, 0), 90 },
		{ UDim2.new(0, 0, 0.8, 0), UDim2.new(1, 0, 0.2, 0), 270 },
	}
	for _, side in sides do
		local frame = make("Frame", {
			Position = side[1],
			Size = side[2],
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = holder,
		})
		make("UIGradient", {
			Transparency = NumberSequence.new(0, 1),
			Rotation = side[3],
			Parent = frame,
		})
	end
	return holder
end

local function buildHUD()
	-- Cartão do jogador ------------------------------------------------
	local card = Theme.panel({
		Name = "PlayerCard",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(320, 100),
		Parent = screen,
	})
	local avatar = make("ImageLabel", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(80, 80),
		BackgroundColor3 = C.PanelLight,
		Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(player.UserId),
		Parent = card,
	})
	Theme.round(avatar)
	Theme.stroke(avatar, Color3.new(1, 1, 1), 3, true)
	local badge = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(78, 80),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = card,
	})
	Theme.round(badge)
	Theme.gradient(badge, Color3.fromRGB(255, 232, 140), Color3.fromRGB(205, 125, 20), 45)
	Theme.stroke(badge, Color3.fromRGB(110, 60, 5), 2)
	hud.Level = label({
		Size = UDim2.fromScale(1, 1),
		Text = "1",
		Font = F.Title,
		TextColor3 = Color3.fromRGB(80, 40, 5),
		ZIndex = 4,
		Parent = badge,
	})
	label({
		Size = UDim2.fromOffset(210, 24),
		Position = UDim2.fromOffset(102, 10),
		Text = player.DisplayName,
		Font = F.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	hud.XP = Theme.bar(card, {
		Size = UDim2.fromOffset(206, 18),
		Position = UDim2.fromOffset(102, 40),
	}, C.XP)
	Theme.coin(card, 22, UDim2.fromOffset(102, 68))
	hud.Coins = label({
		Size = UDim2.fromOffset(110, 22),
		Position = UDim2.fromOffset(130, 68),
		Text = "0",
		Font = F.Number,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	hud.Kills = label({
		Size = UDim2.fromOffset(80, 20),
		Position = UDim2.fromOffset(228, 69),
		Text = "0 abates",
		Font = F.Text,
		TextColor3 = Color3.fromRGB(255, 140, 120),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})

	-- Botões ------------------------------------------------------------
	hud.ShopButton = Theme.button({
		Name = "ShopButton",
		Text = "LOJA  (B)",
		Size = UDim2.fromOffset(150, 46),
		Position = UDim2.fromOffset(14, 126),
		Parent = screen,
	}, Color3.fromRGB(235, 160, 40))
	hud.HelpButton = Theme.button({
		Name = "HelpButton",
		Text = "AJUDA  (H)",
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.fromOffset(14, 180),
		Parent = screen,
	}, Color3.fromRGB(80, 120, 210))

	-- Zona ----------------------------------------------------------------
	local zone = Theme.panel({
		Name = "Zone",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(300, 40),
		Radius = 20,
		Parent = screen,
	})
	hud.ZoneDot = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = C.Green,
		Parent = zone,
	})
	Theme.round(hud.ZoneDot)
	hud.ZoneText = label({
		Size = UDim2.new(1, -40, 1, -12),
		Position = UDim2.fromOffset(32, 6),
		Text = "",
		RichText = true,
		Font = F.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = zone,
	})

	-- Faixa grande ao entrar numa zona
	local banner = make("Frame", {
		Name = "ZoneBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(700, 100),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	hud.BannerTitle = label({
		Size = UDim2.new(1, 0, 0, 62),
		Text = "",
		Font = F.Title,
		Parent = banner,
	})
	make("UIStroke", { Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 0.2, Parent = hud.BannerTitle })
	hud.BannerSub = label({
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 70),
		Text = "",
		Font = F.Text,
		TextColor3 = C.Text,
		TextStrokeTransparency = 0.4,
		Parent = banner,
	})
	for _, side in { -1, 1 } do
		local line = make("Frame", {
			Name = "Line",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 230, 0, 66),
			Size = UDim2.fromOffset(200, 3),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Parent = banner,
		})
		make("UIGradient", {
			Transparency = NumberSequence.new(side < 0 and 1 or 0, side < 0 and 0 or 1),
			Parent = line,
		})
	end
	hud.Banner = banner

	-- Barra do chefe ----------------------------------------------------
	local boss = Theme.panel({
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(540, 62),
		Visible = false,
		Parent = screen,
	})
	hud.BossName = label({
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 5),
		Text = "",
		Font = F.Title,
		TextColor3 = Color3.fromRGB(255, 90, 100),
		Parent = boss,
	})
	hud.BossHP = Theme.bar(boss, {
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 32),
	}, Color3.fromRGB(215, 30, 55))
	hud.Boss = boss
	hud.BossData = nil

	-- Barras inferiores ---------------------------------------------------
	local bottom = make("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -44, 1, -18),
		Size = UDim2.fromOffset(440, 70),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	hud.Status = label({
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		Font = F.Title,
		TextStrokeTransparency = 0.3,
		Parent = bottom,
	})
	hud.HP = Theme.bar(bottom, {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 26),
	}, C.Health)
	hud.Stamina = Theme.bar(bottom, {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.fromOffset(0, 60),
		Radius = 5,
	}, C.Stamina)
	hud.Stamina.Label.Visible = false

	-- Habilidade especial
	local slot = Theme.panel({
		Name = "Special",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(1, 14, 1, 0),
		Size = UDim2.fromOffset(78, 78),
		Radius = 16,
		Parent = bottom,
	})
	hud.SpecialIcon = Theme.swordIcon(slot, 46)
	hud.SpecialIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	hud.SpecialIcon.Position = UDim2.fromScale(0.5, 0.45)
	hud.SpecialShade = make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = slot,
	})
	Theme.corner(hud.SpecialShade, 16)
	hud.SpecialTime = label({
		Size = UDim2.fromScale(1, 0.5),
		Position = UDim2.fromScale(0, 0.2),
		Text = "",
		Font = F.Title,
		ZIndex = 4,
		Parent = slot,
	})
	local key = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 6, 0, 6),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 5,
		Parent = slot,
	})
	Theme.round(key)
	Theme.gradient(key, Color3.fromRGB(255, 232, 140), Color3.fromRGB(205, 125, 20), 45)
	label({ Size = UDim2.fromScale(1, 1), Text = "R", Font = F.Title, TextColor3 = Color3.fromRGB(80, 40, 5), ZIndex = 6, Parent = key })
	hud.SpecialName = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(130, 16),
		Text = "",
		Font = F.Text,
		TextColor3 = C.Gold,
		TextStrokeTransparency = 0.4,
		Parent = slot,
	})
	hud.SpecialSlot = slot

	-- Combo
	hud.Combo = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(300, 46),
		Text = "",
		Font = F.Title,
		TextColor3 = C.Gold,
		Parent = screen,
	})
	make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(70, 35, 0), Parent = hud.Combo })
	hud.ComboScale = make("UIScale", { Parent = hud.Combo })

	-- Minimapa e feed de abates
	Minimap.Build(screen)
	hud.KillFeed = make("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 226),
		Size = UDim2.fromOffset(330, 200),
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
		Position = UDim2.new(1, -14, 1, -120),
		Size = UDim2.fromOffset(310, 300),
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
		Size = UDim2.fromOffset(720, 110),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = overlay,
	})
	make("UIScale", { Name = "Scale", Parent = big })
	local bigTitle = label({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 62),
		Text = "",
		Font = F.Title,
		Parent = big,
	})
	make("UIStroke", { Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 0.15, Parent = bigTitle })
	local line = make("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(420, 3),
		BackgroundColor3 = C.Gold,
		BorderSizePixel = 0,
		Parent = big,
	})
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = line,
	})
	label({
		Name = "Sub",
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 76),
		Text = "",
		Font = F.Text,
		TextColor3 = C.Text,
		TextStrokeTransparency = 0.3,
		Parent = big,
	})
	hud.BigNotify = big

	-- Vermelho nas bordas ao levar dano
	hud.DamageFlash = edgeVignette(overlay, Color3.fromRGB(220, 0, 0))
	for _, frame in hud.DamageFlash:GetChildren() do
		(frame :: Frame).BackgroundTransparency = 1
	end
end

--------------------------------------------------------------------------
-- Ajuda
--------------------------------------------------------------------------
local function buildHelp()
	helpWindow = Theme.panel({
		Name = "Help",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(500, 440),
		Visible = false,
		ZIndex = 10,
		Parent = screen,
	})
	label({
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.fromOffset(20, 14),
		Text = "COMO JOGAR",
		Font = F.Title,
		TextColor3 = C.Gold,
		Parent = helpWindow,
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
			Size = UDim2.fromOffset(170, 22),
			Position = UDim2.fromOffset(26, 64 + (i - 1) * 28),
			Text = line[1],
			Font = F.Text,
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = helpWindow,
		})
		label({
			Size = UDim2.fromOffset(280, 22),
			Position = UDim2.fromOffset(200, 64 + (i - 1) * 28),
			Text = line[2],
			Font = F.Body,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = helpWindow,
		})
	end
	local close = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -12, 0, 12),
		Text = "X",
		Parent = helpWindow,
	}, C.Red)
	close.MouseButton1Click:Connect(function()
		helpWindow.Visible = false
	end)
end

function UIController.ToggleHelp(force: boolean?)
	local open = if force ~= nil then force else not helpWindow.Visible
	helpWindow.Visible = open
	if open then
		ShopUI.SetOpen(false)
		local scale = helpWindow:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = helpWindow })
		scale.Scale = 0.85
		tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

function UIController.ToggleShop(force: boolean?)
	local open = if force ~= nil then force else not ShopUI.IsOpen()
	ShopUI.SetOpen(open)
	if open then
		helpWindow.Visible = false
	end
end

--------------------------------------------------------------------------
-- Atualizações
--------------------------------------------------------------------------
local function refreshStats()
	local level = player:GetAttribute("Level") or 1
	local xp = player:GetAttribute("XP") or 0
	local needed = player:GetAttribute("XPNeeded") or Config.XPForLevel(level)
	hud.Level.Text = tostring(level)
	hud.XP.Set(xp / math.max(needed, 1))
	hud.XP.Label.Text = ("%s / %s XP"):format(Util.FormatNumber(xp), Util.FormatNumber(needed))
	hud.Coins.Text = Util.FormatNumber(player:GetAttribute("Coins") or 0)
	hud.Kills.Text = ("%d abates"):format(player:GetAttribute("Kills") or 0)
	local sword = Config.SwordById[player:GetAttribute("Equipped") or ""]
	hud.SpecialName.Text = sword and sword.SpecialName or ""
end

local lastZone = nil
local function refreshZone()
	local zoneName = player:GetAttribute("Zone") or Config.DefaultZone
	local zone = Config.Zones[zoneName] or Config.Zones[Config.DefaultZone]
	local color = Util.Color(zone.Color)
	hud.ZoneDot.BackgroundColor3 = color
	hud.ZoneText.Text = ('%s  <font color="#B4AFC8" size="14">%s</font>'):format(zone.DisplayName, zone.Subtitle)

	if lastZone ~= nil and lastZone ~= zoneName then
		local banner = hud.Banner
		hud.BannerTitle.Text = zone.DisplayName
		hud.BannerTitle.TextColor3 = color
		hud.BannerSub.Text = zone.Subtitle
		banner.Visible = true
		hud.BannerTitle.TextTransparency = 1
		hud.BannerSub.TextTransparency = 1
		tween(hud.BannerTitle, 0.4, { TextTransparency = 0 })
		tween(hud.BannerSub, 0.4, { TextTransparency = 0 })
		local token = os.clock()
		hud.BannerToken = token
		task.delay(2.6, function()
			if hud.BannerToken ~= token then
				return
			end
			tween(hud.BannerTitle, 0.5, { TextTransparency = 1 })
			tween(hud.BannerSub, 0.5, { TextTransparency = 1 })
			task.wait(0.55)
			if hud.BannerToken == token then
				banner.Visible = false
			end
		end)
	end
	lastZone = zoneName
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
			for _, frame in hud.DamageFlash:GetChildren() do
				(frame :: Frame).BackgroundTransparency = 0.35
				tween(frame, 0.5, { BackgroundTransparency = 1 })
			end
		end
		lastHealth = health
	end)
end

local function updateEveryFrame()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ratio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		hud.HP.Set(ratio)
		hud.HP.SetColor(C.HealthLow:Lerp(C.Health, ratio))
		hud.HP.Label.Text = ("%d / %d"):format(math.ceil(humanoid.Health), humanoid.MaxHealth)
	end

	local stamina = player:GetAttribute("Stamina") or 100
	local staminaMax = player:GetAttribute("StaminaMax") or 100
	hud.Stamina.Set(stamina / staminaMax)

	local readyAt = player:GetAttribute("SpecialReadyAt") or 0
	local cooldown = player:GetAttribute("SpecialCooldown") or 8
	local remaining = readyAt - workspace:GetServerTimeNow()
	if remaining > 0 then
		hud.SpecialShade.Size = UDim2.fromScale(1, math.clamp(remaining / cooldown, 0, 1))
		hud.SpecialTime.Text = ("%.1f"):format(remaining)
	else
		hud.SpecialShade.Size = UDim2.fromScale(1, 0)
		hud.SpecialTime.Text = ""
	end

	local status, color = "", C.Text
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
			status, color = "ZONA SEGURA", Color3.fromRGB(120, 230, 140)
		end
	end
	hud.Status.Text = status
	hud.Status.TextColor3 = color

	Minimap.Update()
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
	hud.Combo.TextColor3 = combo == 3 and Color3.fromRGB(255, 120, 60) or C.Gold
	hud.Combo.TextTransparency = 0
	hud.ComboScale.Scale = 1.6
	tween(hud.ComboScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
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
	hud.BossName.Text = data.Name .. (data.Enraged and "  -  FURIOSO" or "")
	hud.BossHP.Set(data.Health / math.max(data.MaxHealth, 1))
	hud.BossHP.Label.Text = ("%s / %s"):format(Util.FormatNumber(data.Health), Util.FormatNumber(data.MaxHealth))
	hud.Boss.Visible = player:GetAttribute("Zone") == "Ruinas"
end

--------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------
function UIController.SetVisible(visible: boolean)
	screen.Enabled = visible
end

function UIController.Init()
	local playerGui = player:WaitForChild("PlayerGui")
	screen = make("ScreenGui", {
		Name = "LaminasHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = playerGui,
	})
	overlay = make("ScreenGui", {
		Name = "LaminasOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 5,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})
	UIController.Screen = screen

	buildHUD()
	buildHelp()
	ShopUI.Build(screen)

	hud.ShopButton.MouseButton1Click:Connect(function()
		UIController.ToggleShop()
	end)
	hud.HelpButton.MouseButton1Click:Connect(function()
		UIController.ToggleHelp()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not screen.Enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			UIController.ToggleShop()
		elseif input.KeyCode == Enum.KeyCode.H then
			UIController.ToggleHelp()
		end
	end)

	for _, attribute in { "Level", "XP", "XPNeeded", "Coins", "Equipped", "Kills" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshStats)
	end
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
		UIController.ToggleShop(true)
	end)

	RunService.RenderStepped:Connect(updateEveryFrame)

	refreshStats()
	refreshZone()
end

return UIController
