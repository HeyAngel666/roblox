--[[
	Dragões: transforma o modelo feito no Blender (build/assets/dragon.json)
	em peças do Roblox. Cada triângulo da malha vira 2 WedgeParts, então o
	dragão aparece no jogo sem precisar enviar malhas para o Roblox.

	Cada parte do corpo (asas, pescoço, cauda...) fica presa numa junta
	Motor6D. O cliente (DragonController) anima essas juntas.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local lib = require("./lib")

local Instance, Vector3, CFrame = lib.Instance, lib.Vector3, lib.CFrame

local dragons = {}

dragons.Palettes = {
	red = {
		back = { 170, 30, 30 },
		belly = { 235, 180, 90 },
		wing = { 125, 22, 32 },
		wingbone = { 90, 15, 20 },
		horn = { 235, 220, 190 },
		spike = { 60, 20, 20 },
		claw = { 40, 35, 35 },
		eye = { 255, 220, 60 },
		fire = { { 255, 240, 160 }, { 255, 130, 30 }, { 200, 30, 10 } },
	},
	green = {
		back = { 40, 120, 60 },
		belly = { 200, 210, 120 },
		wing = { 30, 95, 75 },
		wingbone = { 25, 70, 45 },
		horn = { 220, 215, 180 },
		spike = { 25, 60, 35 },
		claw = { 35, 35, 30 },
		eye = { 255, 255, 120 },
		fire = { { 230, 255, 160 }, { 120, 230, 60 }, { 30, 120, 30 } },
	},
	shadow = {
		back = { 45, 35, 70 },
		belly = { 130, 70, 170 },
		wing = { 62, 26, 92 },
		wingbone = { 30, 20, 45 },
		horn = { 200, 190, 220 },
		spike = { 150, 40, 220 },
		claw = { 20, 15, 25 },
		eye = { 200, 80, 255 },
		fire = { { 240, 200, 255 }, { 170, 60, 255 }, { 60, 10, 120 } },
	},
}

local data = nil
local function loadData()
	if not data then
		data = serde.decode("json", fs.readFile("build/assets/dragon.json"))
	end
	return data
end

local function vec(t, scale)
	return Vector3.new(t[1] * scale, t[2] * scale, t[3] * scale)
end

-- Triângulo 3D com duas cunhas (técnica clássica do Roblox)
local function triangle(a, b, c, thickness)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-5 or bc.Magnitude < 1e-4 then
		return nil
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	if height < 0.01 then
		return nil
	end
	local result = {}
	local d1 = math.abs(ab:Dot(back))
	local d2 = math.abs(ac:Dot(back))
	if d1 > 0.005 then
		table.insert(result, {
			CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back),
			Size = Vector3.new(thickness, height, d1),
		})
	end
	if d2 > 0.005 then
		table.insert(result, {
			CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back),
			Size = Vector3.new(thickness, height, d2),
		})
	end
	return result
end

local function shade(rgb, factor)
	return lib.rgb(
		math.clamp(math.floor(rgb[1] * factor), 0, 255),
		math.clamp(math.floor(rgb[2] * factor), 0, 255),
		math.clamp(math.floor(rgb[3] * factor), 0, 255)
	)
end

local PIECE_NAMES = {
	Body = "Corpo",
	Neck1 = "Pescoco1",
	Neck2 = "Pescoco2",
	Neck3 = "Pescoco3",
	Head = "Cabeca",
	Jaw = "Mandibula",
	Tail1 = "Cauda1",
	Tail2 = "Cauda2",
	Tail3 = "Cauda3",
	Tail4 = "Cauda4",
	Tail5 = "Cauda5",
	WingL1 = "AsaEsquerda1",
	WingL2 = "AsaEsquerda2",
	WingR1 = "AsaDireita1",
	WingR2 = "AsaDireita2",
}

