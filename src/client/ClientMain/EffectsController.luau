--[[
	EffectsController
	Efeitos visuais criados só no cliente (mais suaves e sem custo de rede):
	faíscas de acerto, números de dano, anéis de habilidade, raios,
	aviso de ataque do chefe, subida de nível...
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local EffectsController = {}

local fxFolder: Folder

local SLASH_SOUND = "rbxasset://sounds/swordslash.wav"
local LUNGE_SOUND = "rbxasset://sounds/swordlunge.wav"

local function tween(instance: Instance, seconds: number, properties, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, properties)
	t:Play()
	return t
end

local function makePart(properties): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in properties do
		(part :: any)[key] = value
	end
	part.Parent = fxFolder
	return part
end

local function playSound(position: Vector3, soundId: string, volume: number, speed: number)
	local holder = makePart({ Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(position) })
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = speed
	sound.RollOffMaxDistance = 120
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 2)
end

local function burst(position: Vector3, color: Color3, count: number, speed: number, size: number)
	local holder = makePart({ Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(position) })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.25, 0.5)
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 1.5)
end

local function floatingText(position: Vector3, text: string, color: Color3, big: boolean)
	local anchor = makePart({
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = CFrame.new(position + Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)),
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(big and 220 or 160, big and 60 or 44)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(gui, 0.9, { StudsOffset = Vector3.new(0, 3, 0) })
	task.delay(0.45, function()
		tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, 1)
end

local function shakeCamera(intensity: number, duration: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < duration do
			local fade = 1 - (os.clock() - start) / duration
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * intensity * fade,
				(math.random() - 0.5) * intensity * fade,
				0
			)
			task.wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

--------------------------------------------------------------------------
-- Tipos de efeito
--------------------------------------------------------------------------
local handlers = {}

function handlers.Hit(data)
	local color: Color3 = data.Color or Color3.new(1, 1, 1)
	local size = data.Crit and 4.5 or 3
	local sphere = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.5,
		Color = data.Crit and Color3.fromRGB(255, 230, 90) or color,
		Transparency = 0.1,
		CFrame = CFrame.new(data.Position),
	})
	tween(sphere, 0.25, { Size = Vector3.one * size, Transparency = 1 })
	Debris:AddItem(sphere, 0.3)
	burst(data.Position, color, data.Crit and 22 or 12, 28, 0.35)
	playSound(data.Position, SLASH_SOUND, 0.35, 1.3 + math.random() * 0.3)
end

function handlers.Damage(data)
	local text = tostring(data.Amount)
	local color = Color3.fromRGB(255, 255, 255)
	if data.Crit then
		text = "CRÍTICO! " .. text
		color = Color3.fromRGB(255, 220, 60)
	elseif data.Color and data.Color ~= Color3.new(1, 1, 1) then
		color = data.Color
	end
	floatingText(data.Position, text, color, data.Crit == true)
	shakeCamera(data.Crit and 0.5 or 0.25, 0.12)
end

function handlers.Text(data)
	floatingText(data.Position + Vector3.new(0, 3, 0), data.Text, data.Color or Color3.new(1, 1, 1), true)
end

function handlers.Block(data)
	burst(data.Position, Color3.fromRGB(140, 200, 255), 10, 18, 0.3)
	playSound(data.Position, SLASH_SOUND, 0.3, 0.7)
end

function handlers.Parry(data)
	local ring = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 2, 2),
		Color = Color3.fromRGB(180, 230, 255),
		Transparency = 0,
		CFrame = CFrame.new(data.Position) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tween(ring, 0.3, { Size = Vector3.new(0.2, 12, 12), Transparency = 1 })
	Debris:AddItem(ring, 0.35)
	burst(data.Position, Color3.fromRGB(200, 240, 255), 25, 35, 0.4)
	playSound(data.Position, LUNGE_SOUND, 0.6, 1.6)
end

