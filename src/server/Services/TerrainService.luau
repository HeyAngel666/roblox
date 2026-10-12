--[[
	TerrainService
	Cria o terreno de verdade quando o jogo começa:
	  - chão de grama com grama animada
	  - morros suaves, montanhas com neve em volta do mapa
	  - lago com margem de areia
	  - floresta com folhagem, areia em volta da arena, lava perto das ruínas
	Os números vêm de ServerStorage.TerrainData (gerado pelo build).
	O chão de peças (Mapa.Terreno.Chao) é removido depois que o terreno fica pronto.
]]

local ServerStorage = game:GetService("ServerStorage")

local TerrainService = {}

local M = Enum.Material

-- Cume: duas cunhas costas com costas (prisma triangular)
local function ridge(terrain: Terrain, base: CFrame, width: number, height: number, depth: number, material)
	local size = Vector3.new(width, height, depth)
	terrain:FillWedge(base * CFrame.new(0, height / 2, -depth / 2), size, material)
	terrain:FillWedge(base * CFrame.new(0, height / 2, depth / 2) * CFrame.Angles(0, math.pi, 0), size, material)
end

-- Montanha: 3 cumes cruzados formam um pico; o topo recebe neve
local function mountain(terrain: Terrain, x: number, z: number, r: number, snow: boolean)
	local height = r * 1.15
	for i = 0, 2 do
		local yaw = math.rad(i * 60 + (x + z) % 30)
		local base = CFrame.new(x, -4, z) * CFrame.Angles(0, yaw, 0)
		ridge(terrain, base, r * (2.1 - i * 0.35), height * (1 - i * 0.08), r, M.Rock)
	end
	-- Pico secundário ao lado
	local side = CFrame.new(x, -4, z) * CFrame.Angles(0, math.rad((x * 7) % 360), 0) * CFrame.new(r * 0.75, 0, 0)
	ridge(terrain, side, r * 1.2, height * 0.6, r * 0.65, M.Rock)
	if snow then
		local top = height * 0.3
		for i = 0, 2 do
			local yaw = math.rad(i * 60 + (x + z) % 30)
			local fullHeight = height * (1 - i * 0.08)
			local scaleTop = top / fullHeight
			local base = CFrame.new(x, -4 + fullHeight - top, z) * CFrame.Angles(0, yaw, 0)
			ridge(terrain, base, r * (2.1 - i * 0.35) * scaleTop + 2, top + 1, r * scaleTop + 1, M.Snow)
		end
	end
end

local function cylinder(terrain: Terrain, x: number, y: number, z: number, height: number, radius: number, material)
	terrain:FillCylinder(CFrame.new(x, y, z), height, radius, material)
end

function TerrainService.Init()
	local terrain = workspace.Terrain
	local ok, data = pcall(require, ServerStorage:WaitForChild("TerrainData"))
	if not ok then
		warn("[TerrainService] TerrainData não encontrado: " .. tostring(data))
		return
	end

	local success, err = pcall(function()
		-- Cores dos materiais
		terrain:SetMaterialColor(M.Grass, Color3.fromRGB(98, 150, 72))
		terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(64, 105, 52))
		terrain:SetMaterialColor(M.Rock, Color3.fromRGB(112, 108, 104))
		terrain:SetMaterialColor(M.Ground, Color3.fromRGB(92, 78, 64))
		terrain:SetMaterialColor(M.Sand, Color3.fromRGB(222, 204, 156))
		terrain:SetMaterialColor(M.Snow, Color3.fromRGB(240, 245, 252))

		-- Chão base (topo exatamente em y = 0)
		terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(1120, 16, 1120), M.Grass)

		-- Floresta
		terrain:FillBlock(CFrame.new(265, -2, 0), Vector3.new(240, 4, 352), M.LeafyGrass)
		-- Areia em volta da arena e chão escuro nas ruínas
		cylinder(terrain, 0, -2, -230, 4, 96, M.Sand)
		cylinder(terrain, -265, -2, 0, 4, 88, M.Ground)
		for _, patch in data.Patches do
			cylinder(terrain, patch[1], -2, patch[2], 4, patch[3], M[patch[4]] or M.CrackedLava)
		end

		-- Lago
		local lake = data.Lake
		cylinder(terrain, lake.X, -2, lake.Z, 4, lake.Radius + 7, M.Sand)
		cylinder(terrain, lake.X, -5, lake.Z, 12, lake.Radius, M.Air)
		cylinder(terrain, lake.X, -14, lake.Z, 6, lake.Radius + 2, M.Sand)
		local size = lake.Radius + 8
		local region = Region3.new(
			Vector3.new(lake.X - size, -12, lake.Z - size),
			Vector3.new(lake.X + size, 0, lake.Z + size)
		):ExpandToGrid(4)
		terrain:ReplaceMaterial(region, 4, M.Air, M.Water)

		-- Morros
		for _, hill in data.Hills do
			terrain:FillBall(Vector3.new(hill[1], hill[2], hill[3]), hill[4], M.Grass)
		end

		-- Montanhas com neve
		for _, peak in data.Mountains do
			mountain(terrain, peak[1], peak[3], peak[4], peak[5])
		end
	end)

	if not success then
		warn("[TerrainService] Erro ao criar o terreno: " .. tostring(err))
		return
	end

	-- Terreno pronto: remove o chão provisório de peças
	local mapa = workspace:FindFirstChild("Mapa")
	local base = mapa and mapa:FindFirstChild("Terreno")
	local floor = base and base:FindFirstChild("Chao")
	if floor then
		floor:Destroy()
	end
	local forest = mapa and mapa:FindFirstChild("FlorestaSombria")
	local forestFloor = forest and forest:FindFirstChild("ChaoFloresta")
	if forestFloor then
		forestFloor:Destroy()
	end
end

return TerrainService