--[[
	def = {
		Name, Palette (nome), Scale,
		Center (Vector3), Radius, Altitude, Speed, Phase, Direction (1/-1), FlapSpeed
	}
]]
function dragons.build(def)
	local mesh = loadData()
	local palette = dragons.Palettes[def.Palette]
	local s = def.Scale
	local thickness = 0.06 * s

	local model = Instance.new("Model")
	model.Name = def.Name

	local root = lib.part(model, {
		Name = "Root",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Anchored = true,
	})

	local joints = {}
	local pending = {}
	for name in mesh.pieces do
		table.insert(pending, name)
	end
	table.sort(pending)

	local seed = 7
	local function random()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end

	local count = 0
	while #pending > 0 do
		for index = #pending, 1, -1 do
			local name = pending[index]
			local info = mesh.pieces[name]
			local parentPart = info.parent and joints[info.parent] or root
			if info.parent == nil or joints[info.parent] then
				table.remove(pending, index)
				local folder = lib.model(model, PIECE_NAMES[name] or name)
				local joint = lib.part(folder, {
					Name = "Junta",
					Size = Vector3.new(0.4, 0.4, 0.4),
					CFrame = CFrame.new(vec(info.pivot, s)),
					Transparency = 1,
					CanCollide = false,
					CanQuery = false,
					CanTouch = false,
					Massless = true,
					Anchored = false,
				})
				joints[name] = joint

				local motor = Instance.new("Motor6D")
				motor.Name = name
				motor.Part0 = parentPart
				motor.Part1 = joint
				motor.C0 = parentPart.CFrame:Inverse() * joint.CFrame
				motor.Parent = parentPart

				for _, tri in info.tris do
					local a, b, c = vec(tri.v[1], s), vec(tri.v[2], s), vec(tri.v[3], s)
					local wedges = triangle(a, b, c, thickness)
					if wedges then
						local color = shade(palette[tri.c], 0.93 + random() * 0.14)
						for _, w in wedges do
							local wedge = lib.part(folder, {
								Class = "WedgePart",
								Name = "Tri",
								Size = w.Size,
								CFrame = w.CFrame,
								Color = color,
								Material = "SmoothPlastic",
								CanCollide = false,
								CanQuery = false,
								CanTouch = false,
								Massless = true,
								Anchored = false,
							})
							local weld = Instance.new("Weld")
							weld.Part0 = joint
							weld.Part1 = wedge
							weld.C0 = joint.CFrame:Inverse() * wedge.CFrame
							weld.Parent = wedge
							count += 1
						end
					end
				end
			end
		end
	end

	-- Olhos brilhantes
	local head = joints.Head
	for _, eye in mesh.eyes do
		local part = lib.part(head.Parent, {
			Name = "Olho",
			Shape = "Ball",
			Size = Vector3.new(0.5, 0.5, 0.5) * s,
			CFrame = CFrame.new(vec(eye, s)),
			Color = palette.eye,
			Material = "Neon",
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Massless = true,
			Anchored = false,
		})
		lib.weld(head, part)
	end
	lib.light(head, { Color = lib.rgb(palette.eye), Range = 6 * s, Brightness = 1 })

	-- Boca: sopro de fogo (o cliente liga e desliga)
	local mouth = Instance.new("Attachment")
	mouth.Name = "Boca"
	mouth.Position = vec(mesh.mouth, s) - head.CFrame.Position
	mouth.Parent = head

	local fire = palette.fire
	local breath = Instance.new("ParticleEmitter")
	breath.Name = "SoproDeFogo"
	breath.Enabled = false
	breath.Texture = "rbxasset://textures/particles/fire_main.dds"
	breath.EmissionDirection = lib.Enum.NormalId.Front
	breath.Color = lib.ColorSequence.new({
		lib.ColorSequenceKeypoint.new(0, lib.rgb(fire[1])),
		lib.ColorSequenceKeypoint.new(0.35, lib.rgb(fire[2])),
		lib.ColorSequenceKeypoint.new(1, lib.rgb(fire[3])),
	})
	breath.LightEmission = 0.9
	breath.Size = lib.NumberSequence.new({
		lib.NumberSequenceKeypoint.new(0, 0.8 * s),
		lib.NumberSequenceKeypoint.new(0.4, 3 * s),
		lib.NumberSequenceKeypoint.new(1, 6 * s),
	})
	breath.Transparency = lib.NumberSequence.new({
		lib.NumberSequenceKeypoint.new(0, 0.1),
		lib.NumberSequenceKeypoint.new(0.7, 0.4),
		lib.NumberSequenceKeypoint.new(1, 1),
	})
	breath.Lifetime = lib.NumberRange.new(0.6, 0.9)
	breath.Speed = lib.NumberRange.new(30 * s, 42 * s)
	breath.SpreadAngle = lib.Vector2.new(10, 10)
	breath.Rate = 140
	breath.RotSpeed = lib.NumberRange.new(-90, 90)
	breath.Rotation = lib.NumberRange.new(0, 360)
	breath.Parent = mouth

	local breathLight = Instance.new("PointLight")
	breathLight.Name = "LuzDoFogo"
	breathLight.Enabled = false
	breathLight.Color = lib.rgb(fire[2])
	breathLight.Range = 30
	breathLight.Brightness = 3
	breathLight.Parent = mouth

	model.PrimaryPart = root
	model:SetAttribute("Center", def.Center)
	model:SetAttribute("Radius", def.Radius)
	model:SetAttribute("Altitude", def.Altitude)
	model:SetAttribute("Speed", def.Speed)
	model:SetAttribute("Phase", def.Phase)
	model:SetAttribute("Direction", def.Direction)
	model:SetAttribute("FlapSpeed", def.FlapSpeed or 2.4)
	model:SetAttribute("Scale", s)
	model:AddTag("Dragon")

	-- Posição inicial (a mesma que o cliente calcula no tempo 0)
	local angle = def.Phase
	local position = def.Center
		+ Vector3.new(math.cos(angle) * def.Radius, def.Altitude, math.sin(angle) * def.Radius)
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * def.Direction
	lib.transform(model, CFrame.lookAt(position, position + tangent))

	return model, count
end

return dragons
