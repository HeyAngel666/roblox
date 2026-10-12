--[[
	Tela de carregamento (ReplicatedFirst)
	Aparece antes de tudo: logo, brasas subindo, barra de progresso e dicas.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
ReplicatedFirst:RemoveDefaultLoadingScreen()

local TIPS = {
	"Bloqueie (F) bem na hora do golpe para dar um PARRY!",
	"O 3º golpe do combo empurra o inimigo para longe.",
	"Esquive com Q: você fica invencível por um instante.",
	"Cada espada tem uma habilidade especial na tecla R.",
	"A Vila é zona segura. Lá ninguém pode te atacar.",
	"O Rei Caído pode derrubar uma espada Mítica!",
	"Derrote quem está em sequência de abates para ganhar a recompensa.",
	"Dragões sobrevoam o reino... olhe para o céu!",
}

local function tween(instance, seconds, properties, style)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), properties)
	t:Play()
	return t
end

local function new(className, properties)
	local instance = Instance.new(className)
	for key, value in properties do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	instance.Parent = properties.Parent
	return instance
end

local gui = new("ScreenGui", {
	Name = "Carregamento",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 100,
	Parent = player:WaitForChild("PlayerGui"),
})
local group = new("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = gui,
})
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 18, 40)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(18, 10, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 4, 10)),
	}),
	Rotation = 90,
	Parent = group,
})

-- Brasas subindo
local embers = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = group })
local running = true
task.spawn(function()
	while running do
		local size = math.random(3, 7)
		local ember = new("Frame", {
			Position = UDim2.new(math.random(), 0, 1.05, 0),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Color3.fromRGB(255, math.random(110, 190), 40),
			BorderSizePixel = 0,
			Parent = embers,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ember })
		local duration = math.random(30, 60) / 10
		tween(ember, duration, {
			Position = UDim2.new(ember.Position.X.Scale + (math.random() - 0.5) * 0.15, 0, -0.05, 0),
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Linear)
		task.delay(duration, function()
			ember:Destroy()
		end)
		task.wait(0.08)
	end
end)

-- Logo
local title = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.4),
	Size = UDim2.fromOffset(760, 110),
	BackgroundTransparency = 1,
	Text = "LÂMINAS DO REINO",
	Font = Enum.Font.LuckiestGuy,
	TextScaled = true,
	TextColor3 = Color3.new(1, 1, 1),
	Parent = group,
})
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 170)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 195, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(205, 115, 20)),
	}),
	Rotation = 90,
	Parent = title,
})
new("UIStroke", { Thickness = 4, Color = Color3.fromRGB(60, 25, 0), Parent = title })
local titleScale = new("UIScale", { Scale = 0.8, Parent = title })
tween(titleScale, 1.2, { Scale = 1 }, Enum.EasingStyle.Back)

-- Barra de progresso
local barBack = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.62),
	Size = UDim2.fromOffset(460, 18),
	BackgroundColor3 = Color3.fromRGB(20, 16, 26),
	Parent = group,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBack })
new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(170, 110, 35), Parent = barBack })
local fill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = barBack,
})
new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(255, 230, 130), Color3.fromRGB(230, 130, 30)),
	Parent = fill,
})
local percent = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.62, 16),
	Size = UDim2.fromOffset(300, 22),
	BackgroundTransparency = 1,
	Text = "Carregando o reino... 0%",
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(220, 210, 235),
	Parent = group,
})
local tip = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.92, 0),
	Size = UDim2.fromOffset(700, 26),
	BackgroundTransparency = 1,
	Text = "DICA: " .. TIPS[math.random(1, #TIPS)],
	Font = Enum.Font.GothamMedium,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(190, 180, 210),
	Parent = group,
})

task.spawn(function()
	while running do
		task.wait(3.5)
		tween(tip, 0.3, { TextTransparency = 1 })
		task.wait(0.3)
		tip.Text = "DICA: " .. TIPS[math.random(1, #TIPS)]
		tween(tip, 0.3, { TextTransparency = 0 })
	end
end)

local progress = 0
local function setProgress(value: number)
	progress = math.max(progress, value)
	tween(fill, 0.4, { Size = UDim2.fromScale(progress, 1) })
	percent.Text = ("Carregando o reino... %d%%"):format(math.floor(progress * 100))
end

local startTime = os.clock()
setProgress(0.1)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.55)
local character = player.Character or player.CharacterAdded:Wait()
setProgress(0.75)
character:WaitForChild("Humanoid", 10)
local scripts = player:WaitForChild("PlayerScripts")
scripts:WaitForChild("ClientMain", 10)
setProgress(0.9)
while os.clock() - startTime < 3 do
	task.wait(0.1)
end
setProgress(1)
task.wait(0.5)

running = false
tween(group, 0.8, { GroupTransparency = 1 })
task.wait(0.85)
player:SetAttribute("LoadingDone", true)
gui:Destroy()