function handlers.Ring(data)
	local radius = data.Radius or 10
	local color: Color3 = data.Color or Color3.new(1, 1, 1)
	local flat = CFrame.new(data.Position) * CFrame.Angles(0, 0, math.rad(90))

	local ring = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		Color = color,
		Transparency = 0.15,
		CFrame = flat,
	})
	tween(ring, 0.4, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, 0.45)

	local wave = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2,
		Color = color,
		Transparency = 0.5,
		CFrame = CFrame.new(data.Position + Vector3.new(0, 2, 0)),
		Material = Enum.Material.ForceField,
	})
	tween(wave, 0.35, { Size = Vector3.one * radius * 1.6, Transparency = 1 })
	Debris:AddItem(wave, 0.4)

	burst(data.Position + Vector3.new(0, 1.5, 0), color, 40, radius * 3, 0.6)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = radius * 1.5
	light.Brightness = 4
	light.Parent = ring
	playSound(data.Position, LUNGE_SOUND, 0.6, 0.8)
end

function handlers.Telegraph(data)
	local radius = data.Radius or 10
	local duration = data.Duration or 1
	local flat = CFrame.new(data.Position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))

	local outline = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		Color = Color3.fromRGB(255, 40, 40),
		Transparency = 0.7,
		CFrame = flat,
	})
	local fill = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 0.5, 0.5),
		Color = Color3.fromRGB(255, 60, 40),
		Transparency = 0.45,
		CFrame = flat,
	})
	tween(fill, duration, { Size = Vector3.new(0.2, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(outline, duration)
	Debris:AddItem(fill, duration)
end

function handlers.Lightning(data)
	local from: Vector3, to: Vector3 = data.From, data.To
	local segments = 7
	local points = { from }
	for i = 1, segments - 1 do
		local alpha = i / segments
		local point = from:Lerp(to, alpha)
			+ Vector3.new((math.random() - 0.5) * 3, (math.random() - 0.5) * 3, (math.random() - 0.5) * 3)
		table.insert(points, point)
	end
	table.insert(points, to)

	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		local bolt = makePart({
			Size = Vector3.new(0.35, 0.35, length),
			Color = Color3.fromRGB(255, 245, 160),
			CFrame = CFrame.lookAt((a + b) / 2, b),
		})
		tween(bolt, 0.3, { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) })
		Debris:AddItem(bolt, 0.35)
	end
	burst(to, Color3.fromRGB(255, 240, 140), 15, 30, 0.4)
	playSound(to, LUNGE_SOUND, 0.4, 2)
end

function handlers.Dash(data)
	burst(data.Position - Vector3.new(0, 2, 0), Color3.fromRGB(230, 230, 230), 14, 12, 0.8)
end

function handlers.Death(data)
	burst(data.Position, Color3.fromRGB(40, 30, 50), 30, 15, 1.2)
	local soul = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.2,
		Color = Color3.fromRGB(220, 230, 255),
		Transparency = 0.3,
		CFrame = CFrame.new(data.Position),
	})
	tween(soul, 1.5, { CFrame = CFrame.new(data.Position + Vector3.new(0, 12, 0)), Transparency = 1 })
	Debris:AddItem(soul, 1.6)
end

function handlers.LevelUp(data)
	local beam = makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(60, 3, 3),
		Color = Color3.fromRGB(255, 215, 80),
		Transparency = 0.2,
		CFrame = CFrame.new(data.Position + Vector3.new(0, 27, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	tween(beam, 1.2, { Size = Vector3.new(60, 8, 8), Transparency = 1 })
	Debris:AddItem(beam, 1.3)
	handlers.Ring({
		Position = data.Position - Vector3.new(0, 2.5, 0),
		Radius = 10,
		Color = Color3.fromRGB(255, 215, 80),
	})
end

--------------------------------------------------------------------------
function EffectsController.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "ClientFX"
	fxFolder.Parent = workspace

	Remotes.Effect.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		local handler = handlers[data.Type]
		if handler then
			local ok, err = pcall(handler, data)
			if not ok then
				warn("[Effects] " .. tostring(err))
			end
		end
	end)
end

EffectsController.FloatingText = floatingText
EffectsController.Burst = burst

return EffectsController
