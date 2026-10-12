--[[
	Gera o arquivo do jogo: SwordGame.rbxlx
	Uso (na raiz do projeto):  lune run build/build.luau
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local lib = require("./lib")
local swords = require("./swords")
local characters = require("./characters")
local map = require("./map")
local dragons = require("./dragons")
local Config = require("../src/shared/Config")

local Instance, Enum = lib.Instance, lib.Enum

local OUTPUT = "LaminasDoReino.rbxl"
local SOURCE_ATTRIBUTE = "__SourcePath"

local game = Instance.new("DataModel")

--------------------------------------------------------------------------
-- Scripts
--------------------------------------------------------------------------
local function addScript(parent, className: string, name: string, path: string)
	local source = fs.readFile(path)
	-- Valida a sintaxe antes de montar o arquivo
	local ok, err = pcall(luau.compile, source)
	if not ok then
		error(("Erro de sintaxe em %s:\n%s"):format(path, tostring(err)))
	end
	local script = Instance.new(className)
	script.Name = name
	script.Source = source
	script:SetAttribute(SOURCE_ATTRIBUTE, path)
	script.Parent = parent
	return script
end

local function addModulesFrom(parent, directory: string, skip: string?)
	local files = fs.readDir(directory)
	table.sort(files)
	for _, file in files do
		if file ~= skip and file:match("%.luau$") then
			local name = file:gsub("%.luau$", "")
			addScript(parent, "ModuleScript", name, directory .. "/" .. file)
		end
	end
end

--------------------------------------------------------------------------
-- Serviços
--------------------------------------------------------------------------
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
game:GetService("StarterGui")
game:GetService("StarterPack")
game:GetService("SoundService")

Workspace.StreamingEnabled = false
Players.RespawnTime = 4
StarterPlayer.CharacterUseJumpPower = false
StarterPlayer.CharacterJumpHeight = 7.2
StarterPlayer.CharacterWalkSpeed = 16
local starterPlayerScripts = Instance.new("StarterPlayerScripts")
starterPlayerScripts.Parent = StarterPlayer
local starterCharacterScripts = Instance.new("StarterCharacterScripts")
starterCharacterScripts.Parent = StarterPlayer

-- Iluminação (visual mais bonito: luz "Future", névoa, brilho, raios de sol)
Lighting.ClockTime = 14
Lighting.Brightness = 3
Lighting.Ambient = lib.rgb(80, 80, 95)
Lighting.OutdoorAmbient = lib.rgb(135, 135, 150)
Lighting.ColorShift_Top = lib.rgb(255, 245, 225)
Lighting.GlobalShadows = true
Lighting.Technology = Enum.Technology.Future
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.ShadowSoftness = 0.25
lib.new("Atmosphere", {
	Density = 0.33,
	Offset = 0.25,
	Color = lib.rgb(205, 215, 235),
	Decay = lib.rgb(100, 110, 135),
	Glare = 0.4,
	Haze = 1.6,
}, Lighting)
lib.new("Sky", {
	Name = "Ceu",
	SunAngularSize = 14,
	MoonAngularSize = 10,
	StarCount = 4000,
}, Lighting)
lib.new("BloomEffect", { Intensity = 0.7, Size = 28, Threshold = 1.3 }, Lighting)
lib.new("ColorCorrectionEffect", {
	Name = "CorDoDia",
	Saturation = 0.18,
	Contrast = 0.1,
	Brightness = 0.02,
	TintColor = lib.rgb(255, 248, 240),
}, Lighting)
lib.new("SunRaysEffect", { Intensity = 0.08, Spread = 0.7 }, Lighting)
lib.new("DepthOfFieldEffect", { FarIntensity = 0.12, FocusDistance = 120, InFocusRadius = 220, NearIntensity = 0 }, Lighting)

-- Terreno (o relevo é criado pelo servidor; aqui só as configurações)
local terrain = Instance.new("Terrain")
terrain.Decoration = true
terrain.WaterColor = lib.rgb(45, 125, 160)
terrain.WaterReflectance = 0.6
terrain.WaterTransparency = 0.55
terrain.WaterWaveSize = 0.18
terrain.WaterWaveSpeed = 8
terrain.Parent = Workspace
lib.new("Clouds", { Cover = 0.55, Density = 0.65, Color = lib.rgb(255, 255, 255) }, terrain)

--------------------------------------------------------------------------
-- ReplicatedStorage
--------------------------------------------------------------------------
local shared = lib.folder(ReplicatedStorage, "Shared")
addModulesFrom(shared, "src/shared")

local remotes = lib.folder(ReplicatedStorage, "Remotes")
for _, name in {
	"Attack",
	"Block",
	"Dash",
	"Special",
	"Effect",
	"Notify",
	"KillFeed",
	"Knockback",
	"OpenShop",
	"BossBar",
} do
	lib.new("RemoteEvent", { Name = name }, remotes)
end
lib.new("RemoteFunction", { Name = "Shop" }, remotes)

local swordsFolder = lib.folder(ReplicatedStorage, "Swords")
for _, sword in Config.Swords do
	local tool = swords.build(sword, 1)
	tool.Name = sword.Id
	tool.Parent = swordsFolder
end

--------------------------------------------------------------------------
-- ServerStorage: modelos dos inimigos
--------------------------------------------------------------------------
local npcFolder = lib.folder(ServerStorage, "NPCs")
local builders = {
	Goblin = characters.goblin,
	Esqueleto = characters.skeleton,
	Orc = characters.orc,
	ReiCaido = characters.fallenKing,
}
for kind, build in builders do
	local model = build()
	model.Name = kind
	local scale = model:GetAttribute("Scale") or 1
	local sword = Config.SwordById[Config.NPCs[kind].Sword]
	swords.attachToR6(swords.build(sword, scale), model, scale)
	model.Parent = npcFolder
end

--------------------------------------------------------------------------
-- Scripts do servidor e do cliente
--------------------------------------------------------------------------
addScript(ServerScriptService, "Script", "GameServer", "src/server/GameServer.server.luau")
local services = lib.folder(ServerScriptService, "Services")
addModulesFrom(services, "src/server/Services")

addScript(game:GetService("ReplicatedFirst"), "LocalScript", "Carregamento", "src/client/Loading.client.luau")
local clientMain = addScript(starterPlayerScripts, "LocalScript", "ClientMain", "src/client/ClientMain/init.client.luau")
addModulesFrom(clientMain, "src/client/ClientMain", "init.client.luau")

--------------------------------------------------------------------------
-- Mapa
--------------------------------------------------------------------------
local terrainSource = map.build(game)
local terrainData = Instance.new("ModuleScript")
terrainData.Name = "TerrainData"
terrainData.Source = terrainSource
terrainData.Parent = ServerStorage

-- Dragões (modelo do Blender convertido em peças)
local dragonFolder = lib.folder(Workspace, "Dragoes")
local dragonDefs = {
	{ Name = "Ignis", Palette = "red", Scale = 1.5, Center = lib.Vector3.new(0, 0, -110), Radius = 175, Altitude = 95, Speed = 34, Phase = 0.4, Direction = 1, FlapSpeed = 2.3 },
	{ Name = "Verdantis", Palette = "green", Scale = 1.3, Center = lib.Vector3.new(265, 0, 0), Radius = 115, Altitude = 75, Speed = 28, Phase = 2.1, Direction = -1, FlapSpeed = 2.6 },
	{ Name = "Umbra", Palette = "shadow", Scale = 1.75, Center = lib.Vector3.new(-265, 0, 0), Radius = 90, Altitude = 70, Speed = 26, Phase = 4.0, Direction = 1, FlapSpeed = 2.0 },
}
for _, def in dragonDefs do
	local model, triangles = dragons.build(def)
	model.Parent = dragonFolder
	print(("Dragão %s: %d peças"):format(def.Name, triangles))
end

--------------------------------------------------------------------------
-- Sourcemap (usado só para checagem de tipos com luau-lsp)
--------------------------------------------------------------------------
local function sourcemapNode(instance, depth: number)
	local node = {
		name = instance.Name,
		className = instance.ClassName,
	}
	local path = instance:GetAttribute(SOURCE_ATTRIBUTE)
	if path then
		node.filePaths = { path }
	end
	local children = {}
	if not (instance.Name == "Mapa" and instance.Parent and instance.Parent.ClassName == "Workspace") then
		for _, child in instance:GetChildren() do
			table.insert(children, sourcemapNode(child, depth + 1))
		end
	end
	if #children > 0 then
		node.children = children
	end
	return node
end
local sourcemap = sourcemapNode(game, 0)
sourcemap.name = "Game"
fs.writeFile("sourcemap.json", serde.encode("json", sourcemap, false))

for _, instance in game:GetDescendants() do
	if instance:GetAttribute(SOURCE_ATTRIBUTE) then
		instance:SetAttribute(SOURCE_ATTRIBUTE, nil)
	end
end

--------------------------------------------------------------------------
-- Salva
--------------------------------------------------------------------------
fs.writeFile(OUTPUT, roblox.serializePlace(game, false))

local parts = 0
for _, instance in game:GetDescendants() do
	if instance:IsA("BasePart") then
		parts += 1
	end
end
print(("OK! %s gerado (%d peças)."):format(OUTPUT, parts))
