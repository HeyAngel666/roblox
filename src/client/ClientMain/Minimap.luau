--[[
	Minimap
	Mapa no canto superior direito: zonas, caminhos, lago, você (seta),
	outros jogadores, dragões e o chefe.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Theme = require(script.Parent:WaitForChild("Theme"))

local make, label = Theme.make, Theme.label
local player = Players.LocalPlayer

local Minimap = {}

local SIZE = 196
local WORLD = 960 -- studs mostrados (de -480 a 480)

local canvas: CanvasGroup
local arrow: Frame
local markers: Folder
local dots = {}
local lastUpdate = 0

local function toMap(x: number, z: number): UDim2
	return UDim2.fromOffset((x + WORLD / 2) / WORLD * SIZE, (z + WORLD / 2) / WORLD * SIZE)
end

local function shape(color: Color3, x: number, z: number, w: number, h: number, round: boolean, transparency: number?)
	local frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(x, z),
		Size = UDim2.fromOffset(w / WORLD * SIZE, h / WORLD * SIZE),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Parent = canvas,
	})
	if round then
		Theme.round(frame)
	else
		Theme.corner(frame, 3)
	end
	return frame
end

local function tag(text: string, x: number, z: number)
	label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toMap(x, z),
		Size = UDim2.fromOffset(70, 12),
		Text = text,
		Font = Theme.Fonts.Bold,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.3,
		ZIndex = 4,
		Parent = canvas,
	})
end

function Minimap.Build(screen: ScreenGui)
	local frame = Theme.panel({
		Name = "Minimap",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(SIZE + 10, SIZE + 10),
		Radius = 16,
		Parent = screen,
	})
	canvas = make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundColor3 = Color3.fromRGB(88, 135, 68),
		Parent = frame,
	})
	Theme.corner(canvas, 12)

	-- Montanhas na borda
	make("UIStroke", { Thickness = 6, Color = Color3.fromRGB(120, 115, 108), Parent = canvas })
	-- Zonas
	shape(Color3.fromRGB(52, 90, 48), 265, 0, 235, 345, false)
	shape(Color3.fromRGB(70, 150, 200), 120, 175, 84, 84, true)
	shape(Color3.fromRGB(215, 195, 145), 0, -230, 150, 150, true)
	shape(Color3.fromRGB(70, 65, 80), -265, 0, 100, 100, true)
	shape(Color3.fromRGB(165, 160, 150), 0, 0, 125, 125, false)
	-- Caminhos
	shape(Color3.fromRGB(135, 108, 76), 0, -116, 10, 112, false)
	shape(Color3.fromRGB(135, 108, 76), 135, 0, 150, 10, false)
	shape(Color3.fromRGB(135, 108, 76), -140, 0, 160, 10, false)
	-- Nomes
	tag("VILA", 0, 0)
	tag("ARENA", 0, -230)
	tag("FLORESTA", 265, -30)
	tag("RUÍNAS", -265, 0)
	tag("LAGO", 120, 175)

	markers = make("Folder", { Parent = canvas })

	-- Você (seta)
	arrow = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = canvas,
	})
	for _, side in { -1, 1 } do
		local wing = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, side * 3, 0, 1),
			Size = UDim2.fromOffset(4, 15),
			Rotation = side * 25,
			BackgroundColor3 = Color3.fromRGB(255, 225, 90),
			BorderSizePixel = 0,
			ZIndex = 10,
			Parent = arrow,
		})
		Theme.round(wing)
		make("UIStroke", { Thickness = 1, Color = Color3.fromRGB(60, 30, 0), Parent = wing })
	end

	-- Norte
	label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(20, 14),
		Text = "N",
		Font = Theme.Fonts.Title,
		TextColor3 = Theme.Colors.Gold,
		TextStrokeTransparency = 0.2,
		ZIndex = 11,
		Parent = canvas,
	})
end

local function dot(key, color: Color3, size: number)
	local marker = dots[key]
	if not marker then
		marker = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = color,
			ZIndex = 8,
			Parent = markers,
		})
		Theme.round(marker)
		make("UIStroke", { Thickness = 1.5, Color = Color3.new(0, 0, 0), Parent = marker })
		dots[key] = marker
	end
	marker:SetAttribute("Seen", true)
	return marker
end

function Minimap.Update()
	if not canvas then
		return
	end
	local now = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		arrow.Position = toMap(root.Position.X, root.Position.Z)
		local look = root.CFrame.LookVector
		arrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
	end
	if now - lastUpdate < 0.25 then
		return
	end
	lastUpdate = now

	for _, marker in dots do
		marker:SetAttribute("Seen", false)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			local otherRoot = other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot and otherRoot:IsA("BasePart") then
				dot(other, Color3.new(1, 1, 1), 7).Position = toMap(otherRoot.Position.X, otherRoot.Position.Z)
			end
		end
	end
	for _, dragon in CollectionService:GetTagged("Dragon") do
		local dragonRoot = dragon:FindFirstChild("Root")
		if dragonRoot and dragonRoot:IsA("BasePart") then
			dot(dragon, Color3.fromRGB(255, 130, 40), 9).Position = toMap(dragonRoot.Position.X, dragonRoot.Position.Z)
		end
	end
	for _, npc in CollectionService:GetTagged("NPC") do
		if npc:GetAttribute("NPC") == "ReiCaido" then
			local bossRoot = npc:FindFirstChild("HumanoidRootPart")
			if bossRoot and bossRoot:IsA("BasePart") then
				local marker = dot(npc, Color3.fromRGB(255, 40, 60), 12)
				marker.Position = toMap(bossRoot.Position.X, bossRoot.Position.Z)
			end
		end
	end
	for key, marker in dots do
		if not marker:GetAttribute("Seen") then
			marker:Destroy()
			dots[key] = nil
		end
	end
end

return Minimap
