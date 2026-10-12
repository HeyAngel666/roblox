--[[
	Construção do mapa "Lâminas do Reino"
	  Centro (0,0)        Vila (zona segura): fonte com espada gigante,
	                       ferraria (loja), placar, área de treino
	  Norte (0,-230)      Arena PvP (coliseu)
	  Leste (265,0)       Floresta Sombria: acampamento goblin, cemitério,
	                       fortaleza orc
	  Oeste (-265,0)      Ruínas do Rei Caído (chefe)
	  Ao redor            Campos e montanhas
]]

local lib = require("./lib")
local swords = require("./swords")
local characters = require("./characters")
local Config = require("../src/shared/Config")

local Instance, Vector3, CFrame, Enum = lib.Instance, lib.Vector3, lib.CFrame, lib.Enum
local V3, CF = Vector3.new, CFrame.new
local rad = math.rad

local map = {}

math.randomseed(20261010)
local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end
local function pick(list)
	return list[math.random(1, #list)]
end

--------------------------------------------------------------------------
-- Áreas livres (para não colocar árvores em cima das construções)
--------------------------------------------------------------------------
local blocked = {} -- { {x, z, r} } círculos
local blockedRects = {} -- { {x1, z1, x2, z2} }

local function block(x, z, r)
	table.insert(blocked, { x, z, r })
end
local function blockRect(x1, z1, x2, z2)
	table.insert(blockedRects, { math.min(x1, x2), math.min(z1, z2), math.max(x1, x2), math.max(z1, z2) })
end
local function isFree(x, z, r)
	for _, c in blocked do
		local dx, dz = x - c[1], z - c[2]
		if dx * dx + dz * dz < (c[3] + r) ^ 2 then
			return false
		end
	end
	for _, rect in blockedRects do
		if x + r > rect[1] and x - r < rect[3] and z + r > rect[2] and z - r < rect[4] then
			return false
		end
	end
	return true
end

--------------------------------------------------------------------------
-- Peças decorativas reutilizáveis
--------------------------------------------------------------------------
local function tree(parent, position, style: string?, scale: number?)
	local s = scale or rand(0.85, 1.25)
	local model = lib.model(parent, "Arvore")
	local kind = style or pick({ "round", "round", "pine" })
	local trunkHeight = (kind == "pine" and 6 or 9) * s
	local trunkColor = pick({ { 105, 75, 50 }, { 95, 68, 45 }, { 115, 85, 55 } })
	lib.cylinder(model, { Name = "Tronco", Color = trunkColor, Material = "Wood" }, position + V3(0, trunkHeight / 2, 0), trunkHeight, 1.8 * s)

	if kind == "pine" then
		local greens = { { 45, 95, 55 }, { 40, 85, 50 }, { 55, 105, 60 } }
		local y = trunkHeight * 0.6
		for i, size in { 11, 8, 5 } do
			local layer = size * s
			lib.part(model, {
				Name = "Folhas",
				Size = V3(layer, 3.4 * s, layer),
				CFrame = CF(position + V3(0, y + 1.7 * s, 0)) * CFrame.Angles(0, rad(45 * i + rand(0, 20)), 0),
				Color = greens[i],
				Material = "Grass",
			})
			y += 3 * s
		end
	elseif kind == "dead" then
		for i = 1, 3 do
			local angle = rand(0, 360)
			local branch = lib.part(model, {
				Name = "Galho",
				Size = V3(0.6 * s, 4.5 * s, 0.6 * s),
				CFrame = CF(position + V3(0, trunkHeight * (0.55 + i * 0.12), 0))
					* CFrame.Angles(0, rad(angle), rad(rand(30, 55)))
					* CF(0, 2 * s, 0),
				Color = { 70, 60, 55 },
				Material = "Wood",
			})
			branch.Name = "Galho"
		end
	else
		local greens = { { 75, 140, 60 }, { 65, 125, 55 }, { 90, 150, 70 } }
		lib.part(model, {
			Name = "Folhas",
			Shape = "Ball",
			Size = V3(11, 11, 11) * s,
			CFrame = CF(position + V3(0, trunkHeight + 3 * s, 0)),
			Color = pick(greens),
			Material = "Grass",
		})
		for _ = 1, 2 do
			local size = rand(6, 8) * s
			lib.part(model, {
				Name = "Folhas",
				Shape = "Ball",
				Size = V3(size, size, size),
				CFrame = CF(position + V3(rand(-4, 4) * s, trunkHeight + rand(1, 5) * s, rand(-4, 4) * s)),
				Color = pick(greens),
				Material = "Grass",
			})
		end
	end
	return model
end

local function darkTree(parent, position)
	local s = rand(1, 1.4)
	local model = lib.model(parent, "ArvoreSombria")
	local height = 12 * s
	lib.cylinder(model, { Name = "Tronco", Color = { 70, 55, 45 }, Material = "Wood" }, position + V3(0, height / 2, 0), height, 2.2 * s)
	local greens = { { 35, 70, 45 }, { 30, 60, 40 }, { 45, 80, 50 } }
	for _ = 1, 3 do
		local size = rand(8, 12) * s
		lib.part(model, {
			Name = "Folhas",
			Shape = "Ball",
			Size = V3(size, size, size),
			CFrame = CF(position + V3(rand(-4, 4) * s, height + rand(-1, 4) * s, rand(-4, 4) * s)),
			Color = pick(greens),
			Material = "Grass",
		})
	end
	return model
end

local function rock(parent, position, size: number?)
	local s = size or rand(2, 5)
	return lib.part(parent, {
		Name = "Pedra",
		Size = V3(s * rand(1, 1.6), s * rand(0.6, 1), s * rand(1, 1.5)),
		CFrame = CF(position + V3(0, s * 0.3, 0)) * CFrame.Angles(rad(rand(-15, 15)), rad(rand(0, 360)), rad(rand(-15, 15))),
		Color = pick({ { 120, 120, 125 }, { 105, 105, 110 }, { 135, 130, 125 } }),
		Material = "Slate",
	})
end

local function lamp(parent, position)
	local model = lib.model(parent, "Poste")
	lib.cylinder(model, { Name = "Poste", Color = { 40, 40, 45 }, Material = "Metal" }, position + V3(0, 4.5, 0), 9, 0.5)
	lib.part(model, {
		Name = "Base",
		Size = V3(1.4, 0.6, 1.4),
		CFrame = CF(position + V3(0, 0.3, 0)),
		Color = { 40, 40, 45 },
		Material = "Metal",
	})
	lib.part(model, {
		Name = "Topo",
		Size = V3(1.8, 0.3, 1.8),
		CFrame = CF(position + V3(0, 10.25, 0)),
		Color = { 40, 40, 45 },
		Material = "Metal",
	})
	local lantern = lib.part(model, {
		Name = "Lanterna",
		Size = V3(1.3, 1.6, 1.3),
		CFrame = CF(position + V3(0, 9.3, 0)),
		Color = { 255, 210, 140 },
		Material = "Neon",
		Tags = { "NightLight" },
	})
	lib.light(lantern, { Color = lib.rgb(255, 200, 130), Range = 22, Brightness = 1.5 }, { "NightLight" })
	return model
end

local function torch(parent, position, fireColor)
	local model = lib.model(parent, "Tocha")
	lib.cylinder(model, { Name = "Haste", Color = { 80, 55, 35 }, Material = "Wood" }, position + V3(0, 1.5, 0), 3, 0.4)
	local bowl = lib.cylinder(model, { Name = "Cuia", Color = { 50, 50, 55 }, Material = "Metal" }, position + V3(0, 3.2, 0), 0.6, 1.2)
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 7
	if fireColor then
		fire.Color = lib.rgb(fireColor)
		fire.SecondaryColor = lib.rgb(math.floor(fireColor[1] * 0.4), math.floor(fireColor[2] * 0.4), math.floor(fireColor[3] * 0.4))
	end
	fire.Parent = bowl
	lib.light(bowl, { Color = fireColor and lib.rgb(fireColor) or lib.rgb(255, 150, 60), Range = 16, Brightness = 1.4 })
	return model
end

-- Arco de entrada com placa (yaw em graus)
local function arch(parent, position, yaw: number, text: string, color)
	local model = lib.model(parent, "Arco")
	local base = CF(position) * CFrame.Angles(0, rad(yaw), 0)
	for _, side in { -1, 1 } do
		lib.part(model, {
			Name = "Pilar",
			Size = V3(2.5, 14, 2.5),
			CFrame = base * CF(side * 9, 7, 0),
			Color = { 140, 135, 125 },
			Material = "Cobblestone",
		})
		local top = lib.part(model, {
			Name = "TopoPilar",
			Size = V3(3, 0.8, 3),
			CFrame = base * CF(side * 9, 16.9, 0),
			Color = { 120, 115, 105 },
			Material = "Cobblestone",
		})
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Parent = top
		lib.light(top, { Color = lib.rgb(255, 150, 60), Range = 18, Brightness = 1.2 })
	end
	lib.part(model, {
		Name = "Viga",
		Size = V3(21, 2.5, 2.5),
		CFrame = base * CF(0, 15.25, 0),
		Color = { 120, 115, 105 },
		Material = "Cobblestone",
	})
	local board = lib.part(model, {
		Name = "Placa",
		Size = V3(15, 2.6, 0.5),
		CFrame = base * CF(0, 12.4, 0),
		Color = { 90, 60, 35 },
		Material = "WoodPlanks",
	})
	lib.sign(board, "Front", text, color)
	lib.sign(board, "Back", text, color)
	return model
end

-- Anel de segmentos (muros circulares, arquibancadas, paliçadas)
local function ring(parent, center, radius, count, skip, build)
	local step = 360 / count
	for i = 0, count - 1 do
		local angle = i * step
		if skip and skip(angle) then
			continue
		end
		local a = rad(angle)
		local position = center + V3(math.cos(a) * radius, 0, math.sin(a) * radius)
		local facing = CF(position) * CFrame.Angles(0, math.pi / 2 - a, 0) -- -Z aponta para o centro
		build(facing, i, angle)
	end
end

local function angleNear(angle, target, tolerance)
	local diff = math.abs(((angle - target + 180) % 360) - 180)
	return diff <= tolerance
end

local function zonePart(parent, name, center, size, safe)
	lib.part(parent, {
		Name = name,
		Size = size,
		CFrame = CF(center),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Attributes = { Zone = name, Safe = safe },
	})
end

local function npcSpawn(parent, kind, position)
	lib.part(parent, {
		Name = kind .. "Spawn",
		Size = V3(2, 1, 2),
		CFrame = CF(position + V3(0, 0.5, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Attributes = { NPC = kind },
	})
	block(position.X, position.Z, 6)
end

--------------------------------------------------------------------------
-- RELEVO (o terreno de verdade é criado pelo servidor ao iniciar o jogo,
-- usando estes dados: morros, lago, montanhas e manchas de material)
--------------------------------------------------------------------------
local terrainData = {
	Hills = {},
	Mountains = {},
	Lake = { X = 120, Z = 175, Radius = 42 },
	Patches = {},
}

local function heightAt(x, z)
	local h = 0
	for _, hill in terrainData.Hills do
		local dx, dz = x - hill[1], z - hill[3]
		local d2 = dx * dx + dz * dz
		if d2 < hill[4] * hill[4] then
			h = math.max(h, hill[2] + math.sqrt(hill[4] * hill[4] - d2))
		end
	end
	return h
end

local function generateRelief()
	-- Montanhas em volta do mapa
	for i = 0, 47 do
		local a = rad(i * 7.5 + rand(-2, 2))
		local radius = rand(495, 540)
		local size = rand(70, 115)
		table.insert(terrainData.Mountains, {
			math.floor(math.cos(a) * radius),
			math.floor(rand(-size * 0.45, -size * 0.1)),
			math.floor(math.sin(a) * radius),
			math.floor(size),
			math.random() < 0.7,
		})
	end
	-- Morros suaves nos campos
	local tries = 0
	while #terrainData.Hills < 22 and tries < 2000 do
		tries += 1
		local r = rand(40, 85)
		local footprint = r * 0.63
		local x, z = rand(-430, 430), rand(-430, 430)
		if isFree(x, z, footprint + 6) and math.abs(x) < 450 and math.abs(z) < 450 then
			table.insert(terrainData.Hills, { math.floor(x), math.floor(-r * 0.78), math.floor(z), math.floor(r) })
			block(x, z, footprint * 0.35)
		end
	end
	-- Lava rachada perto das ruínas
	for i = 0, 6 do
		local a = rad(i * 51 + rand(-10, 10))
		local d = rand(54, 72)
		if not angleNear(i * 51, 0, 20) then
			table.insert(terrainData.Patches, { -265 + math.floor(math.cos(a) * d), math.floor(math.sin(a) * d), math.floor(rand(5, 9)), "CrackedLava" })
		end
	end
end

local function terrainModule(): string
	local lines = { "-- Gerado pelo build (build/map.luau). Usado pelo TerrainService.", "return {" }
	local function list(name, rows)
		table.insert(lines, "\t" .. name .. " = {")
		for _, row in rows do
			local items = {}
			for _, value in row do
				if type(value) == "string" then
					table.insert(items, '"' .. value .. '"')
				else
					table.insert(items, tostring(value))
				end
			end
			table.insert(lines, "\t\t{ " .. table.concat(items, ", ") .. " },")
		end
		table.insert(lines, "\t},")
	end
	list("Hills", terrainData.Hills)
	list("Mountains", terrainData.Mountains)
	list("Patches", terrainData.Patches)
	local lake = terrainData.Lake
	table.insert(lines, ("\tLake = { X = %d, Z = %d, Radius = %d },"):format(lake.X, lake.Z, lake.Radius))
	table.insert(lines, "}")
	return table.concat(lines, "\n") .. "\n"
end

--------------------------------------------------------------------------
-- TERRENO BASE
--------------------------------------------------------------------------
local function buildTerrain(world)
	local folder = lib.folder(world, "Terreno")
	lib.part(folder, {
		Name = "Chao",
		Size = V3(1000, 10, 1000),
		CFrame = CF(0, -5, 0),
		Color = { 92, 135, 70 },
		Material = "Grass",
	})

	-- Paredes invisíveis no limite do mapa
	for _, data in {
		{ V3(1000, 300, 4), V3(0, 150, -482) },
		{ V3(1000, 300, 4), V3(0, 150, 482) },
		{ V3(4, 300, 1000), V3(-482, 150, 0) },
		{ V3(4, 300, 1000), V3(482, 150, 0) },
	} do
		lib.part(folder, {
			Name = "Limite",
			Size = data[1],
			CFrame = CF(data[2]),
			Transparency = 1,
		})
	end

end

--------------------------------------------------------------------------
-- VILA (zona segura)
--------------------------------------------------------------------------
local function buildVillage(world, server)
	local vila = lib.folder(world, "Vila")
	block(0, 0, 80)

	-- Praça
	lib.part(vila, {
		Name = "Praca",
		Size = V3(120, 1, 120),
		CFrame = CF(0, 0, 0),
		Color = { 150, 145, 135 },
		Material = "Cobblestone",
	})
	-- Meio-fio com aberturas para norte, leste e oeste
	local curb = { Color = { 120, 115, 108 }, Material = "Cobblestone" }
	for _, side in { -1, 1 } do
		lib.part(vila, { Name = "Mureta", Size = V3(52, 1.5, 1), CFrame = CF(side * 34, 1.25, -59.5), Color = curb.Color, Material = curb.Material })
		lib.part(vila, { Name = "Mureta", Size = V3(1, 1.5, 52), CFrame = CF(59.5, 1.25, side * 34), Color = curb.Color, Material = curb.Material })
		lib.part(vila, { Name = "Mureta", Size = V3(1, 1.5, 52), CFrame = CF(-59.5, 1.25, side * 34), Color = curb.Color, Material = curb.Material })
	end
	lib.part(vila, { Name = "Mureta", Size = V3(120, 1.5, 1), CFrame = CF(0, 1.25, 59.5), Color = curb.Color, Material = curb.Material })

	-- Fonte com a espada lendária
	local fountain = lib.model(vila, "Fonte")
	lib.cylinder(fountain, { Name = "Fundo", Color = { 160, 155, 148 }, Material = "Marble" }, V3(0, 0.8, 0), 0.6, 24)
	ring(fountain, V3(0, 0, 0), 11.6, 24, nil, function(facing)
		lib.part(fountain, {
			Name = "Borda",
			Size = V3(3.4, 2, 1.2),
			CFrame = facing * CF(0, 1.5, 0),
			Color = { 175, 170, 160 },
			Material = "Marble",
		})
	end)
	lib.cylinder(fountain, {
		Name = "Agua",
		Color = { 70, 150, 210 },
		Material = "Glass",
		Transparency = 0.35,
		CanCollide = false,
	}, V3(0, 1.6, 0), 0.6, 22.4)
	lib.part(fountain, {
		Name = "Pedestal",
		Size = V3(5, 4, 5),
		CFrame = CF(0, 3.1, 0),
		Color = { 185, 180, 170 },
		Material = "Marble",
	})
	lib.part(fountain, {
		Name = "PedestalTopo",
		Size = V3(6, 0.6, 6),
		CFrame = CF(0, 5.3, 0),
		Color = { 200, 160, 60 },
		Material = "Metal",
	})
	local statue = swords.display(
		swords.build(Config.SwordById.celestial, 3.2),
		"EspadaLendaria",
		CF(0, 21.5, 0) * CFrame.Angles(0, rad(30), math.pi)
	)
	statue.Parent = fountain

	-- Pontos de nascimento
	for _, pos in { V3(20, 1, 20), V3(-20, 1, 20), V3(20, 1, -20), V3(-20, 1, -20) } do
		local spawn = lib.part(vila, {
			Class = "SpawnLocation",
			Name = "Nascimento",
			Size = V3(6, 1, 6),
			CFrame = CF(pos),
			Color = { 220, 185, 90 },
			Material = "Slate",
		})
		spawn.Neutral = true
		spawn.Duration = 3
	end

	-- Bancos
	for i = 0, 3 do
		local a = rad(45 + i * 90)
		local position = V3(math.cos(a) * 15, 0.5, math.sin(a) * 15)
		local base = CF(position) * CFrame.Angles(0, math.pi / 2 - a, 0)
		local bench = lib.model(vila, "Banco")
		lib.part(bench, { Name = "Assento", Size = V3(5, 0.4, 1.6), CFrame = base * CF(0, 1.4, 0), Color = { 120, 80, 45 }, Material = "WoodPlanks" })
		lib.part(bench, { Name = "Encosto", Size = V3(5, 1.6, 0.3), CFrame = base * CF(0, 2.3, 0.75), Color = { 120, 80, 45 }, Material = "WoodPlanks" })
		for _, side in { -1, 1 } do
			lib.part(bench, { Name = "Pe", Size = V3(0.4, 1.2, 1.4), CFrame = base * CF(side * 2.2, 0.6, 0), Color = { 50, 50, 55 }, Material = "Metal" })
		end
	end

	-- FERRARIA (loja) ----------------------------------------------------
	local shop = lib.model(vila, "Ferraria")
	lib.part(shop, { Name = "Piso", Size = V3(28, 0.4, 18), CFrame = CF(0, 0.7, 45), Color = { 130, 95, 60 }, Material = "WoodPlanks" })
	lib.part(shop, { Name = "ParedeFundo", Size = V3(30, 12, 1), CFrame = CF(0, 6.5, 54.5), Color = { 150, 140, 125 }, Material = "Brick" })
	for _, side in { -1, 1 } do
		lib.part(shop, { Name = "ParedeLado", Size = V3(1, 12, 19), CFrame = CF(side * 14.5, 6.5, 45), Color = { 150, 140, 125 }, Material = "Brick" })
		lib.part(shop, { Name = "Pilar", Size = V3(1.6, 12, 1.6), CFrame = CF(side * 14.5, 6.5, 35.5), Color = { 90, 60, 35 }, Material = "Wood" })
		lib.part(shop, {
			Name = "Telhado",
			Size = V3(16.6, 0.8, 22),
			CFrame = CF(side * 7.5, 16, 45) * CFrame.Angles(0, 0, rad(-side * 25)),
			Color = { 125, 45, 35 },
			Material = "WoodPlanks",
		})
	end
	lib.part(shop, { Name = "Viga", Size = V3(30.5, 1, 1.4), CFrame = CF(0, 12.5, 35.5), Color = { 90, 60, 35 }, Material = "Wood" })
	-- Frontão (triângulo do telhado) com placa
	local board = lib.part(shop, {
		Name = "Placa",
		Size = V3(12, 2.6, 0.4),
		CFrame = CF(0, 14.4, 35.2),
		Color = { 90, 60, 35 },
		Material = "WoodPlanks",
	})
	lib.sign(board, "Front", "FERRARIA", lib.rgb(255, 210, 110))

	-- Balcão
	local counter = lib.part(shop, { Name = "Balcao", Size = V3(16, 3.5, 2.5), CFrame = CF(0, 2.65, 40), Color = { 120, 80, 45 }, Material = "Wood" })
	lib.part(shop, { Name = "TampoBalcao", Size = V3(16.6, 0.3, 3), CFrame = CF(0, 4.55, 40), Color = { 80, 55, 30 }, Material = "Wood" })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Abrir Loja"
	prompt.ObjectText = "Ferraria"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:AddTag("ShopPrompt")
	prompt.Parent = counter

	-- Ferreiro
	local smith = characters.blacksmith()
	lib.transform(smith, CF(0, 0.9, 44))
	smith.Parent = shop

	-- Bigorna
	lib.part(shop, { Name = "BigornaBase", Size = V3(1.6, 1.4, 1.2), CFrame = CF(9, 1.6, 46), Color = { 50, 50, 55 }, Material = "Metal" })
	lib.part(shop, { Name = "Bigorna", Size = V3(3, 0.9, 1.3), CFrame = CF(9, 2.75, 46), Color = { 60, 60, 66 }, Material = "Metal" })
	-- Forno
	lib.part(shop, { Name = "Forno", Size = V3(6, 7, 4.5), CFrame = CF(-9, 4.4, 50.5), Color = { 120, 70, 55 }, Material = "Brick" })
	local opening = lib.part(shop, { Name = "Brasa", Size = V3(2.6, 2, 0.2), CFrame = CF(-9, 2.6, 48.2), Color = { 255, 120, 30 }, Material = "Neon" })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Parent = opening
	lib.light(opening, { Color = lib.rgb(255, 130, 40), Range = 18, Brightness = 2 })
	lib.part(shop, { Name = "Chamine", Size = V3(2.2, 10, 2.2), CFrame = CF(-9, 12.9, 51.5), Color = { 110, 65, 50 }, Material = "Brick" })
	local smoke = Instance.new("Smoke")
	smoke.Opacity = 0.15
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = shop:FindFirstChild("Chamine")

	-- Vitrine de espadas na parede do fundo
	lib.part(shop, { Name = "Painel", Size = V3(27, 9, 0.3), CFrame = CF(0, 5.6, 53.85), Color = { 85, 55, 30 }, Material = "WoodPlanks" })
	for i, sword in Config.Swords do
		local x = -10.8 + (i - 1) * 3.6
		local display = swords.display(swords.build(sword, 1), "Vitrine_" .. sword.Id, CF(x, 3.2, 53.4))
		display.Parent = shop
		local plaque = lib.part(shop, {
			Name = "Plaquinha",
			Size = V3(3.3, 1, 0.2),
			CFrame = CF(x, 1.7, 53.5),
			Color = { 60, 40, 25 },
			Material = "Wood",
		})
		local priceText = sword.Price and (tostring(sword.Price) .. " moedas") or "Drop do Chefe"
		lib.sign(plaque, "Front", sword.Name .. "\n" .. priceText, lib.rgb(255, 225, 150))
	end

	-- PLACAR --------------------------------------------------------------
	local boardBase = CF(-42, 0.5, -42) * CFrame.Angles(0, rad(-45), 0)
	local leaderboard = lib.model(vila, "Placar")
	for _, side in { -1, 1 } do
		lib.part(leaderboard, { Name = "Poste", Size = V3(1, 10, 1), CFrame = boardBase * CF(-0.9, 5, side * 8.5), Color = { 80, 55, 35 }, Material = "Wood" })
	end
	local boardPart = lib.part(leaderboard, {
		Name = "Quadro",
		Size = V3(0.8, 13, 20),
		CFrame = boardBase * CF(0, 9.5, 0),
		Color = { 60, 40, 25 },
		Material = "WoodPlanks",
		Tags = { "Leaderboard" },
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.2
	gui.Parent = boardPart
	local back = lib.new("Frame", {
		Size = lib.UDim2.fromScale(1, 1),
		BackgroundColor3 = lib.rgb(25, 22, 30),
		BackgroundTransparency = 0.1,
	}, gui)
	lib.new("TextLabel", {
		Name = "Titulo",
		Size = lib.UDim2.fromScale(1, 0.14),
		BackgroundTransparency = 1,
		Text = "TOP DO SERVIDOR",
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		TextColor3 = lib.rgb(255, 205, 85),
	}, back)
	local rows = lib.new("Frame", {
		Name = "Rows",
		Position = lib.UDim2.fromScale(0.04, 0.16),
		Size = lib.UDim2.fromScale(0.92, 0.82),
		BackgroundTransparency = 1,
	}, back)
	lib.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = lib.UDim.new(0, 2) }, rows)
	for i = 1, 10 do
		lib.new("TextLabel", {
			Name = "Row" .. i,
			LayoutOrder = i,
			Size = lib.UDim2.new(1, 0, 0.098, 0),
			BackgroundTransparency = 1,
			Text = i .. ". ---",
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = i == 1 and lib.rgb(255, 215, 90) or i == 2 and lib.rgb(220, 220, 230) or i == 3 and lib.rgb(220, 150, 90) or lib.rgb(235, 235, 240),
		}, rows)
	end

	-- ÁREA DE TREINO --------------------------------------------------------
	local training = lib.folder(vila, "Treino")
	lib.part(training, { Name = "Areia", Size = V3(14, 0.1, 44), CFrame = CF(46, 0.55, -31), Color = { 210, 190, 140 }, Material = "Sand" })
	for _, z in { -16, -26, -36, -46 } do
		local dummy = characters.dummy()
		lib.transform(dummy, CF(46, 0.6, z) * CFrame.Angles(0, rad(90), 0))
		dummy.Parent = training
	end
	local trainingSign = lib.part(training, {
		Name = "Placa",
		Size = V3(0.5, 3, 12),
		CFrame = CF(55, 4, -31),
		Color = { 90, 60, 35 },
		Material = "WoodPlanks",
	})
	lib.sign(trainingSign, "Left", "ÁREA DE TREINO", lib.rgb(255, 220, 120))
	for _, z in { -36, -26 } do
		lib.part(training, { Name = "Poste", Size = V3(0.6, 3, 0.6), CFrame = CF(55, 1.5, z), Color = { 80, 55, 35 }, Material = "Wood" })
	end

	-- Arcos de saída
	arch(vila, V3(0, 0.5, -60), 0, "ARENA  PvP", lib.rgb(255, 120, 100))
	arch(vila, V3(60, 0.5, 0), 90, "FLORESTA SOMBRIA", lib.rgb(150, 230, 120))
	arch(vila, V3(-60, 0.5, 0), 90, "RUÍNAS DO REI", lib.rgb(255, 90, 100))

	-- Postes de luz
	for _, pos in {
		V3(54, 0.5, 54), V3(-54, 0.5, 54), V3(54, 0.5, -54), V3(-54, 0.5, -54),
		V3(30, 0.5, 0), V3(-30, 0.5, 0), V3(0, 0.5, -30), V3(22, 0.5, 30), V3(-22, 0.5, 30),
	} do
		lamp(vila, pos)
	end

	-- Canteiros de flores
	local flowers = { { 255, 90, 110 }, { 255, 220, 80 }, { 200, 120, 255 }, { 255, 255, 255 } }
	for _, center in { V3(-30, 0.5, -45), V3(30, 0.5, 18), V3(-45, 0.5, 20), V3(-30, 0.5, 45), V3(30, 0.5, 48) } do
		lib.part(vila, { Name = "Canteiro", Size = V3(8, 0.6, 5), CFrame = CF(center + V3(0, 0.3, 0)), Color = { 100, 70, 45 }, Material = "Ground" })
		for _ = 1, 9 do
			lib.part(vila, {
				Name = "Flor",
				Shape = "Ball",
				Size = V3(0.8, 0.8, 0.8),
				CFrame = CF(center + V3(rand(-3.4, 3.4), 1, rand(-2, 2))),
				Color = pick(flowers),
				Material = "SmoothPlastic",
				CanCollide = false,
			})
		end
	end

	-- Árvores ao redor da vila
	for _, along in { -50, -28, 28, 50 } do
		tree(vila, V3(along + rand(-3, 3), 0, -72 + rand(-2, 2)))
		tree(vila, V3(along + rand(-3, 3), 0, 72 + rand(-2, 2)))
		tree(vila, V3(-72 + rand(-2, 2), 0, along + rand(-3, 3)))
		tree(vila, V3(72 + rand(-2, 2), 0, along + rand(-3, 3)))
	end

	zonePart(server.Zones, "Vila", V3(0, 30, 0), V3(132, 80, 132), true)
end

--------------------------------------------------------------------------
-- CAMINHOS
--------------------------------------------------------------------------
local function buildPaths(world)
	local paths = lib.folder(world, "Caminhos")
	local dirt = { Color = { 125, 100, 70 }, Material = "Ground" }
	lib.part(paths, { Name = "CaminhoArena", Size = V3(14, 0.4, 112), CFrame = CF(0, 0.1, -116), Color = dirt.Color, Material = dirt.Material })
	lib.part(paths, { Name = "CaminhoFloresta", Size = V3(150, 0.4, 12), CFrame = CF(135, 0.1, 0), Color = dirt.Color, Material = dirt.Material })
	lib.part(paths, { Name = "CaminhoRuinas", Size = V3(160, 0.4, 12), CFrame = CF(-140, 0.1, 0), Color = dirt.Color, Material = dirt.Material })
	blockRect(-10, -60, 10, -172)
	blockRect(60, -9, 300, 9)
	blockRect(-60, -9, -220, 9)

	for i = 0, 3 do
		lamp(paths, V3(i % 2 == 0 and 10 or -10, 0, -75 - i * 28))
		lamp(paths, V3(75 + i * 30, 0, i % 2 == 0 and 9 or -9))
		lamp(paths, V3(-75 - i * 34, 0, i % 2 == 0 and 9 or -9))
	end
end

--------------------------------------------------------------------------
-- ARENA PvP
--------------------------------------------------------------------------
local function buildArena(world, server)
	local arena = lib.folder(world, "Arena")
	local center = V3(0, 0, -230)
	block(center.X, center.Z, 88)

	lib.cylinder(arena, { Name = "Chao", Color = { 215, 190, 140 }, Material = "Sand" }, center, 1, 124)
	lib.cylinder(arena, { Name = "Emblema", Color = { 190, 45, 40 }, Material = "Neon" }, center + V3(0, 0.55, 0), 0.1, 24)
	lib.cylinder(arena, { Name = "EmblemaCentro", Color = { 205, 180, 130 }, Material = "Sand" }, center + V3(0, 0.6, 0), 0.1, 21)
	for _, angle in { 45, -45 } do
		lib.part(arena, {
			Name = "EmblemaEspada",
			Size = V3(16, 0.1, 1.1),
			CFrame = CF(center + V3(0, 0.66, 0)) * CFrame.Angles(0, rad(angle), 0),
			Color = { 170, 35, 35 },
			Material = "Neon",
		})
	end

	local function isGate(angle)
		return angleNear(angle, 90, 8) or angleNear(angle, 270, 8)
	end

	-- Muro
	ring(arena, center, 62, 48, isGate, function(facing, i)
		lib.part(arena, {
			Name = "Muro",
			Size = V3(8.6, 8, 3),
			CFrame = facing * CF(0, 4, 0),
			Color = { 195, 165, 120 },
			Material = "Sandstone",
		})
		if i % 2 == 0 then
			lib.part(arena, {
				Name = "Ameia",
				Size = V3(3, 2, 3),
				CFrame = facing * CF(0, 9, 0),
				Color = { 185, 155, 110 },
				Material = "Sandstone",
			})
		end
		if i % 6 == 0 then
			lib.part(arena, {
				Name = "Estandarte",
				Size = V3(4, 6, 0.2),
				CFrame = facing * CF(0, 4.5, -1.65),
				Color = (i / 6) % 2 == 0 and { 170, 30, 30 } or { 30, 60, 160 },
				Material = "Fabric",
			})
		end
		if i % 6 == 3 then
			torch(arena, (facing * CF(0, 8, 0)).Position)
		end
	end)

	-- Arquibancadas
	for tier = 1, 3 do
		local radius = 63.5 + tier * 4 - 2
		local height = tier * 4
		local count = 48
		local width = 2 * math.pi * radius / count + 0.6
		ring(arena, center, radius, count, isGate, function(facing)
			lib.part(arena, {
				Name = "Arquibancada",
				Size = V3(width, height, 4),
				CFrame = facing * CF(0, height / 2, 0),
				Color = tier % 2 == 0 and { 165, 155, 140 } or { 180, 170, 155 },
				Material = "Concrete",
			})
		end)
	end

	arch(arena, center + V3(0, 0, 66), 0, "ARENA  PvP", lib.rgb(255, 120, 100))
	arch(arena, center + V3(0, 0, -66), 0, "ARENA  PvP", lib.rgb(255, 120, 100))

	zonePart(server.Zones, "Arena", center + V3(0, 30, 0), V3(160, 80, 160), false)
end

--------------------------------------------------------------------------
-- FLORESTA SOMBRIA
--------------------------------------------------------------------------
local function tent(parent, position, yaw, color)
	local model = lib.model(parent, "Tenda")
	local base = CF(position) * CFrame.Angles(0, rad(yaw), 0)
	local w, h = 3, 3.5
	local length = math.sqrt(w * w + h * h)
	local angle = math.atan2(h, w)
	for _, side in { -1, 1 } do
		lib.part(model, {
			Name = "Lona",
			Size = V3(length + 0.3, 0.25, 6),
			CFrame = base * CF(side * w / 2, h / 2, 0) * CFrame.Angles(0, 0, -side * angle),
			Color = color,
			Material = "Fabric",
		})
	end
	lib.cylinder(model, { Name = "Mastro", Color = { 90, 65, 40 }, Material = "Wood" }, (base * CF(0, h / 2, -3)).Position, h, 0.3)
	return model
end

local function campfire(parent, position)
	local model = lib.model(parent, "Fogueira")
	for i = 0, 2 do
		lib.part(model, {
			Name = "Lenha",
			Shape = "Cylinder",
			Size = V3(3.2, 0.5, 0.5),
			CFrame = CF(position + V3(0, 0.35, 0)) * CFrame.Angles(0, rad(i * 60), rad(10)),
			Color = { 90, 60, 40 },
			Material = "Wood",
		})
	end
	for i = 0, 7 do
		local a = rad(i * 45)
		rock(model, position + V3(math.cos(a) * 2.2, -0.2, math.sin(a) * 2.2), 0.9)
	end
	local core = lib.part(model, {
		Name = "Brasa",
		Size = V3(1.2, 0.4, 1.2),
		CFrame = CF(position + V3(0, 0.4, 0)),
		Color = { 255, 120, 30 },
		Material = "Neon",
		CanCollide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 9
	fire.Parent = core
	lib.light(core, { Color = lib.rgb(255, 140, 50), Range = 24, Brightness = 2 })
	return model
end

local function buildForest(world, server)
	local forest = lib.folder(world, "FlorestaSombria")
	local spawns = server.NPCSpawns

	lib.part(forest, {
		Name = "ChaoFloresta",
		Size = V3(235, 0.2, 345),
		CFrame = CF(265, 0, 0),
		Color = { 62, 98, 52 },
		Material = "LeafyGrass",
	})
	lib.part(forest, { Name = "Trilha", Size = V3(100, 0.4, 10), CFrame = CF(255, 0.12, 0), Color = { 110, 88, 62 }, Material = "Ground" })

	-- Acampamento goblin
	local camp = lib.folder(forest, "AcampamentoGoblin")
	local campCenter = V3(215, 0.1, -75)
	block(campCenter.X, campCenter.Z, 22)
	campfire(camp, campCenter)
	tent(camp, campCenter + V3(-12, 0, -6), 30, { 150, 110, 60 })
	tent(camp, campCenter + V3(10, 0, -10), -25, { 125, 95, 55 })
	tent(camp, campCenter + V3(0, 0, 13), 90, { 140, 100, 50 })
	for _, offset in { V3(14, 0, 6), V3(15, 0, 9), V3(-14, 0, 8) } do
		lib.part(camp, {
			Name = "Caixa",
			Size = V3(2.5, 2.5, 2.5),
			CFrame = CF(campCenter + offset + V3(0, 1.25, 0)) * CFrame.Angles(0, rad(rand(0, 90)), 0),
			Color = { 140, 100, 60 },
			Material = "WoodPlanks",
		})
	end
	-- Totem com caveira
	lib.cylinder(camp, { Name = "Totem", Color = { 90, 65, 40 }, Material = "Wood" }, campCenter + V3(-4, 3, -16), 6, 0.6)
	lib.part(camp, { Name = "Caveira", Shape = "Ball", Size = V3(1.4, 1.4, 1.4), CFrame = CF(campCenter + V3(-4, 6.6, -16)), Color = { 230, 225, 205 }, Material = "SmoothPlastic" })
	for i = 0, 6 do
		local a = rad(i * (360 / 7) + 20)
		npcSpawn(spawns, "Goblin", campCenter + V3(math.cos(a) * rand(7, 14), 0, math.sin(a) * rand(7, 14)))
	end
	npcSpawn(spawns, "Goblin", V3(180, 0.1, -25))
	npcSpawn(spawns, "Goblin", V3(190, 0.1, 30))

	-- Cemitério
	local grave = lib.folder(forest, "Cemiterio")
	local graveCenter = V3(245, 0.1, 82)
	block(graveCenter.X, graveCenter.Z, 26)
	for i = -4, 4 do
		for _, z in { -18, 18 } do
			if not (z == -18 and math.abs(i) <= 1) then
				lib.part(grave, {
					Name = "Cerca",
					Size = V3(0.4, 4, 0.4),
					CFrame = CF(graveCenter + V3(i * 4.5, 2, z)),
					Color = { 40, 40, 45 },
					Material = "Metal",
				})
			end
		end
		lib.part(grave, { Name = "Cerca", Size = V3(0.4, 4, 0.4), CFrame = CF(graveCenter + V3(-18, 2, i * 4.5)), Color = { 40, 40, 45 }, Material = "Metal" })
		lib.part(grave, { Name = "Cerca", Size = V3(0.4, 4, 0.4), CFrame = CF(graveCenter + V3(18, 2, i * 4.5)), Color = { 40, 40, 45 }, Material = "Metal" })
	end
	for _, z in { 18 } do
		lib.part(grave, { Name = "CercaBarra", Size = V3(36, 0.3, 0.3), CFrame = CF(graveCenter + V3(0, 3.5, z)), Color = { 40, 40, 45 }, Material = "Metal" })
	end
	for _, x in { -18, 18 } do
		lib.part(grave, { Name = "CercaBarra", Size = V3(0.3, 0.3, 36), CFrame = CF(graveCenter + V3(x, 3.5, 0)), Color = { 40, 40, 45 }, Material = "Metal" })
	end
	for row = 0, 2 do
		for col = 0, 3 do
			local position = graveCenter + V3(-10.5 + col * 7, 0, -8 + row * 8)
			lib.part(grave, {
				Name = "Lapide",
				Size = V3(2.2, 2.8, 0.5),
				CFrame = CF(position + V3(0, 1.4, 2)) * CFrame.Angles(rad(rand(-8, 8)), 0, rad(rand(-6, 6))),
				Color = { 125, 125, 130 },
				Material = "Granite",
			})
			lib.part(grave, {
				Name = "Cova",
				Size = V3(2.4, 0.5, 4.5),
				CFrame = CF(position + V3(0, 0.25, -1)),
				Color = { 90, 70, 50 },
				Material = "Ground",
			})
		end
	end
	for _, offset in { V3(-14, 0, 14), V3(14, 0, -14), V3(13, 0, 13) } do
		tree(grave, graveCenter + offset, "dead", 1)
	end
	for _, offset in { V3(-15, 0, -15), V3(15, 0, 15) } do
		local lantern = lib.part(grave, {
			Name = "LuzFantasma",
			Shape = "Ball",
			Size = V3(1.2, 1.2, 1.2),
			CFrame = CF(graveCenter + offset + V3(0, 4.6, 0)),
			Color = { 120, 220, 255 },
			Material = "Neon",
		})
		lib.light(lantern, { Color = lib.rgb(120, 220, 255), Range = 18, Brightness = 1.5 })
	end
	for i = 0, 4 do
		local a = rad(i * 72)
		npcSpawn(spawns, "Esqueleto", graveCenter + V3(math.cos(a) * 9, 0, math.sin(a) * 9))
	end

	-- Fortaleza orc
	local fort = lib.folder(forest, "FortalezaOrc")
	local fortCenter = V3(330, 0.1, 0)
	block(fortCenter.X, fortCenter.Z, 34)
	ring(fort, fortCenter, 26, 90, function(angle)
		return angleNear(angle, 180, 9)
	end, function(facing)
		local height = rand(10, 12.5)
		lib.cylinder(fort, { Name = "Tronco", Color = { 100, 72, 45 }, Material = "Wood" }, (facing * CF(0, height / 2, 0)).Position, height, 1.9)
	end)
	-- Torre de vigia
	local towerBase = fortCenter + V3(14, 0, -14)
	for _, offset in { V3(-3, 0, -3), V3(3, 0, -3), V3(-3, 0, 3), V3(3, 0, 3) } do
		lib.part(fort, { Name = "PernaTorre", Size = V3(1, 16, 1), CFrame = CF(towerBase + offset + V3(0, 8, 0)), Color = { 95, 68, 42 }, Material = "Wood" })
	end
	lib.part(fort, { Name = "PlataformaTorre", Size = V3(8, 0.8, 8), CFrame = CF(towerBase + V3(0, 16, 0)), Color = { 120, 85, 50 }, Material = "WoodPlanks" })
	lib.part(fort, { Name = "TetoTorre", Size = V3(9, 0.6, 9), CFrame = CF(towerBase + V3(0, 22, 0)), Color = { 110, 40, 30 }, Material = "WoodPlanks" })
	for _, offset in { V3(-3.8, 0, -3.8), V3(3.8, 0, -3.8), V3(-3.8, 0, 3.8), V3(3.8, 0, 3.8) } do
		lib.part(fort, { Name = "ColunaTeto", Size = V3(0.5, 6, 0.5), CFrame = CF(towerBase + offset + V3(0, 19, 0)), Color = { 95, 68, 42 }, Material = "Wood" })
	end
	tent(fort, fortCenter + V3(-6, 0, 12), 0, { 110, 45, 35 })
	tent(fort, fortCenter + V3(8, 0, 12), 0, { 110, 45, 35 })
	campfire(fort, fortCenter + V3(0, 0, -2))
	for _, offset in { V3(-28, 0, -8), V3(-28, 0, 8) } do
		lib.cylinder(fort, { Name = "MastroBandeira", Color = { 80, 55, 35 }, Material = "Wood" }, fortCenter + offset + V3(0, 8, 0), 16, 0.5)
		lib.part(fort, {
			Name = "Bandeira",
			Size = V3(0.2, 4, 5),
			CFrame = CF(fortCenter + offset + V3(0, 13.5, 2.6)),
			Color = { 140, 30, 25 },
			Material = "Fabric",
		})
	end
	for _, offset in { V3(-8, 0, -8), V3(8, 0, -6), V3(-4, 0, 5), V3(6, 0, 3) } do
		npcSpawn(spawns, "Orc", fortCenter + offset)
	end

	-- Cogumelos gigantes brilhantes
	local mushrooms = lib.folder(forest, "Cogumelos")
	local capColors = { { 170, 80, 255 }, { 80, 210, 255 }, { 255, 90, 170 } }
	local placed = 0
	for _ = 1, 200 do
		if placed >= 18 then
			break
		end
		local x, z = rand(160, 370), rand(-160, 160)
		if isFree(x, z, 5) then
			block(x, z, 5)
			placed += 1
			local height = rand(3, 7)
			local base = V3(x, 0.1, z)
			local color = pick(capColors)
			lib.cylinder(mushrooms, { Name = "Caule", Color = { 230, 225, 210 }, Material = "SmoothPlastic" }, base + V3(0, height / 2, 0), height, rand(1, 1.6))
			local capSize = rand(4, 7)
			local cap = lib.cylinder(mushrooms, { Name = "Chapeu", Color = color, Material = "Neon" }, base + V3(0, height + 0.5, 0), 1.2, capSize)
			lib.cylinder(mushrooms, { Name = "ChapeuTopo", Color = color, Material = "Neon" }, base + V3(0, height + 1.4, 0), 0.8, capSize * 0.6)
			lib.light(cap, { Color = lib.rgb(color), Range = 14, Brightness = 1 })
		end
	end

	-- Árvores e pedras
	local trees = lib.folder(forest, "Arvores")
	local treeSpots = {}
	for _ = 1, 600 do
		if #treeSpots >= 115 then
			break
		end
		local x, z = rand(155, 375), rand(-168, 168)
		if isFree(x, z, 5) then
			local ok = true
			for _, spot in treeSpots do
				if (spot.X - x) ^ 2 + (spot.Z - z) ^ 2 < 90 then
					ok = false
					break
				end
			end
			if ok then
				table.insert(treeSpots, V3(x, 0.1, z))
			end
		end
	end
	for i, spot in treeSpots do
		if i % 3 == 0 then
			tree(trees, spot, "pine")
		else
			darkTree(trees, spot)
		end
	end
	for _ = 1, 30 do
		local x, z = rand(155, 375), rand(-168, 168)
		if isFree(x, z, 3) then
			rock(trees, V3(x, 0.1, z))
		end
	end

	-- Placa na entrada
	local sign = lib.part(forest, {
		Name = "PlacaPerigo",
		Size = V3(0.5, 3, 9),
		CFrame = CF(160, 4, 12),
		Color = { 90, 60, 35 },
		Material = "WoodPlanks",
	})
	lib.sign(sign, "Left", "CUIDADO: MONSTROS!", lib.rgb(255, 120, 90))
	lib.part(forest, { Name = "PostePlaca", Size = V3(0.6, 3, 0.6), CFrame = CF(160, 1.5, 12), Color = { 80, 55, 35 }, Material = "Wood" })

	zonePart(server.Zones, "Floresta", V3(265, 40, 0), V3(240, 100, 350), false)
end

--------------------------------------------------------------------------
-- RUÍNAS DO REI CAÍDO
--------------------------------------------------------------------------
local function buildRuins(world, server)
	local ruins = lib.folder(world, "RuinasDoRei")
	local center = V3(-265, 0, 0)
	block(center.X, center.Z, 58)

	lib.cylinder(ruins, { Name = "Plataforma", Color = { 65, 65, 75 }, Material = "Slate" }, center, 1.4, 96)
	lib.cylinder(ruins, { Name = "CirculoRunico", Color = { 170, 20, 35 }, Material = "Neon" }, center + V3(0, 0.75, 0), 0.1, 44)
	lib.cylinder(ruins, { Name = "CirculoInterno", Color = { 55, 55, 65 }, Material = "Slate" }, center + V3(0, 0.8, 0), 0.1, 41)
	for i = 0, 7 do
		local a = rad(i * 45 + 22.5)
		lib.part(ruins, {
			Name = "Runa",
			Size = V3(1.2, 0.1, 3),
			CFrame = CF(center + V3(math.cos(a) * 15, 0.9, math.sin(a) * 15)) * CFrame.Angles(0, -a, 0),
			Color = { 200, 25, 45 },
			Material = "Neon",
		})
	end

	-- Pilares (inteiros, quebrados e caídos)
	ring(ruins, center, 40, 14, function(angle)
		return angleNear(angle, 0, 14) or angleNear(angle, 180, 14)
	end, function(facing, i)
		local base = facing.Position + V3(0, 0.7, 0)
		local kind = i % 3
		local stone = { 110, 108, 118 }
		lib.part(ruins, { Name = "BasePilar", Size = V3(4.4, 1, 4.4), CFrame = CF(base + V3(0, 0.5, 0)), Color = { 95, 93, 102 }, Material = "Granite" })
		if kind == 0 then
			lib.cylinder(ruins, { Name = "Pilar", Color = stone, Material = "Granite" }, base + V3(0, 9, 0), 16, 3.2)
			lib.part(ruins, { Name = "Capitel", Size = V3(4.6, 1.2, 4.6), CFrame = CF(base + V3(0, 17.6, 0)), Color = { 95, 93, 102 }, Material = "Granite" })
		elseif kind == 1 then
			local height = rand(4, 9)
			lib.cylinder(ruins, { Name = "PilarQuebrado", Color = stone, Material = "Granite" }, base + V3(0, 1 + height / 2, 0), height, 3.2)
			lib.part(ruins, {
				Name = "Escombro",
				Size = V3(2.5, 1.5, 2),
				CFrame = CF(base + V3(rand(-3, 3), 0.75, rand(-3, 3))) * CFrame.Angles(rad(rand(-20, 20)), rad(rand(0, 360)), 0),
				Color = stone,
				Material = "Granite",
			})
		else
			lib.cylinder(ruins, { Name = "PilarQuebrado", Color = stone, Material = "Granite" }, base + V3(0, 2, 0), 2, 3.2)
			lib.part(ruins, {
				Name = "PilarCaido",
				Shape = "Cylinder",
				Size = V3(11, 3, 3),
				CFrame = facing * CF(6.5, 2.2, 0) * CFrame.Angles(0, 0, rad(4)),
				Color = stone,
				Material = "Granite",
			})
		end
	end)

	-- Trono
	local throne = lib.model(ruins, "Trono")
	local tx = center.X - 36
	lib.part(throne, { Name = "Degrau1", Size = V3(12, 1, 14), CFrame = CF(tx, 1.2, 0), Color = { 45, 40, 50 }, Material = "Marble" })
	lib.part(throne, { Name = "Degrau2", Size = V3(9, 1, 11), CFrame = CF(tx - 1.5, 2.2, 0), Color = { 50, 45, 55 }, Material = "Marble" })
	lib.part(throne, { Name = "Degrau3", Size = V3(6, 1, 8), CFrame = CF(tx - 3, 3.2, 0), Color = { 55, 50, 60 }, Material = "Marble" })
	lib.part(throne, { Name = "Assento", Size = V3(4, 1.2, 4.5), CFrame = CF(tx - 3, 4.3, 0), Color = { 70, 15, 25 }, Material = "Fabric" })
	lib.part(throne, { Name = "Encosto", Size = V3(1, 9, 5), CFrame = CF(tx - 5.2, 8.2, 0), Color = { 40, 35, 45 }, Material = "Marble" })
	lib.part(throne, { Name = "EncostoOuro", Size = V3(1.1, 0.6, 5.2), CFrame = CF(tx - 5.2, 12.9, 0), Color = { 200, 160, 40 }, Material = "Metal" })
	for _, side in { -1, 1 } do
		lib.part(throne, { Name = "BracoTrono", Size = V3(4, 1.4, 0.8), CFrame = CF(tx - 3, 5.3, side * 2.6), Color = { 40, 35, 45 }, Material = "Marble" })
		lib.part(throne, { Name = "PontaOuro", Size = V3(0.8, 2.4, 0.8), CFrame = CF(tx - 5.2, 13.9, side * 2), Color = { 200, 160, 40 }, Material = "Metal" })
	end
	local runeWall = lib.part(throne, { Name = "MuralRunico", Size = V3(0.6, 16, 12), CFrame = CF(tx - 7, 8.7, 0), Color = { 30, 25, 35 }, Material = "Slate" })
	local runeGlow = lib.part(throne, { Name = "RunaGrande", Size = V3(0.2, 8, 1.2), CFrame = CF(tx - 6.6, 10, 0), Color = { 220, 25, 45 }, Material = "Neon" })
	lib.light(runeGlow, { Color = lib.rgb(255, 30, 50), Range = 20, Brightness = 2 })
	runeWall.Name = "MuralRunico"

	-- Tapete vermelho
	lib.part(ruins, { Name = "Tapete", Size = V3(60, 0.1, 6), CFrame = CF(center.X + 1, 0.9, 0), Color = { 130, 20, 30 }, Material = "Fabric", CanCollide = false })

	-- Braseiros
	for _, offset in { V3(22, 0, 22), V3(22, 0, -22), V3(-22, 0, 22), V3(-22, 0, -22) } do
		torch(ruins, center + offset + V3(0, 0.7, 0), { 255, 40, 50 })
	end

	-- Árvores mortas em volta
	for i = 0, 11 do
		local a = rad(i * 30 + 15)
		if not angleNear(i * 30 + 15, 0, 20) then
			tree(ruins, center + V3(math.cos(a) * rand(55, 70), 0, math.sin(a) * rand(55, 70)), "dead", rand(1, 1.4))
		end
	end

	-- Cristais sombrios brilhantes
	local crystals = lib.folder(ruins, "Cristais")
	for i = 0, 7 do
		local a = rad(i * 45 + 20)
		if not angleNear(i * 45 + 20, 0, 25) then
			local d = i % 2 == 0 and rand(50, 56) or rand(26, 32)
			local base = V3(center.X + math.cos(a) * d, i % 2 == 0 and 0 or 0.8, center.Z + math.sin(a) * d)
			local cluster = lib.model(crystals, "Cristal")
			for k = 1, 5 do
				local height = rand(3, 8) * (k == 1 and 1.5 or 1)
				local width = height * 0.28
				lib.part(cluster, {
					Name = "Cristal",
					Size = V3(width, height, width),
					CFrame = CF(base + V3(rand(-1.5, 1.5), height * 0.4, rand(-1.5, 1.5)))
						* CFrame.Angles(rad(rand(-25, 25)), rad(rand(0, 90)), rad(rand(-25, 25)))
						* CFrame.Angles(0, rad(45), 0),
					Color = pick({ { 160, 60, 255 }, { 120, 40, 220 }, { 200, 90, 255 } }),
					Material = "Neon",
					Transparency = 0.15,
				})
			end
			lib.light(cluster:FindFirstChild("Cristal"), { Color = lib.rgb(170, 70, 255), Range = 16, Brightness = 1.5 })
		end
	end

	-- Obeliscos com runas na entrada
	for _, side in { -1, 1 } do
		local base = center + V3(56, 0, side * 16)
		local obelisk = lib.model(ruins, "Obelisco")
		lib.part(obelisk, { Name = "Base", Size = V3(5, 1.5, 5), CFrame = CF(base + V3(0, 0.75, 0)), Color = { 70, 68, 80 }, Material = "Slate" })
		lib.part(obelisk, { Name = "Pedra", Size = V3(3, 16, 3), CFrame = CF(base + V3(0, 9.5, 0)), Color = { 55, 52, 65 }, Material = "Slate" })
		lib.part(obelisk, { Name = "Ponta", Size = V3(2.1, 2.1, 2.1), CFrame = CF(base + V3(0, 17.8, 0)) * CFrame.Angles(rad(45), 0, rad(45)), Color = { 55, 52, 65 }, Material = "Slate" })
		for k = 0, 3 do
			lib.part(obelisk, {
				Name = "Runa",
				Size = V3(0.6, 1.6, 0.2),
				CFrame = CF(base + V3(1.55, 5 + k * 3, 0)) * CFrame.Angles(0, rad(90), 0),
				Color = { 220, 30, 50 },
				Material = "Neon",
			})
		end
		lib.light(obelisk:FindFirstChild("Pedra"), { Color = lib.rgb(255, 40, 60), Range = 14, Brightness = 1 })
	end

	-- Inimigos
	npcSpawn(server.NPCSpawns, "ReiCaido", center + V3(-8, 0.7, 0))
	npcSpawn(server.NPCSpawns, "Esqueleto", V3(-200, 0, 22))
	npcSpawn(server.NPCSpawns, "Esqueleto", V3(-200, 0, -22))

	zonePart(server.Zones, "Ruinas", center + V3(0, 40, 0), V3(200, 100, 200), false)
end

--------------------------------------------------------------------------
-- CAMPOS (decoração entre as áreas)
--------------------------------------------------------------------------
local function buildFields(world)
	local fields = lib.folder(world, "Campos")
	-- Floresta e área da arena já bloqueadas
	blockRect(148, -175, 385, 175)

	local count = 0
	for _ = 1, 900 do
		if count >= 95 then
			break
		end
		local x, z = rand(-420, 420), rand(-420, 420)
		if isFree(x, z, 6) then
			block(x, z, 7)
			tree(fields, V3(x, heightAt(x, z) - 0.4, z))
			count += 1
		end
	end
	for _ = 1, 60 do
		local x, z = rand(-420, 420), rand(-420, 420)
		if isFree(x, z, 3) then
			rock(fields, V3(x, heightAt(x, z) - 0.3, z))
		end
	end
	local flowers = { { 255, 90, 110 }, { 255, 220, 80 }, { 200, 120, 255 }, { 255, 255, 255 }, { 255, 150, 60 } }
	for _ = 1, 70 do
		local x, z = rand(-420, 420), rand(-420, 420)
		if isFree(x, z, 2) then
			local color = pick(flowers)
			for _ = 1, 5 do
				lib.part(fields, {
					Name = "Flor",
					Shape = "Ball",
					Size = V3(0.7, 0.7, 0.7),
					CFrame = CF(x + rand(-2, 2), heightAt(x, z) + 0.2, z + rand(-2, 2)),
					Color = color,
					Material = "SmoothPlastic",
					CanCollide = false,
				})
			end
		end
	end
	-- Cerca de madeira ao lado dos caminhos
	for i = 0, 9 do
		lib.part(fields, { Name = "Cerca", Size = V3(0.5, 3, 0.5), CFrame = CF(-75 - i * 14, 1.5, 14), Color = { 110, 80, 50 }, Material = "Wood" })
		lib.part(fields, { Name = "CercaBarra", Size = V3(14, 0.4, 0.3), CFrame = CF(-82 - i * 14, 2.3, 14), Color = { 110, 80, 50 }, Material = "Wood" })
	end
end

--------------------------------------------------------------------------
-- CASAS, MERCADO E ENFEITES DA VILA
--------------------------------------------------------------------------
local function house(parent, position, yaw: number, roofColor, wallColor)
	local model = lib.model(parent, "Casa")
	local base = CF(position) * CFrame.Angles(0, rad(yaw), 0)
	local W, D, H = 14, 12, 9
	local wall = wallColor or { 235, 225, 200 }
	local wood = { 85, 55, 35 }
	local function p(props, offset)
		props.CFrame = base * offset
		return lib.part(model, props)
	end

	p({ Name = "Alicerce", Size = V3(W + 1.2, 1.2, D + 1.2), Color = { 130, 125, 118 }, Material = "Cobblestone" }, CF(0, 0.4, 0))
	-- Paredes
	p({ Name = "Parede", Size = V3(W, H, 0.8), Color = wall, Material = "Concrete" }, CF(0, 1 + H / 2, -D / 2 + 0.4))
	p({ Name = "Parede", Size = V3(W, H, 0.8), Color = wall, Material = "Concrete" }, CF(0, 1 + H / 2, D / 2 - 0.4))
	for _, side in { -1, 1 } do
		p({ Name = "Parede", Size = V3(0.8, H, D - 1.6), Color = wall, Material = "Concrete" }, CF(side * (W / 2 - 0.4), 1 + H / 2, 0))
	end
	-- Enxaimel (vigas de madeira)
	for _, x in { -W / 2, W / 2 } do
		for _, z in { -D / 2, D / 2 } do
			p({ Name = "Viga", Size = V3(0.9, H, 0.9), Color = wood, Material = "Wood" }, CF(x, 1 + H / 2, z))
		end
	end
	for _, z in { -D / 2 - 0.05, D / 2 + 0.05 } do
		p({ Name = "Viga", Size = V3(W, 0.6, 0.9), Color = wood, Material = "Wood" }, CF(0, 1 + H * 0.52, z))
		p({ Name = "Viga", Size = V3(W, 0.6, 0.9), Color = wood, Material = "Wood" }, CF(0, 1 + H - 0.3, z))
	end
	for _, side in { -1, 1 } do
		p({ Name = "Diagonal", Size = V3(0.5, 5.6, 0.3), Color = wood, Material = "Wood" },
			CF(side * (W / 2 - 1.6), 1 + H * 0.76, -D / 2 - 0.5) * CFrame.Angles(0, 0, rad(side * 35)))
	end
	-- Porta
	p({ Name = "Porta", Size = V3(3, 5, 0.3), Color = { 100, 60, 35 }, Material = "WoodPlanks" }, CF(0, 3.5, -D / 2 - 0.1))
	p({ Name = "Macaneta", Shape = "Ball", Size = V3(0.35, 0.35, 0.35), Color = { 220, 180, 60 }, Material = "Metal" }, CF(1, 3.5, -D / 2 - 0.35))
	p({ Name = "Degrau", Size = V3(4, 0.5, 1.6), Color = { 130, 125, 118 }, Material = "Cobblestone" }, CF(0, 0.25, -D / 2 - 1.2))
	-- Janelas (acendem à noite)
	local windows = {
		CF(-4.3, 6.2, -D / 2 - 0.15), CF(4.3, 6.2, -D / 2 - 0.15),
		CF(-W / 2 - 0.15, 6.2, 0) * CFrame.Angles(0, rad(90), 0),
		CF(W / 2 + 0.15, 6.2, 0) * CFrame.Angles(0, rad(90), 0),
	}
	for i, offset in windows do
		p({ Name = "Janela", Size = V3(2.4, 2.4, 0.2), Color = { 255, 205, 120 }, Material = "SmoothPlastic", Tags = { "NightLight" } }, offset)
		p({ Name = "Moldura", Size = V3(2.9, 0.3, 0.35), Color = wood, Material = "Wood" }, offset * CF(0, 1.3, 0))
		p({ Name = "Moldura", Size = V3(2.9, 0.3, 0.35), Color = wood, Material = "Wood" }, offset * CF(0, -1.3, 0))
		p({ Name = "Cruz", Size = V3(0.2, 2.4, 0.3), Color = wood, Material = "Wood" }, offset)
		p({ Name = "Cruz", Size = V3(2.4, 0.2, 0.3), Color = wood, Material = "Wood" }, offset)
		if i <= 2 then
			-- Floreira embaixo da janela
			p({ Name = "Floreira", Size = V3(2.8, 0.6, 0.8), Color = { 110, 70, 40 }, Material = "Wood" }, offset * CF(0, -1.75, -0.4))
			for k = -1, 1 do
				p({ Name = "Flor", Shape = "Ball", Size = V3(0.6, 0.6, 0.6), Color = pick({ { 255, 90, 110 }, { 255, 220, 80 }, { 200, 120, 255 } }), Material = "SmoothPlastic", CanCollide = false },
					offset * CF(k * 0.8, -1.25, -0.4))
			end
		end
	end
	-- Telhado de duas águas
	local hd, angle = D / 2 + 1, rad(35)
	local slope = hd / math.cos(angle)
	local ridge = hd * math.tan(angle)
	p({ Name = "Telhado", Size = V3(W + 2.4, 0.7, slope + 0.4), Color = roofColor, Material = "Slate" },
		CF(0, 1 + H + ridge / 2, -hd / 2) * CFrame.Angles(-angle, 0, 0))
	p({ Name = "Telhado", Size = V3(W + 2.4, 0.7, slope + 0.4), Color = roofColor, Material = "Slate" },
		CF(0, 1 + H + ridge / 2, hd / 2) * CFrame.Angles(angle, 0, 0))
	p({ Name = "Cumeeira", Size = V3(W + 2.6, 0.6, 0.9), Color = { 60, 45, 35 }, Material = "Wood" }, CF(0, 1 + H + ridge + 0.1, 0))
	-- Oitões (triângulos das laterais)
	local gable = (D / 2) * math.tan(angle)
	for _, side in { -1, 1 } do
		p({ Class = "WedgePart", Name = "Oitao", Size = V3(0.8, gable, D / 2), Color = wall, Material = "Concrete" },
			CF(side * (W / 2 - 0.4), 1 + H + gable / 2, -D / 4))
		p({ Class = "WedgePart", Name = "Oitao", Size = V3(0.8, gable, D / 2), Color = wall, Material = "Concrete" },
			CF(side * (W / 2 - 0.4), 1 + H + gable / 2, D / 4) * CFrame.Angles(0, math.pi, 0))
	end
	-- Chaminé com fumaça
	local chimney = p({ Name = "Chamine", Size = V3(1.8, 6, 1.8), Color = { 140, 80, 60 }, Material = "Brick" }, CF(W / 2 - 3, 1 + H + 3.5, 2.5))
	local smoke = Instance.new("Smoke")
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 3
	smoke.Size = 2.5
	smoke.Color = lib.rgb(220, 220, 220)
	smoke.Parent = chimney
	-- Lanterna na porta
	local lantern = p({ Name = "Lanterna", Size = V3(0.7, 0.9, 0.7), Color = { 255, 200, 120 }, Material = "Neon", Tags = { "NightLight" } }, CF(-2.3, 6.2, -D / 2 - 0.6))
	lib.light(lantern, { Color = lib.rgb(255, 190, 110), Range = 14, Brightness = 1.2 }, { "NightLight" })
	block(position.X, position.Z, 13)
	return model
end

local function marketStall(parent, position, yaw: number, colorA, colorB, goods)
	local model = lib.model(parent, "Barraca")
	local base = CF(position) * CFrame.Angles(0, rad(yaw), 0)
	local wood = { 120, 80, 45 }
	local function p(props, offset)
		props.CFrame = base * offset
		return lib.part(model, props)
	end
	for _, x in { -3.6, 3.6 } do
		for _, z in { -2, 2 } do
			p({ Name = "Poste", Size = V3(0.4, z < 0 and 6 or 7, 0.4), Color = wood, Material = "Wood" }, CF(x, z < 0 and 3 or 3.5, z))
		end
	end
	p({ Name = "Balcao", Size = V3(7.4, 2.6, 2.2), Color = wood, Material = "WoodPlanks" }, CF(0, 1.3, -1.4))
	-- Toldo listrado
	for i = 0, 7 do
		p({
			Name = "Toldo",
			Size = V3(1, 0.15, 5.4),
			Color = i % 2 == 0 and colorA or colorB,
			Material = "Fabric",
		}, CF(-3.5 + i, 6.75, -0.1) * CFrame.Angles(rad(-10), 0, 0))
	end
	for i = 0, 7 do
		p({ Class = "WedgePart", Name = "Franja", Size = V3(1, 0.7, 0.15), Color = i % 2 == 0 and colorA or colorB, Material = "Fabric" },
			CF(-3.5 + i, 5.95, -2.85) * CFrame.Angles(0, 0, math.pi))
	end
	-- Mercadorias
	for i = 1, 9 do
		p({
			Name = "Fruta",
			Shape = "Ball",
			Size = V3(0.7, 0.7, 0.7),
			Color = pick(goods),
			Material = "SmoothPlastic",
			CanCollide = false,
		}, CF(rand(-3, 3), 2.95, rand(-2.1, -0.8)))
	end
	p({ Name = "Barril", Shape = "Cylinder", Size = V3(2, 1.8, 1.8), Color = { 110, 70, 40 }, Material = "Wood" }, CF(4.8, 1, 1) * CFrame.Angles(0, 0, rad(90)))
	p({ Name = "Caixa", Size = V3(1.6, 1.6, 1.6), Color = { 150, 110, 65 }, Material = "WoodPlanks" }, CF(-4.8, 0.8, 0.8) * CFrame.Angles(0, rad(20), 0))
	return model
end

-- Varal de bandeirinhas entre dois pontos (com curva)
local function bunting(parent, a, b, colors)
	local model = lib.model(parent, "Bandeirinhas")
	local count = math.floor((b - a).Magnitude / 3.2)
	local points = {}
	for i = 0, count do
		local t = i / count
		local point = a:Lerp(b, t) - V3(0, math.sin(t * math.pi) * 3.5, 0)
		table.insert(points, point)
	end
	for i = 1, #points - 1 do
		local p0, p1 = points[i], points[i + 1]
		lib.part(model, {
			Name = "Corda",
			Size = V3(0.08, 0.08, (p1 - p0).Magnitude),
			CFrame = CFrame.lookAt((p0 + p1) / 2, p1),
			Color = { 240, 235, 220 },
			Material = "Fabric",
			CanCollide = false,
			CastShadow = false,
		})
		local mid = (p0 + p1) / 2
		local direction = (p1 - p0).Unit
		local flat = V3(direction.X, 0, direction.Z).Unit
		lib.part(model, {
			Class = "WedgePart",
			Name = "Bandeira",
			Size = V3(0.05, 1.4, 1.2),
			CFrame = CFrame.lookAt(mid, mid + flat) * CF(0, -0.75, 0) * CFrame.Angles(0, 0, math.pi),
			Color = colors[(i % #colors) + 1],
			Material = "Fabric",
			CanCollide = false,
			CastShadow = false,
		})
	end
	return model
end

local function emitter(parent, name, size: any, position, props)
	local holder = lib.part(parent, {
		Name = name,
		Size = size,
		CFrame = CF(position),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local particles = Instance.new("ParticleEmitter")
	particles.Shape = Enum.ParticleEmitterShape.Box
	for key, value in props do
		particles[key] = value
	end
	particles.Parent = holder
	return holder
end

local NS, NR, CS = lib.NumberSequence, lib.NumberRange, lib.ColorSequence

local function buildVillageExtras(world)
	local vila = world:FindFirstChild("Vila")
	local houses = lib.folder(vila, "Casas")
	local roofs = { { 165, 60, 45 }, { 60, 85, 135 }, { 70, 115, 70 }, { 120, 75, 50 } }
	local walls = { { 238, 228, 205 }, { 230, 215, 190 }, { 240, 232, 215 } }
	local spots = {
		{ V3(-95, 0, -42), 90 }, { V3(-95, 0, 42), 90 }, { V3(95, 0, -42), -90 }, { V3(95, 0, 42), -90 },
		{ V3(-42, 0, 96), 0 }, { V3(42, 0, 96), 0 }, { V3(-46, 0, -96), 180 }, { V3(46, 0, -96), 180 },
	}
	for i, spot in spots do
		house(houses, spot[1], spot[2], roofs[(i - 1) % #roofs + 1], walls[(i - 1) % #walls + 1])
	end

	local market = lib.folder(vila, "Mercado")
	marketStall(market, V3(-36, 0.5, 30), 90, { 200, 50, 50 }, { 245, 240, 230 }, { { 220, 40, 40 }, { 255, 160, 40 }, { 120, 200, 60 } })
	marketStall(market, V3(36, 0.5, 30), -90, { 50, 90, 190 }, { 245, 240, 230 }, { { 150, 60, 200 }, { 255, 220, 60 }, { 230, 90, 60 } })

	-- Bandeirinhas da espada da fonte até os postes
	local colors = { { 220, 50, 50 }, { 255, 205, 60 }, { 60, 120, 220 }, { 70, 180, 90 }, { 240, 240, 240 } }
	local decor = lib.folder(vila, "Enfeites")
	for _, corner in { V3(54, 10.3, 54), V3(-54, 10.3, 54), V3(54, 10.3, -54), V3(-54, 10.3, -54) } do
		bunting(decor, V3(0, 15, 0) + V3(corner.X, 0, corner.Z).Unit * 3, corner, colors)
	end

	-- Água da fonte
	emitter(decor, "Jato", V3(1, 1, 1), V3(0, 6, 0), {
		Color = CS.new(lib.rgb(200, 235, 255)),
		LightEmission = 0.3,
		Size = NS.new(0.5, 0.15),
		Transparency = NS.new(0.2, 1),
		Lifetime = NR.new(1, 1.4),
		Speed = NR.new(14, 18),
		SpreadAngle = lib.Vector2.new(18, 18),
		Acceleration = V3(0, -30, 0),
		Rate = 70,
		EmissionDirection = Enum.NormalId.Top,
	})
	for i = 0, 3 do
		local a = rad(i * 90 + 45)
		emitter(decor, "JatoBorda", V3(0.5, 0.5, 0.5), V3(math.cos(a) * 10.5, 2.6, math.sin(a) * 10.5), {
			Color = CS.new(lib.rgb(200, 235, 255)),
			Size = NS.new(0.35, 0.1),
			Transparency = NS.new(0.2, 1),
			Lifetime = NR.new(0.8, 1),
			Speed = NR.new(9, 11),
			SpreadAngle = lib.Vector2.new(5, 5),
			Acceleration = V3(-math.cos(a) * 14, -26, -math.sin(a) * 14),
			Rate = 30,
			EmissionDirection = Enum.NormalId.Top,
		})
	end

	-- Estandartes nos cantos da praça
	for _, corner in { V3(57, 0.5, 57), V3(-57, 0.5, 57), V3(57, 0.5, -57), V3(-57, 0.5, -57) } do
		lib.cylinder(decor, { Name = "Mastro", Color = { 60, 45, 35 }, Material = "Wood" }, corner + V3(0, 9, 0), 18, 0.5)
		lib.part(decor, { Name = "PontaMastro", Shape = "Ball", Size = V3(1, 1, 1), CFrame = CF(corner + V3(0, 18.4, 0)), Color = { 230, 190, 70 }, Material = "Metal" })
		lib.part(decor, {
			Name = "Estandarte",
			Size = V3(0.15, 7, 3.4),
			CFrame = CF(corner + V3(0, 13.5, 0)) * CFrame.Angles(0, math.atan2(-corner.X, -corner.Z) + rad(90), 0) * CF(0, 0, 1.9),
			Color = { 170, 30, 40 },
			Material = "Fabric",
		})
	end
end

local function buildLake(world)
	local lake = terrainData.Lake
	local folder = lib.folder(world, "Lago")
	block(lake.X, lake.Z, lake.Radius + 14)
	-- Píer de madeira saindo da margem norte
	local startZ = lake.Z - lake.Radius - 6
	for i = 0, 9 do
		lib.part(folder, {
			Name = "Tabua",
			Size = V3(7, 0.4, 2.6),
			CFrame = CF(lake.X, 0.9, startZ + i * 2.8) * CFrame.Angles(0, rad(rand(-1.5, 1.5)), 0),
			Color = pick({ { 140, 100, 60 }, { 130, 92, 55 }, { 150, 108, 66 } }),
			Material = "WoodPlanks",
		})
	end
	for i = 0, 4 do
		for _, side in { -1, 1 } do
			lib.cylinder(folder, { Name = "Estaca", Color = { 90, 65, 40 }, Material = "Wood" }, V3(lake.X + side * 3.6, -1, startZ + i * 7), 6, 0.6)
		end
	end
	local post = lib.cylinder(folder, { Name = "PosteLanterna", Color = { 60, 45, 35 }, Material = "Wood" }, V3(lake.X + 3, 3.5, startZ + 26), 5, 0.4)
	post.Name = "PosteLanterna"
	local lantern = lib.part(folder, { Name = "Lanterna", Size = V3(0.9, 1.1, 0.9), CFrame = CF(lake.X + 3, 6.5, startZ + 26), Color = { 255, 200, 120 }, Material = "Neon", Tags = { "NightLight" } })
	lib.light(lantern, { Color = lib.rgb(255, 190, 110), Range = 18, Brightness = 1.4 }, { "NightLight" })
	-- Barquinho
	local boat = lib.model(folder, "Barco")
	local boatBase = CF(lake.X + 12, 0.4, lake.Z - 6) * CFrame.Angles(0, rad(30), 0)
	lib.part(boat, { Name = "Fundo", Size = V3(3.4, 0.5, 8), CFrame = boatBase, Color = { 120, 80, 45 }, Material = "WoodPlanks" })
	for _, side in { -1, 1 } do
		lib.part(boat, { Name = "Lateral", Size = V3(0.4, 1.2, 8), CFrame = boatBase * CF(side * 1.8, 0.6, 0), Color = { 140, 95, 55 }, Material = "WoodPlanks" })
	end
	lib.part(boat, { Class = "WedgePart", Name = "Proa", Size = V3(3.4, 1.2, 2.5), CFrame = boatBase * CF(0, 0.6, -5.2) * CFrame.Angles(0, math.pi, 0), Color = { 140, 95, 55 }, Material = "WoodPlanks" })
	lib.part(boat, { Name = "Banco", Size = V3(3.2, 0.3, 1.2), CFrame = boatBase * CF(0, 0.8, 0.5), Color = { 100, 65, 40 }, Material = "Wood" })
	-- Juncos e pedras na margem
	for i = 0, 23 do
		local a = rad(i * 15 + rand(-5, 5))
		local d = lake.Radius + rand(1, 5)
		local x, z = lake.X + math.cos(a) * d, lake.Z + math.sin(a) * d
		if math.abs(x - lake.X) > 6 or z > lake.Z then
			if i % 3 == 0 then
				rock(folder, V3(x, -0.3, z), rand(1.5, 3))
			else
				for k = 0, 2 do
					lib.part(folder, {
						Name = "Junco",
						Size = V3(0.25, rand(2.5, 4), 0.25),
						CFrame = CF(x + rand(-1, 1), 1.2, z + rand(-1, 1)) * CFrame.Angles(rad(rand(-12, 12)), 0, rad(rand(-12, 12))),
						Color = { 90, 130, 60 },
						Material = "Grass",
						CanCollide = false,
					})
				end
			end
		end
	end
end

-- Partículas de ambiente: vagalumes, brasas, névoa
local function buildAmbience(world)
	local folder = lib.folder(world, "Ambiente")
	for _, position in { V3(200, 6, -40), V3(240, 6, 40), V3(290, 6, -60), V3(300, 6, 80), V3(180, 6, 120), V3(330, 6, -130), V3(220, 6, -140), V3(350, 6, 120) } do
		emitter(folder, "Vagalumes", V3(60, 10, 60), position, {
			Color = CS.new(lib.rgb(220, 255, 120)),
			LightEmission = 1,
			Size = NS.new(0.22),
			Transparency = NS.new({ lib.NumberSequenceKeypoint.new(0, 1), lib.NumberSequenceKeypoint.new(0.3, 0), lib.NumberSequenceKeypoint.new(0.7, 0.1), lib.NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NR.new(4, 7),
			Speed = NR.new(0.4, 1.2),
			SpreadAngle = lib.Vector2.new(180, 180),
			Rate = 6,
			RotSpeed = NR.new(-20, 20),
		})
	end
	emitter(folder, "Brasas", V3(80, 2, 80), V3(-265, 2, 0), {
		Color = CS.new(lib.rgb(255, 120, 40), lib.rgb(255, 40, 40)),
		LightEmission = 1,
		Size = NS.new(0.25, 0),
		Transparency = NS.new(0, 1),
		Lifetime = NR.new(3, 5),
		Speed = NR.new(3, 6),
		SpreadAngle = lib.Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top,
		Rate = 22,
	})
	emitter(folder, "Nevoa", V3(110, 2, 110), V3(-265, 3, 0), {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = CS.new(lib.rgb(90, 50, 110)),
		Size = NS.new(10, 18),
		Transparency = NS.new({ lib.NumberSequenceKeypoint.new(0, 1), lib.NumberSequenceKeypoint.new(0.5, 0.85), lib.NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NR.new(8, 12),
		Speed = NR.new(0.5, 1.5),
		SpreadAngle = lib.Vector2.new(180, 10),
		Rate = 4,
		RotSpeed = NR.new(-10, 10),
	})
	emitter(folder, "Petalas", V3(120, 4, 120), V3(0, 24, 0), {
		Color = CS.new(lib.rgb(255, 190, 210), lib.rgb(255, 240, 245)),
		Size = NS.new(0.3),
		Lifetime = NR.new(6, 9),
		Speed = NR.new(0, 0.5),
		Acceleration = V3(1.5, -2.5, 0.8),
		SpreadAngle = lib.Vector2.new(180, 180),
		RotSpeed = NR.new(-60, 60),
		Rotation = NR.new(0, 360),
		Rate = 8,
	})
end

--------------------------------------------------------------------------
function map.build(game)
	local workspace = game:GetService("Workspace")
	local server = {
		Zones = lib.folder(workspace, "Zones"),
		NPCSpawns = lib.folder(workspace, "NPCSpawns"),
	}
	lib.folder(workspace, "NPCs")
	local world = lib.folder(workspace, "Mapa")

	buildTerrain(world)
	buildVillage(world, server)
	buildPaths(world)
	buildArena(world, server)
	buildForest(world, server)
	buildRuins(world, server)
	buildVillageExtras(world)
	buildLake(world)
	generateRelief()
	buildFields(world)
	buildAmbience(world)
	return terrainModule()
end

return map
