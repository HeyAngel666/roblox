--[[
	MenuController
	Tela inicial com câmera de cinema passeando pelo mapa (vila, dragão,
	arena, ruínas) e os botões JOGAR / LOJA / COMO JOGAR.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Theme = require(script.Parent:WaitForChild("Theme"))

local C, F = Theme.Colors, Theme.Fonts
local make, label, tween = Theme.make, Theme.label, Theme.tween
local player = Players.LocalPlayer

local MenuController = {}

local SHOT_TIME = 7

local function findDragon(name: string): BasePart?
	for _, dragon in CollectionService:GetTagged("Dragon") do
		if dragon.Name == name then
			local root = dragon:FindFirstChild("Root")
			if root and root:IsA("BasePart") then
				return root
			end
		end
	end
	return nil
end

-- Cada tomada recebe o tempo (s) desde que começou e devolve o CFrame da câmera
local shots = {
	function(t)
		local a = t * 0.07
		local position = Vector3.new(math.cos(a) * 70, 30 + math.sin(t * 0.2) * 3, math.sin(a) * 70)
		return CFrame.lookAt(position, Vector3.new(0, 12, 0))
	end,
	function(t)
		local root = findDragon("Ignis")
		if not root then
			return nil
		end
		local position = (root.CFrame * CFrame.new(32, 10, 55)).Position
		return CFrame.lookAt(position, root.Position + root.CFrame.LookVector * 15)
	end,
	function(t)
		local position = Vector3.new(110 - t * 6, 55, -140 - t * 3)
		return CFrame.lookAt(position, Vector3.new(0, 0, -230))
	end,
	function(t)
		local root = findDragon("Verdantis")
		if not root then
			return nil
		end
		local position = (root.CFrame * CFrame.new(-40, -6, 30)).Position
		return CFrame.lookAt(position, root.Position)
	end,
	function(t)
		local a = 1.2 + t * 0.06
		local position = Vector3.new(-265 + math.cos(a) * 75, 26, math.sin(a) * 75)
		return CFrame.lookAt(position, Vector3.new(-275, 8, 0))
	end,
}

local function setControls(enabled: boolean)
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript)
		local controls = module:GetControls()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end)
end

function MenuController.Init(UIController)
	local camera = workspace.CurrentCamera
	setControls(false)

	local gui = make("ScreenGui", {
		Name = "MenuInicial",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Faixas de cinema
	for _, top in { true, false } do
		make("Frame", {
			AnchorPoint = Vector2.new(0, top and 0 or 1),
			Position = UDim2.fromScale(0, top and 0 or 1),
			Size = UDim2.new(1, 0, 0.07, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	local side = make("Frame", {
		Size = UDim2.fromScale(0.55, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = gui,
	})
	make("UIGradient", { Transparency = NumberSequence.new(0.15, 1), Parent = side })

	local content = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0.06, 0, 0.5, 0),
		Size = UDim2.fromOffset(520, 520),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	make("UIScale", { Parent = content })

	local icon = Theme.swordIcon(content, 70)
	icon.Position = UDim2.fromOffset(0, 10)
	local title = label({
		Position = UDim2.fromOffset(78, 0),
		Size = UDim2.fromOffset(440, 96),
		Text = "LÂMINAS",
		Font = F.Title,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 170)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 195, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 115, 20)),
		}),
		Rotation = 90,
		Parent = title,
	})
	make("UIStroke", { Thickness = 4, Color = Color3.fromRGB(60, 25, 0), Parent = title })
	local subtitle = label({
		Position = UDim2.fromOffset(84, 88),
		Size = UDim2.fromOffset(300, 46),
		Text = "DO REINO",
		Font = F.Title,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})
	make("UIStroke", { Thickness = 3, Color = Color3.fromRGB(60, 25, 0), Parent = subtitle })
	label({
		Position = UDim2.fromOffset(4, 150),
		Size = UDim2.fromOffset(480, 44),
		Text = "Forje sua lenda. Enfrente monstros, dragões e outros guerreiros.",
		Font = F.Text,
		TextColor3 = C.SubText,
		TextWrapped = true,
		TextScaled = false,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = content,
	})

	local play = Theme.button({
		Position = UDim2.fromOffset(0, 220),
		Size = UDim2.fromOffset(300, 68),
		Text = "JOGAR",
		MaxText = 40,
		Parent = content,
	}, Color3.fromRGB(245, 175, 40))
	local shop = Theme.button({
		Position = UDim2.fromOffset(0, 302),
		Size = UDim2.fromOffset(300, 50),
		Text = "LOJA",
		Parent = content,
	}, Color3.fromRGB(190, 70, 60))
	local help = Theme.button({
		Position = UDim2.fromOffset(0, 364),
		Size = UDim2.fromOffset(300, 50),
		Text = "COMO JOGAR",
		Parent = content,
	}, Color3.fromRGB(70, 115, 205))

	local fade = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		ZIndex = 50,
		Parent = gui,
	})
	tween(fade, 1.2, { BackgroundTransparency = 1 })

	-- Entrada animada
	for i, button in { play, shop, help } do
		local scale = button:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 0
		task.delay(0.5 + i * 0.12, function()
			tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end

	-- Câmera de cinema
	camera.CameraType = Enum.CameraType.Scriptable
	local shotIndex = 1
	local shotStart = os.clock()
	local switching = false
	RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - shotStart
		if t > SHOT_TIME and not switching then
			switching = true
			tween(fade, 0.45, { BackgroundTransparency = 0 })
			task.delay(0.5, function()
				shotIndex = shotIndex % #shots + 1
				shotStart = os.clock()
				switching = false
				tween(fade, 0.6, { BackgroundTransparency = 1 })
			end)
		end
		local cframe = shots[shotIndex](t)
		if not cframe then
			shotIndex = shotIndex % #shots + 1
			shotStart = os.clock()
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cframe
	end)

	local started = false
	local function startGame(after: (() -> ())?)
		if started then
			return
		end
		started = true
		tween(fade, 0.5, { BackgroundTransparency = 0 })
		task.wait(0.55)
		RunService:UnbindFromRenderStep("MenuCamera")
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		setControls(true)
		UIController.SetVisible(true)
		for _, child in gui:GetChildren() do
			if child ~= fade then
				child:Destroy()
			end
		end
		tween(fade, 0.8, { BackgroundTransparency = 1 })
		task.delay(0.9, function()
			gui:Destroy()
		end)
		UIController.Notify({
			Text = "BEM-VINDO, " .. string.upper(player.DisplayName) .. "!",
			Sub = "Aperte H para ver os controles. Boa sorte, guerreiro!",
			Color = C.Gold,
		})
		if after then
			after()
		end
	end

	play.MouseButton1Click:Connect(function()
		startGame()
	end)
	shop.MouseButton1Click:Connect(function()
		startGame(function()
			UIController.ToggleShop(true)
		end)
	end)
	help.MouseButton1Click:Connect(function()
		startGame(function()
			UIController.ToggleHelp(true)
		end)
	end)
end

return MenuController
