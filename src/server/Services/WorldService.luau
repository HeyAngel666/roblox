--[[
	WorldService
	- Placar "Top do Servidor" na Vila
	- Ciclo de dia e noite
	- Tochas que acendem à noite
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = {}

local function updateLeaderboards()
	local list = {}
	for _, player in Players:GetPlayers() do
		table.insert(list, {
			Name = player.DisplayName,
			Kills = player:GetAttribute("Kills") or 0,
			Level = player:GetAttribute("Level") or 1,
		})
	end
	table.sort(list, function(a, b)
		if a.Kills == b.Kills then
			return a.Level > b.Level
		end
		return a.Kills > b.Kills
	end)

	for _, board in CollectionService:GetTagged("Leaderboard") do
		local rows = board:FindFirstChild("Rows", true)
		if not rows then
			continue
		end
		for i = 1, 10 do
			local row = rows:FindFirstChild("Row" .. i)
			if row and row:IsA("TextLabel") then
				local entry = list[i]
				if entry then
					row.Text = ("%d. %s  -  %d abates  (Nv.%d)"):format(i, entry.Name, entry.Kills, entry.Level)
				else
					row.Text = ("%d. ---"):format(i)
				end
			end
		end
	end
end

local function setTorches(lit: boolean)
	for _, torch in CollectionService:GetTagged("NightLight") do
		if torch:IsA("Light") then
			torch.Enabled = lit
		elseif torch:IsA("BasePart") then
			torch.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
end

-- Cor do céu/ambiente conforme a hora (amanhecer, dia, pôr do sol, noite)
local MOODS = {
	{ Hour = 5.5, Tint = Color3.fromRGB(190, 200, 255), Ambient = Color3.fromRGB(60, 65, 95) },
	{ Hour = 7, Tint = Color3.fromRGB(255, 220, 190), Ambient = Color3.fromRGB(95, 85, 85) },
	{ Hour = 9, Tint = Color3.fromRGB(255, 248, 240), Ambient = Color3.fromRGB(135, 135, 150) },
	{ Hour = 16.5, Tint = Color3.fromRGB(255, 248, 240), Ambient = Color3.fromRGB(135, 135, 150) },
	{ Hour = 18, Tint = Color3.fromRGB(255, 200, 160), Ambient = Color3.fromRGB(120, 95, 95) },
	{ Hour = 19.5, Tint = Color3.fromRGB(190, 200, 255), Ambient = Color3.fromRGB(60, 65, 95) },
}

local function moodAt(hour: number)
	if hour < MOODS[1].Hour or hour >= MOODS[#MOODS].Hour then
		return MOODS[#MOODS].Tint, MOODS[#MOODS].Ambient
	end
	for i = 1, #MOODS - 1 do
		local a, b = MOODS[i], MOODS[i + 1]
		if hour >= a.Hour and hour < b.Hour then
			local alpha = (hour - a.Hour) / (b.Hour - a.Hour)
			return a.Tint:Lerp(b.Tint, alpha), a.Ambient:Lerp(b.Ambient, alpha)
		end
	end
	return MOODS[1].Tint, MOODS[1].Ambient
end

local function applyMood()
	local tint, ambient = moodAt(Lighting.ClockTime)
	local correction = Lighting:FindFirstChild("CorDoDia")
	if correction and correction:IsA("ColorCorrectionEffect") then
		TweenService:Create(correction, TweenInfo.new(1), { TintColor = tint }):Play()
	end
	TweenService:Create(Lighting, TweenInfo.new(1), { OutdoorAmbient = ambient }):Play()
end

function WorldService.Init()
	task.spawn(function()
		while true do
			updateLeaderboards()
			task.wait(5)
		end
	end)

	-- Ciclo dia/noite
	local hoursPerSecond = 24 / (Config.DayLengthMinutes * 60)
	local wasNight = nil
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		Lighting.ClockTime = (Lighting.ClockTime + elapsed * hoursPerSecond) % 24
		elapsed = 0
		applyMood()
		local isNight = Lighting.ClockTime < 6.3 or Lighting.ClockTime > 17.7
		if isNight ~= wasNight then
			wasNight = isNight
			setTorches(isNight)
		end
	end)
end

return WorldService
