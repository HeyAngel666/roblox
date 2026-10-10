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
local Config = require("../src/shared/Config")

local Instance, Enum = lib.Instance, lib.Enum

local OUTPUT = "LaminasDoReino.rbxlx"
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

-- Iluminação
Lighting.ClockTime = 13
Lighting.Brightness = 2.5
Lighting.Ambient = lib.rgb(70, 70, 82)
Lighting.OutdoorAmbient = lib.rgb(125, 125, 135)
Lighting.GlobalShadows = true
Lighting.Technology = Enum.Technology.ShadowMap
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.5
lib.new("Atmosphere", {
	Density = 0.3,
	Offset = 0.2,
	Color = lib.rgb(199, 205, 220),
	Decay = lib.rgb(106, 112, 125),
	Glare = 0.3,
	Haze = 1.2,
}, Lighting)
lib.new("Sky", { Name = "Ceu" }, Lighting)
lib.new("BloomEffect", { Intensity = 0.5, Size = 24, Threshold = 1.5 }, Lighting)
lib.new("ColorCorrectionEffect", { Saturation = 0.12, Contrast = 0.08, Brightness = 0.02 }, Lighting)
lib.new("SunRaysEffect", { Intensity = 0.06, Spread = 0.8 }, Lighting)

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

local clientMain = addScript(starterPlayerScripts, "LocalScript", "ClientMain", "src/client/ClientMain/init.client.luau")
addModulesFrom(clientMain, "src/client/ClientMain", "init.client.luau")

--------------------------------------------------------------------------
-- Mapa
--------------------------------------------------------------------------
map.build(game)

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
fs.writeFile(OUTPUT, roblox.serializePlace(game, true))

local parts = 0
for _, instance in game:GetDescendants() do
	if instance:IsA("BasePart") then
		parts += 1
	end
end
print(("OK! %s gerado (%d peças)."):format(OUTPUT, parts))
