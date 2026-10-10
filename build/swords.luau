--[[
	Construção dos modelos 3D das espadas (Tools).
	Cada espada é montada com peças (cabo, guarda, lâmina, ponta, pomo)
	soldadas no Handle. O visual vem de Config.Swords[i].Look.
]]

local lib = require("./lib")

local Instance, Vector3, CFrame, Enum = lib.Instance, lib.Vector3, lib.CFrame, lib.Enum

local swords = {}

local function darker(rgb, amount)
	return { math.floor(rgb[1] * amount), math.floor(rgb[2] * amount), math.floor(rgb[3] * amount) }
end

local function lighter(rgb, amount)
	return {
		math.floor(rgb[1] + (255 - rgb[1]) * amount),
		math.floor(rgb[2] + (255 - rgb[2]) * amount),
		math.floor(rgb[3] + (255 - rgb[3]) * amount),
	}
end

-- Cria a Tool da espada. scale = tamanho (1 = normal, usado maior nos NPCs/estátuas)
function swords.build(sword, scale: number?)
	local s = scale or 1
	local look = sword.Look
	local style = look.Style
	local L = look.BladeLength * s
	local W = look.BladeWidth * s
	local thick = (style == "greatsword" and 0.2 or 0.14) * s
	local handleLen = (style == "greatsword" and 1.6 or style == "katana" and 1.4 or 1.1) * s

	local tool = Instance.new("Tool")
	tool.Name = sword.Name
	tool.ToolTip = sword.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -0.2 * s, 0)
	tool:SetAttribute("SwordId", sword.Id)

	local parts = {}
	local function add(props)
		props.Anchored = false
		props.CanCollide = false
		props.CanTouch = false
		props.CanQuery = false
		props.Massless = true
		props.CastShadow = true
		local part = lib.part(tool, props)
		table.insert(parts, part)
		return part
	end

	local metalGuard = look.BladeMaterial == "Wood" and "Wood" or "Metal"
	local gripMaterial = look.BladeMaterial == "Wood" and "Wood" or "Fabric"

	-- Cabo (Handle)
	local handle = add({
		Name = "Handle",
		Size = Vector3.new(0.32 * s, handleLen, 0.32 * s),
		CFrame = CFrame.new(),
		Color = look.HandleColor,
		Material = gripMaterial,
	})
	handle.CanQuery = false

	-- Faixas do cabo
	for _, y in { -handleLen * 0.25, handleLen * 0.25 } do
		add({
			Name = "Wrap",
			Size = Vector3.new(0.36 * s, 0.08 * s, 0.36 * s),
			CFrame = CFrame.new(0, y, 0),
			Color = darker(look.HandleColor, 0.6),
			Material = gripMaterial,
		})
	end

	-- Pomo
	add({
		Name = "Pommel",
		Shape = "Ball",
		Size = Vector3.new(0.48, 0.48, 0.48) * s,
		CFrame = CFrame.new(0, -handleLen / 2 - 0.14 * s, 0),
		Color = look.PommelColor,
		Material = look.Glow and "Neon" or metalGuard,
	})

	-- Guarda
	local guardTop
	if style == "katana" then
		local guardThick = 0.16 * s
		add({
			Name = "Guard",
			Shape = "Cylinder",
			Size = Vector3.new(guardThick, 0.85 * s, 0.85 * s),
			CFrame = CFrame.new(0, handleLen / 2 + guardThick / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = look.GuardColor,
			Material = "Metal",
		})
		guardTop = handleLen / 2 + guardThick
	else
		local guardWidth = W * (style == "greatsword" and 3.2 or style == "broad" and 3.2 or 3)
		local guardThick = 0.26 * s
		local guardY = handleLen / 2 + guardThick / 2
		add({
			Name = "Guard",
			Size = Vector3.new(guardWidth, guardThick, 0.42 * s),
			CFrame = CFrame.new(0, guardY, 0),
			Color = look.GuardColor,
			Material = metalGuard,
		})
		if style == "broad" or style == "greatsword" then
			for _, side in { -1, 1 } do
				if style == "greatsword" then
					-- Espinhos curvados para cima
					add({
						Name = "GuardSpike",
						Size = Vector3.new(0.9 * s, 0.22 * s, 0.3 * s),
						CFrame = CFrame.new(side * (guardWidth / 2 + 0.25 * s), guardY + 0.25 * s, 0)
							* CFrame.Angles(0, 0, math.rad(side * 40)),
						Color = look.GuardColor,
						Material = "Metal",
					})
				else
					add({
						Name = "GuardTip",
						Shape = "Ball",
						Size = Vector3.new(0.36, 0.36, 0.36) * s,
						CFrame = CFrame.new(side * guardWidth / 2, guardY, 0),
						Color = look.PommelColor,
						Material = look.Glow and "Neon" or "Metal",
					})
				end
			end
		end
		if look.Glow then
			add({
				Name = "Gem",
				Shape = "Ball",
				Size = Vector3.new(0.3, 0.3, 0.3) * s,
				CFrame = CFrame.new(0, guardY, -0.2 * s),
				Color = look.PommelColor,
				Material = "Neon",
			})
		end
		guardTop = handleLen / 2 + guardThick
	end

	-- Lâmina
	local bladeCenter = guardTop + L / 2
	local blade = add({
		Name = "Blade",
		Size = Vector3.new(W, L, thick),
		CFrame = CFrame.new(0, bladeCenter, 0),
		Color = look.BladeColor,
		Material = look.BladeMaterial,
		Reflectance = look.BladeMaterial == "Metal" and 0.25 or 0,
		Transparency = look.BladeMaterial == "Ice" and 0.1 or 0,
	})

	-- Detalhe no meio da lâmina (sulco ou núcleo brilhante)
	if look.BladeMaterial == "Neon" then
		add({
			Name = "Core",
			Size = Vector3.new(W * 0.3, L * 0.85, thick + 0.02 * s),
			CFrame = CFrame.new(0, guardTop + L * 0.45, 0),
			Color = lighter(look.BladeColor, 0.55),
			Material = "Neon",
		})
	elseif look.BladeMaterial ~= "Wood" then
		add({
			Name = "Fuller",
			Size = Vector3.new(W * 0.22, L * 0.72, thick + 0.02 * s),
			CFrame = CFrame.new(0, guardTop + L * 0.4, 0),
			Color = darker(look.BladeColor, 0.75),
			Material = look.BladeMaterial,
		})
	end

	-- Ponta (losango girado 45°)
	local tipSize = W * 0.7072
	add({
		Name = "Tip",
		Size = Vector3.new(tipSize, tipSize, thick),
		CFrame = CFrame.new(0, guardTop + L, 0) * CFrame.Angles(0, 0, math.rad(45)),
		Color = look.BladeColor,
		Material = look.BladeMaterial,
		Reflectance = look.BladeMaterial == "Metal" and 0.25 or 0,
	})

	-- Solda tudo no Handle
	for _, part in parts do
		if part ~= handle then
			lib.weld(handle, part)
		end
	end

	-- Rastro do golpe
	local a0 = lib.new("Attachment", { Name = "TrailBottom", Position = Vector3.new(0, -L / 2 + 0.3 * s, 0) }, blade)
	local a1 = lib.new("Attachment", { Name = "TrailTop", Position = Vector3.new(0, L / 2 + W * 0.5, 0) }, blade)
	local trail = Instance.new("Trail")
	trail.Name = "SwordTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Enabled = false
	trail.Lifetime = 0.18
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = look.Glow and 0.8 or 0.3
	trail.Color = lib.ColorSequence.new(lib.rgb(look.TrailColor))
	trail.Transparency = lib.NumberSequence.new(0.25, 1)
	trail.Parent = handle

	-- Brilho / efeitos
	if look.Glow then
		lib.light(blade, { Color = lib.rgb(look.Glow), Range = 8 * s, Brightness = 1.2 })
	end
	if look.Effect == "fire" then
		local fire = Instance.new("Fire")
		fire.Size = 2 * s
		fire.Heat = 4
		fire.Color = lib.rgb(255, 110, 30)
		fire.SecondaryColor = lib.rgb(255, 220, 80)
		fire.Parent = blade
	elseif look.Effect == "holy" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = lib.rgb(255, 230, 120)
		sparkles.Parent = blade
	elseif look.Effect then
		local colors = {
			ice = { 170, 230, 255 },
			shadow = { 150, 60, 230 },
			void = { 230, 30, 50 },
		}
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Aura"
		emitter.Color = lib.ColorSequence.new(lib.rgb(colors[look.Effect] or { 255, 255, 255 }))
		emitter.LightEmission = look.Effect == "shadow" and 0.3 or 0.7
		emitter.Size = lib.NumberSequence.new(0.25 * s, 0)
		emitter.Transparency = lib.NumberSequence.new(0.2, 1)
		emitter.Lifetime = lib.NumberRange.new(0.4, 0.8)
		emitter.Rate = look.Effect == "void" and 14 or 8
		emitter.Speed = lib.NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = lib.Vector2.new(180, 180)
		emitter.Parent = blade
	end

	-- Sons (sons padrão do Roblox)
	local sounds = {
		Slash = "rbxasset://sounds/swordslash.wav",
		Lunge = "rbxasset://sounds/swordlunge.wav",
		Unsheath = "rbxasset://sounds/unsheath.wav",
	}
	for name, id in sounds do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Volume = name == "Unsheath" and 0.4 or 0.6
		sound.RollOffMaxDistance = 100
		sound.Parent = handle
	end

	return tool
end

-- Converte a Tool em um modelo ancorado (vitrines e estátuas)
function swords.display(tool, name: string, cframe)
	local model = Instance.new("Model")
	model.Name = name
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Parent = model
		end
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("Sound") or inst:IsA("Trail") or inst:IsA("Weld") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored = true
			inst.Massless = false
		end
	end
	lib.transform(model, cframe)
	return model
end

-- Coloca a espada na mão direita de um NPC R6 já montado
function swords.attachToR6(tool, character, scale: number)
	local rightArm = character:FindFirstChild("Right Arm")
	local weapon = Instance.new("Model")
	weapon.Name = "Weapon"
	local handle
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			child.Parent = weapon
			if child.Name == "Handle" then
				handle = child
			end
		end
	end
	local gripC0 = CFrame.new(0, -1 * scale, 0, 1, 0, 0, 0, 0, 1, 0, -1, 0)
	local handleCFrame = rightArm.CFrame * gripC0 * tool.Grip:Inverse()
	lib.transform(weapon, handleCFrame)

	local grip = Instance.new("Weld")
	grip.Name = "RightGrip"
	grip.Part0 = rightArm
	grip.Part1 = handle
	grip.C0 = gripC0
	grip.C1 = tool.Grip
	grip.Parent = rightArm

	weapon.Parent = character
	return weapon
end

return swords
