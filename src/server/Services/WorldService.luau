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
		local isNight = Lighting.ClockTime < 6.3 or Lighting.ClockTime > 17.7
		if isNight ~= wasNight then
			wasNight = isNight
			setTorches(isNight)
		end
	end)
end

return WorldService
