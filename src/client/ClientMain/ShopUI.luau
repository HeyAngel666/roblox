--[[
	ShopUI - Ferraria
	Lista de espadas à esquerda (com raridade) e detalhes à direita:
	espada 3D girando, atributos em barras e botão de comprar/equipar.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SwordsFolder = ReplicatedStorage:WaitForChild("Swords")
local player = Players.LocalPlayer

local C, F = Theme.Colors, Theme.Fonts
local make, label, tween = Theme.make, Theme.label, Theme.tween

local ShopUI = {}

local window: Frame
local scale: UIScale
local selected = Config.DefaultSword
local cards = {}
local spinners = {}
local detail = {} :: any
local busy = false
local angle = 0

-- Maiores valores (para as barras de atributo)
local MAX = { Damage = 0, Range = 0, Speed = 0, Special = 0 }
for _, sword in Config.Swords do
	MAX.Damage = math.max(MAX.Damage, sword.Damage)
	MAX.Range = math.max(MAX.Range, sword.Range)
	MAX.Speed = math.max(MAX.Speed, 1 / sword.Cooldown)
	MAX.Special = math.max(MAX.Special, sword.SpecialDamage)
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

local function rarityColor(sword): Color3
	return Theme.Rarity[sword.Rarity or "Comum"] or Theme.Rarity.Comum
end

-- Espada 3D dentro de um ViewportFrame
local function viewport(parent: Instance, swordId: string, size: UDim2, position: UDim2, tilt: number)
	local frame = make("ViewportFrame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(180, 175, 190),
		LightColor = Color3.fromRGB(255, 248, 235),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	})
	local template = SwordsFolder:FindFirstChild(swordId)
	if not template then
		return frame
	end
	local model = Instance.new("Model")
	for _, child in template:Clone():GetChildren() do
		child.Parent = model
	end
	model.Parent = frame
	local center, bounds = model:GetBoundingBox()
	local length = math.max(bounds.X, bounds.Y, bounds.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(center.Position + Vector3.new(0, 0, length * 1.7), center.Position)
	camera.Parent = frame
	frame.CurrentCamera = camera
	table.insert(spinners, { Model = model, Center = center.Position, Pivot = model:GetPivot(), Tilt = tilt })
	return frame
end

local function shopMessage(text: string, good: boolean)
	detail.Message.Text = text
	detail.Message.TextColor3 = good and C.Health or Color3.fromRGB(255, 110, 100)
	detail.Message.TextTransparency = 0
	local token = os.clock()
	detail.MessageToken = token
	task.delay(3, function()
		if detail.MessageToken == token then
			tween(detail.Message, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function statRow(parent: Instance, y: number, name: string, color: Color3)
	label({
		Size = UDim2.fromOffset(110, 20),
		Position = UDim2.fromOffset(0, y),
		Text = name,
		Font = F.Text,
		TextColor3 = C.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
	local bar = Theme.bar(parent, {
		Size = UDim2.new(1, -170, 0, 14),
		Position = UDim2.fromOffset(110, y + 3),
		Radius = 7,
	}, color)
	bar.Label.Visible = false
	local value = label({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(52, 20),
		Position = UDim2.new(1, 0, 0, y),
		Text = "",
		Font = F.Number,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = parent,
	})
	return bar, value
end

local function refreshDetail()
	local sword = Config.SwordById[selected]
	if not sword then
		return
	end
	local owned = getOwned()
	local equipped = player:GetAttribute("Equipped")
	local level = player:GetAttribute("Level") or 1
	local coins = player:GetAttribute("Coins") or 0
	local rarity = rarityColor(sword)
	local element = Config.Elements[sword.Element] or Config.Elements.none

	detail.Name.Text = sword.Name
	detail.Name.TextColor3 = rarity
	detail.Rarity.Text = string.upper(sword.Rarity or "Comum")
	Theme.recolor(detail.RarityPill, rarity)
	detail.Description.Text = sword.Description
	detail.Special.Text = ("Especial: %s  (%d de dano)"):format(sword.SpecialName, sword.SpecialDamage)
	detail.Element.Text = sword.Element ~= "none" and ("Elemento: " .. element.Name) or "Sem elemento"
	detail.Element.TextColor3 = sword.Element ~= "none" and Util.Color(element.Color) or C.SubText

	detail.Damage.Set(sword.Damage / MAX.Damage)
	detail.DamageValue.Text = tostring(sword.Damage)
	detail.Range.Set(sword.Range / MAX.Range)
	detail.RangeValue.Text = ("%.1f"):format(sword.Range)
	detail.Speed.Set((1 / sword.Cooldown) / MAX.Speed)
	detail.SpeedValue.Text = ("%.2fs"):format(sword.Cooldown)
	detail.SpecialBar.Set(sword.SpecialDamage / MAX.Special)
	detail.SpecialValue.Text = tostring(sword.SpecialDamage)

	-- Troca a espada 3D grande
	if detail.ViewportId ~= sword.Id then
		detail.ViewportId = sword.Id
		if detail.Viewport then
			for i = #spinners, 1, -1 do
				if spinners[i].Model:IsDescendantOf(detail.Viewport) then
					table.remove(spinners, i)
				end
			end
			detail.Viewport:Destroy()
		end
		detail.Viewport = viewport(detail.Preview, sword.Id, UDim2.fromScale(1, 1), UDim2.new(), -35)
		detail.Glow.BackgroundColor3 = rarity
	end

	local button = detail.Button
	if equipped == sword.Id then
		button.Text = "EQUIPADA"
		Theme.recolor(button, C.Gray)
	elseif owned[sword.Id] then
		button.Text = "EQUIPAR"
		Theme.recolor(button, C.Blue)
	elseif sword.Price == nil then
		button.Text = "SÓ CAI DO CHEFE"
		Theme.recolor(button, Color3.fromRGB(130, 30, 45))
	elseif level < sword.Level then
		button.Text = "REQUER NÍVEL " .. sword.Level
		Theme.recolor(button, C.Gray)
	else
		button.Text = "COMPRAR  " .. Util.FormatNumber(sword.Price)
		Theme.recolor(button, coins >= sword.Price and C.Green or C.Red)
	end
end

local function refreshCards()
	local owned = getOwned()
	local equipped = player:GetAttribute("Equipped")
	local level = player:GetAttribute("Level") or 1
	detail.Coins.Text = Util.FormatNumber(player:GetAttribute("Coins") or 0)
	for id, card in cards do
		local sword = Config.SwordById[id]
		local state
		if equipped == id then
			state, card.State.TextColor3 = "EQUIPADA", C.Health
		elseif owned[id] then
			state, card.State.TextColor3 = "NA MOCHILA", Color3.fromRGB(140, 190, 255)
		elseif sword.Price == nil then
			state, card.State.TextColor3 = "DROP DO CHEFE", Color3.fromRGB(255, 90, 100)
		elseif level < sword.Level then
			state, card.State.TextColor3 = "NÍVEL " .. sword.Level, C.SubText
		else
			state, card.State.TextColor3 = Util.FormatNumber(sword.Price) .. " moedas", C.Gold
		end
		card.State.Text = state
		card.Highlight.Visible = id == selected
	end
	refreshDetail()
end

local function select(id: string)
	selected = id
	refreshCards()
end

function ShopUI.Build(screen: ScreenGui)
	window = Theme.panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.94, 0, 0.84, 0),
		Visible = false,
		ZIndex = 10,
		Radius = 16,
		Parent = screen,
	})
	make("UISizeConstraint", { MaxSize = Vector2.new(900, 580), Parent = window })
	scale = make("UIScale", { Parent = window })

	-- Cabeçalho
	local swordIcon = Theme.swordIcon(window, 40)
	swordIcon.Position = UDim2.fromOffset(18, 12)
	local title = label({
		Size = UDim2.new(0.5, 0, 0, 40),
		Position = UDim2.fromOffset(66, 14),
		Text = "FERRARIA DO REINO",
		Font = F.Title,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	make("UIStroke", { Thickness = 2, Color = Color3.fromRGB(70, 35, 0), Parent = title })

	local coinPill = Theme.panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -70, 0, 16),
		Size = UDim2.fromOffset(170, 36),
		Radius = 18,
		Parent = window,
	}, false)
	Theme.coin(coinPill, 24, UDim2.fromOffset(8, 6))
	detail.Coins = label({
		Size = UDim2.new(1, -46, 1, -10),
		Position = UDim2.fromOffset(38, 5),
		Text = "0",
		Font = F.Number,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = coinPill,
	})
	local close = Theme.button({
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.new(1, -14, 0, 13),
		Text = "X",
		Parent = window,
	}, C.Red)
	close.MouseButton1Click:Connect(function()
		ShopUI.SetOpen(false)
	end)

	-- Lista de espadas
	local list = make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 68),
		Size = UDim2.new(0.42, -16, 1, -84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = window,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		make("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	})

	for _, sword in Config.Swords do
		local rarity = rarityColor(sword)
		local card = make("TextButton", {
			Name = sword.Id,
			LayoutOrder = sword.Order,
			Size = UDim2.new(1, 0, 0, 78),
			BackgroundColor3 = Color3.new(1, 1, 1),
			AutoButtonColor = false,
			Text = "",
			Parent = list,
		})
		Theme.corner(card, 12)
		Theme.gradient(card, C.PanelLight, C.Panel, 0)
		Theme.stroke(card, rarity, 2)
		local strip = make("Frame", {
			Size = UDim2.new(0, 6, 1, -16),
			Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = rarity,
			BorderSizePixel = 0,
			Parent = card,
		})
		Theme.round(strip)
		viewport(card, sword.Id, UDim2.fromOffset(64, 64), UDim2.fromOffset(18, 7), -45)
		label({
			Size = UDim2.new(1, -100, 0, 24),
			Position = UDim2.fromOffset(90, 10),
			Text = sword.Name,
			Font = F.Title,
			TextColor3 = rarity,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		label({
			Size = UDim2.new(0.5, -50, 0, 16),
			Position = UDim2.fromOffset(90, 38),
			Text = string.upper(sword.Rarity or "Comum"),
			Font = F.Bold,
			TextColor3 = rarity:Lerp(Color3.new(1, 1, 1), 0.3),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		local state = label({
			Size = UDim2.new(1, -100, 0, 16),
			Position = UDim2.fromOffset(90, 56),
			Text = "",
			Font = F.Number,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})
		local highlight = make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = rarity,
			BackgroundTransparency = 0.85,
			Visible = false,
			ZIndex = 0,
			Parent = card,
		})
		Theme.corner(highlight, 12)
		local cardScale = make("UIScale", { Parent = card })
		card.MouseEnter:Connect(function()
			tween(cardScale, 0.12, { Scale = 1.03 })
		end)
		card.MouseLeave:Connect(function()
			tween(cardScale, 0.12, { Scale = 1 })
		end)
		card.MouseButton1Click:Connect(function()
			select(sword.Id)
		end)
		cards[sword.Id] = { State = state, Highlight = highlight }
	end

	-- Detalhes
	local right = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 68),
		Size = UDim2.new(0.58, -16, 1, -84),
		BackgroundTransparency = 1,
		Parent = window,
	})
	local previewBox = Theme.panel({
		Size = UDim2.new(0.46, 0, 0.62, 0),
		Radius = 14,
		Parent = right,
	}, false)
	detail.Glow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundColor3 = C.Gold,
		BackgroundTransparency = 0.6,
		Parent = previewBox,
	})
	Theme.round(detail.Glow)
	make("UIGradient", {
		Transparency = NumberSequence.new(0, 1),
		Rotation = 90,
		Parent = detail.Glow,
	})
	detail.Preview = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = previewBox,
	})

	local info = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.54, -14, 0.62, 0),
		BackgroundTransparency = 1,
		Parent = right,
	})
	detail.Name = label({
		Size = UDim2.new(1, 0, 0, 34),
		Text = "",
		Font = F.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	make("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3, Parent = detail.Name })
	detail.RarityPill = make("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.fromOffset(110, 24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = info,
	})
	Theme.round(detail.RarityPill)
	Theme.gradient(detail.RarityPill, C.Gold, C.GoldDark, 90)
	Theme.stroke(detail.RarityPill, C.GoldDark, 1.5)
	detail.Rarity = label({
		Size = UDim2.new(1, -10, 1, -6),
		Position = UDim2.fromOffset(5, 3),
		Text = "",
		Font = F.Bold,
		TextStrokeTransparency = 0.5,
		Parent = detail.RarityPill,
	})
	detail.Description = label({
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 44),
		Text = "",
		Font = F.Body,
		TextColor3 = C.SubText,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = info,
	})
	detail.Element = label({
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		Font = F.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})
	detail.Special = label({
		Position = UDim2.fromOffset(0, 148),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		Font = F.Text,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = info,
	})

	local stats = make("Frame", {
		Position = UDim2.new(0, 0, 0.62, 14),
		Size = UDim2.new(1, 0, 0, 110),
		BackgroundTransparency = 1,
		Parent = right,
	})
	detail.Damage, detail.DamageValue = statRow(stats, 0, "Dano", Color3.fromRGB(240, 80, 70))
	detail.Range, detail.RangeValue = statRow(stats, 26, "Alcance", Color3.fromRGB(90, 180, 255))
	detail.Speed, detail.SpeedValue = statRow(stats, 52, "Velocidade", Color3.fromRGB(120, 230, 120))
	detail.SpecialBar, detail.SpecialValue = statRow(stats, 78, "Especial", C.Gold)

	detail.Button = Theme.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		MaxText = 28,
		Parent = right,
	}, C.Green)
	detail.Message = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
		Text = "",
		Font = F.Text,
		Parent = right,
	})

	detail.Button.MouseButton1Click:Connect(function()
		if busy then
			return
		end
		local sword = Config.SwordById[selected]
		if not sword or player:GetAttribute("Equipped") == sword.Id then
			return
		end
		local action = getOwned()[sword.Id] and "Equip" or "Buy"
		busy = true
		local ok, success, message = pcall(function()
			return Remotes.Shop:InvokeServer(action, sword.Id)
		end)
		busy = false
		if ok then
			shopMessage(message or "", success == true)
		else
			shopMessage("Erro de conexão, tente de novo", false)
		end
		refreshCards()
	end)

	for _, attribute in { "Coins", "Level", "Equipped", "Owned" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshCards)
	end

	-- Espadas girando
	local function pose(spinner)
		local center = spinner.Center
		spinner.Model:PivotTo(
			CFrame.new(center)
				* CFrame.Angles(0, 0, math.rad(spinner.Tilt))
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(-center)
				* spinner.Pivot
		)
	end
	RunService.RenderStepped:Connect(function(dt)
		if not window.Visible then
			return
		end
		angle += dt * 0.9
		for _, spinner in spinners do
			pose(spinner)
		end
	end)

	selected = player:GetAttribute("Equipped") or Config.DefaultSword
	refreshCards()
end

function ShopUI.IsOpen(): boolean
	return window ~= nil and window.Visible
end

function ShopUI.SetOpen(open: boolean)
	if not window then
		return
	end
	if open and not window.Visible then
		window.Visible = true
		scale.Scale = 0.85
		tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		refreshCards()
	elseif not open then
		window.Visible = false
	end
end

return ShopUI
