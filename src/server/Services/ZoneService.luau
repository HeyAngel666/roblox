--[[
	ZoneService
	Descobre em qual zona do mapa cada jogador está (Vila, Arena, Floresta...)
	As zonas são peças invisíveis dentro de Workspace.Zones com o atributo
	"Zone" (nome) e "Safe" (true = sem PvP).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ZoneService = {}

local zoneParts: { BasePart } = {}

local function pointInPart(part: BasePart, point: Vector3): boolean
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
end

function ZoneService.GetZoneAt(position: Vector3): (string, boolean)
	for _, part in zoneParts do
		if pointInPart(part, position) then
			return part:GetAttribute("Zone") or Config.DefaultZone, part:GetAttribute("Safe") == true
		end
	end
	return Config.DefaultZone, false
end

function ZoneService.IsSafe(player: Player): boolean
	return player:GetAttribute("Safe") == true
end

function ZoneService.IsPositionSafe(position: Vector3): boolean
	local _, safe = ZoneService.GetZoneAt(position)
	return safe
end

function ZoneService.Init()
	local folder = workspace:WaitForChild("Zones")
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(zoneParts, child)
		end
	end
	-- zonas menores primeiro (para zonas dentro de zonas)
	table.sort(zoneParts, function(a, b)
		return a.Size.Magnitude < b.Size.Magnitude
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local zone, safe = ZoneService.GetZoneAt(root.Position)
					if player:GetAttribute("Zone") ~= zone then
						player:SetAttribute("Zone", zone)
					end
					if player:GetAttribute("Safe") ~= safe then
						player:SetAttribute("Safe", safe)
					end
				end
			end
			task.wait(0.3)
		end
	end)
end

return ZoneService
