--[[
	Construção dos personagens R6 (inimigos, chefe, bonecos de treino, ferreiro).
	Cada um é montado peça por peça com juntas Motor6D padrão do R6,
	então funcionam com as animações padrão do Roblox.
]]

local lib = require("./lib")

local Instance, Vector3, CFrame = lib.Instance, lib.Vector3, lib.CFrame

local characters = {}

-- Juntas padrão do R6 (C0/C1) — posições multiplicadas pela escala
local function joint(name: string, part0, part1, c0, c1, scale: number)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = CFrame.new(c0[1] * scale, c0[2] * scale, c0[3] * scale, table.unpack(c0, 4))
	motor.C1 = CFrame.new(c1[1] * scale, c1[2] * scale, c1[3] * scale, table.unpack(c1, 4))
	motor.MaxVelocity = 0.1
	motor.Parent = part0
	return motor
end

--[[
	opts = {
		Name, Scale,
		Colors = { Head, Torso, Arms, Legs } ({r,g,b}),
		Face = true/false,
		Anchored = false,
		MaxHealth = 100,
	}
	Retorna model, parts (tabela com Head, Torso, ...)
]]
function characters.buildR6(opts)
	local s = opts.Scale or 1
	local colors = opts.Colors
	local model = Instance.new("Model")
	model.Name = opts.Name

	local function bodyPart(name, size, position, color, collide)
		return lib.part(model, {
			Name = name,
			Size = size * s,
			CFrame = CFrame.new(position * s),
			Color = color,
			Material = opts.Material or "SmoothPlastic",
			Anchored = false,
			CanCollide = collide,
		})
	end

	local root = bodyPart("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), colors.Torso, false)
	root.Transparency = 1
	root.Anchored = opts.Anchored == true
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), colors.Torso, true)
	local head = bodyPart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0), colors.Head, true)
	local leftArm = bodyPart("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), colors.LeftArm or colors.Arms, false)
	local rightArm = bodyPart("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), colors.RightArm or colors.Arms, false)
	local leftLeg = bodyPart("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), colors.Legs, false)
	local rightLeg = bodyPart("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), colors.Legs, false)

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = lib.Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head

	if opts.Face ~= false then
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Face = lib.Enum.NormalId.Front
		face.Parent = head
	end

	joint("RootJoint", root, torso, { 0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0 }, { 0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0 }, s)
	joint("Neck", torso, head, { 0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0 }, { 0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0 }, s)
	joint("Right Shoulder", torso, rightArm, { 1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }, { -0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }, s)
	joint("Left Shoulder", torso, leftArm, { -1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 }, { 0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 }, s)
	joint("Right Hip", torso, rightLeg, { 1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }, { 0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0 }, s)
	joint("Left Hip", torso, leftLeg, { -1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 }, { -0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0 }, s)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = lib.Enum.HumanoidRigType.R6
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 7.2
	humanoid.MaxHealth = opts.MaxHealth or 100
	humanoid.Health = opts.MaxHealth or 100
	humanoid.BreakJointsOnDeath = opts.BreakJoints ~= false
	if opts.ShowName then
		humanoid.DisplayName = opts.ShowName
		humanoid.NameDisplayDistance = 40
		humanoid.HealthDisplayType = lib.Enum.HumanoidHealthDisplayType.AlwaysOff
	else
		humanoid.DisplayDistanceType = lib.Enum.HumanoidDisplayDistanceType.None
	end
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid

	model.PrimaryPart = root
	model:SetAttribute("SpawnHeight", 3 * s)
	model:SetAttribute("Scale", s)

	local parts = {
		Root = root,
		Torso = torso,
		Head = head,
		LeftArm = leftArm,
		RightArm = rightArm,
		LeftLeg = leftLeg,
		RightLeg = rightLeg,
	}
	return model, parts
end

-- Adiciona um enfeite soldado numa parte do corpo.
-- offset é relativo ao centro da parte (em studs já escalados pelo chamador)
function characters.decorate(model, bodyPart, props, offset)
	props.Anchored = false
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.Massless = true
	props.CFrame = bodyPart.CFrame * offset
	local part = lib.part(model, props)
	lib.weld(bodyPart, part)
	return part
end

--------------------------------------------------------------------------
-- Inimigos
--------------------------------------------------------------------------
function characters.goblin()
	local s = 0.85
	local model, p = characters.buildR6({
		Name = "Goblin",
		Scale = s,
		Colors = {
			Head = { 110, 160, 60 },
			Torso = { 110, 80, 45 },
			Arms = { 110, 160, 60 },
			Legs = { 70, 55, 40 },
		},
	})
	local d = characters.decorate
	-- Orelhas pontudas
	for _, side in { -1, 1 } do
		d(model, p.Head, {
			Name = "Ear",
			Size = Vector3.new(0.9, 0.3, 0.2) * s,
			Color = { 110, 160, 60 },
			Material = "SmoothPlastic",
		}, CFrame.new(side * 0.85 * s, 0.15 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 25)))
	end
	-- Nariz grande
	d(model, p.Head, {
		Name = "Nose",
		Size = Vector3.new(0.25, 0.25, 0.4) * s,
		Color = { 95, 140, 50 },
		Material = "SmoothPlastic",
	}, CFrame.new(0, -0.05 * s, -0.6 * s))
	-- Cinto e tanga
	d(model, p.Torso, {
		Name = "Belt",
		Size = Vector3.new(2.05, 0.3, 1.05) * s,
		Color = { 60, 40, 25 },
		Material = "Fabric",
	}, CFrame.new(0, -0.8 * s, 0))
	return model
end

function characters.skeleton()
	local s = 1
	local bone = { 225, 220, 200 }
	local model, p = characters.buildR6({
		Name = "Esqueleto",
		Scale = s,
		Face = false,
		Colors = { Head = bone, Torso = { 60, 55, 50 }, Arms = bone, Legs = bone },
	})
	local d = characters.decorate
	-- Olhos (buracos com brilho)
	for _, side in { -1, 1 } do
		d(model, p.Head, {
			Name = "Eye",
			Size = Vector3.new(0.25, 0.25, 0.1),
			Color = { 120, 220, 255 },
			Material = "Neon",
		}, CFrame.new(side * 0.25, 0.1, -0.6))
	end
	d(model, p.Head, {
		Name = "Mouth",
		Size = Vector3.new(0.6, 0.08, 0.1),
		Color = { 20, 20, 20 },
		Material = "SmoothPlastic",
	}, CFrame.new(0, -0.25, -0.6))
	-- Costelas
	for i = 0, 3 do
		d(model, p.Torso, {
			Name = "Rib",
			Size = Vector3.new(1.7, 0.18, 1.05),
			Color = bone,
			Material = "SmoothPlastic",
		}, CFrame.new(0, 0.65 - i * 0.4, 0))
	end
	-- Elmo enferrujado
	d(model, p.Head, {
		Name = "Helmet",
		Size = Vector3.new(1.35, 0.45, 1.35),
		Color = { 110, 90, 70 },
		Material = "CorrodedMetal",
	}, CFrame.new(0, 0.5, 0))
	return model
end

function characters.orc()
	local s = 1.3
	local skin = { 85, 120, 70 }
	local model, p = characters.buildR6({
		Name = "Orc",
		Scale = s,
		Colors = { Head = skin, Torso = { 90, 60, 40 }, Arms = skin, Legs = { 55, 45, 40 } },
	})
	local d = characters.decorate
	-- Presas
	for _, side in { -1, 1 } do
		d(model, p.Head, {
			Name = "Tusk",
			Size = Vector3.new(0.15, 0.35, 0.15) * s,
			Color = { 240, 235, 210 },
			Material = "SmoothPlastic",
		}, CFrame.new(side * 0.3 * s, -0.25 * s, -0.6 * s))
	end
	-- Ombreiras de metal
	for _, arm in { p.LeftArm, p.RightArm } do
		d(model, arm, {
			Name = "Pauldron",
			Size = Vector3.new(1.3, 0.6, 1.3) * s,
			Color = { 80, 80, 90 },
			Material = "Metal",
		}, CFrame.new(0, 0.85 * s, 0))
	end
	-- Elmo com chifres
	d(model, p.Head, {
		Name = "Helmet",
		Size = Vector3.new(1.35, 0.5, 1.35) * s,
		Color = { 70, 70, 80 },
		Material = "Metal",
	}, CFrame.new(0, 0.45 * s, 0))
	for _, side in { -1, 1 } do
		d(model, p.Head, {
			Name = "Horn",
			Size = Vector3.new(0.9, 0.25, 0.25) * s,
			Color = { 230, 220, 190 },
			Material = "SmoothPlastic",
		}, CFrame.new(side * 0.85 * s, 0.7 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 40)))
	end
	-- Cinto
	d(model, p.Torso, {
		Name = "Belt",
		Size = Vector3.new(2.05, 0.35, 1.05) * s,
		Color = { 50, 35, 25 },
		Material = "Fabric",
	}, CFrame.new(0, -0.75 * s, 0))
	return model
end

function characters.fallenKing()
	local s = 2.2
	local armor = { 45, 40, 50 }
	local model, p = characters.buildR6({
		Name = "ReiCaido",
		Scale = s,
		Face = false,
		Material = "Metal",
		Colors = { Head = { 30, 25, 35 }, Torso = armor, Arms = armor, Legs = { 35, 30, 40 } },
	})
	local d = characters.decorate
	-- Olhos vermelhos
	for _, side in { -1, 1 } do
		d(model, p.Head, {
			Name = "Eye",
			Size = Vector3.new(0.28, 0.12, 0.1) * s,
			Color = { 255, 30, 40 },
			Material = "Neon",
		}, CFrame.new(side * 0.25 * s, 0.05 * s, -0.62 * s))
	end
	-- Coroa
	d(model, p.Head, {
		Name = "CrownBase",
		Size = Vector3.new(1.4, 0.3, 1.4) * s,
		Color = { 200, 160, 40 },
		Material = "Metal",
	}, CFrame.new(0, 0.62 * s, 0))
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		d(model, p.Head, {
			Name = "CrownSpike",
			Size = Vector3.new(0.25, 0.5, 0.25) * s,
			Color = { 200, 160, 40 },
			Material = "Metal",
		}, CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.95 * s, -0.55 * s))
	end
	d(model, p.Head, {
		Name = "CrownGem",
		Shape = "Ball",
		Size = Vector3.new(0.3, 0.3, 0.3) * s,
		Color = { 255, 30, 50 },
		Material = "Neon",
	}, CFrame.new(0, 0.65 * s, -0.72 * s))
	-- Ombreiras com espinhos
	for _, arm in { p.LeftArm, p.RightArm } do
		d(model, arm, {
			Name = "Pauldron",
			Size = Vector3.new(1.4, 0.7, 1.4) * s,
			Color = { 25, 20, 30 },
			Material = "Metal",
		}, CFrame.new(0, 0.85 * s, 0))
		d(model, arm, {
			Name = "Spike",
			Size = Vector3.new(0.25, 0.8, 0.25) * s,
			Color = { 160, 20, 30 },
			Material = "Neon",
		}, CFrame.new(0, 1.4 * s, 0))
	end
	-- Peitoral com runa
	d(model, p.Torso, {
		Name = "Rune",
		Size = Vector3.new(0.5, 0.9, 0.1) * s,
		Color = { 230, 30, 50 },
		Material = "Neon",
	}, CFrame.new(0, 0.1 * s, -0.53 * s))
	-- Capa
	d(model, p.Torso, {
		Name = "Cape",
		Size = Vector3.new(2.2, 3.4, 0.12) * s,
		Color = { 120, 15, 25 },
		Material = "Fabric",
	}, CFrame.new(0, -0.6 * s, 0.6 * s) * CFrame.Angles(math.rad(8), 0, 0))
	return model
end

--------------------------------------------------------------------------
-- Vila
--------------------------------------------------------------------------
function characters.dummy()
	local wood = { 160, 120, 75 }
	local model, p = characters.buildR6({
		Name = "Boneco de Treino",
		Scale = 1,
		Face = false,
		Anchored = true,
		MaxHealth = 2000,
		BreakJoints = false,
		Material = "Wood",
		Colors = { Head = { 200, 180, 140 }, Torso = wood, Arms = wood, Legs = wood },
	})
	p.Head.Material = lib.Enum.Material.Fabric
	local d = characters.decorate
	-- Alvo no peito
	local rings = { { 1.5, { 230, 230, 230 } }, { 1.05, { 210, 40, 40 } }, { 0.6, { 230, 230, 230 } }, { 0.25, { 210, 40, 40 } } }
	for i, ring in rings do
		d(model, p.Torso, {
			Name = "Target",
			Shape = "Cylinder",
			Size = Vector3.new(0.05, ring[1], ring[1]),
			Color = ring[2],
			Material = "SmoothPlastic",
		}, CFrame.new(0, 0.1, -0.52 - i * 0.012) * CFrame.Angles(0, math.rad(90), 0))
	end
	-- Poste
	d(model, p.Torso, {
		Name = "Post",
		Size = Vector3.new(0.5, 3, 0.5),
		Color = { 100, 70, 40 },
		Material = "Wood",
	}, CFrame.new(0, -2.5, 0.9))
	model:SetAttribute("Dummy", true)
	model:AddTag("Dummy")
	return model
end

function characters.blacksmith()
	local model, p = characters.buildR6({
		Name = "Ferreiro",
		Scale = 1,
		Anchored = true,
		MaxHealth = 100,
		ShowName = "Ferreiro",
		Colors = {
			Head = { 234, 184, 146 },
			Torso = { 150, 100, 60 },
			Arms = { 234, 184, 146 },
			Legs = { 60, 50, 45 },
		},
	})
	local d = characters.decorate
	d(model, p.Torso, {
		Name = "Apron",
		Size = Vector3.new(1.8, 2.4, 0.1),
		Color = { 70, 45, 30 },
		Material = "Fabric",
	}, CFrame.new(0, -0.3, -0.55))
	d(model, p.Head, {
		Name = "Beard",
		Size = Vector3.new(1, 0.6, 0.3),
		Color = { 90, 50, 30 },
		Material = "Fabric",
	}, CFrame.new(0, -0.45, -0.5))
	d(model, p.Head, {
		Name = "Bandana",
		Size = Vector3.new(1.3, 0.3, 1.3),
		Color = { 180, 40, 40 },
		Material = "Fabric",
	}, CFrame.new(0, 0.5, 0))
	model:SetAttribute("Invulnerable", true)
	return model
end

return characters
