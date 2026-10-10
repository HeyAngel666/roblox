--[[
	CombatController
	Controles do jogador:
	  Clique / Toque  = Atacar (combo de 3 golpes)
	  F               = Bloquear (segurar) — bloqueie na hora certa para PARRY
	  Q               = Esquiva
	  R               = Habilidade especial da espada
	No celular aparecem botões na tela. No controle: L2, B e Y.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local C = Config.Combat

local CombatController = {}

local currentTool: Tool? = nil
local toolConnection: RBXScriptConnection? = nil
local blocking = false
local lastDash = 0

local function getCharacterParts()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function setBlocking(state: boolean)
	if state and not currentTool then
		return
	end
	if blocking == state then
		return
	end
	blocking = state
	Remotes.Block:FireServer(state)
end

local function dash()
	local character, humanoid, root = getCharacterParts()
	if not character or not humanoid or not root then
		return
	end
	local now = os.clock()
	if now - lastDash < C.DashCooldown or blocking or character:GetAttribute("Stunned") then
		return
	end
	if (player:GetAttribute("Stamina") or 0) < C.DashCost then
		return
	end
	lastDash = now

	local direction = humanoid.MoveDirection
	if direction.Magnitude < 0.1 then
		direction = root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.01 then
		return
	end
	direction = direction.Unit

	Remotes.Dash:FireServer()

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * C.DashSpeed
	velocity.MaxForce = math.huge
	velocity.Parent = root

	task.delay(C.DashDuration, function()
		velocity:Destroy()
		attachment:Destroy()
	end)
end

local function special()
	local character = getCharacterParts()
	if not character or not currentTool or blocking then
		return
	end
	Remotes.Special:FireServer()
end

local function watchTool(tool: Tool)
	if not tool:GetAttribute("SwordId") then
		return
	end
	currentTool = tool
	if toolConnection then
		toolConnection:Disconnect()
	end
	toolConnection = tool.Activated:Connect(function()
		if not blocking then
			Remotes.Attack:FireServer()
		end
	end)
end

local function onCharacterAdded(character: Model)
	currentTool = nil
	blocking = false
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			watchTool(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child == currentTool then
			currentTool = nil
			if toolConnection then
				toolConnection:Disconnect()
				toolConnection = nil
			end
			if blocking then
				setBlocking(false)
			end
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			watchTool(child)
		end
	end
end

function CombatController.Init()
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	ContextActionService:BindAction("SwordBlock", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			setBlocking(true)
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			setBlocking(false)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)

	ContextActionService:BindAction("SwordDash", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			dash()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

	ContextActionService:BindAction("SwordSpecial", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			special()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

	-- Botões de celular
	ContextActionService:SetTitle("SwordBlock", "Bloq")
	ContextActionService:SetTitle("SwordDash", "Esquiva")
	ContextActionService:SetTitle("SwordSpecial", "Especial")
	ContextActionService:SetPosition("SwordBlock", UDim2.new(1, -170, 1, -150))
	ContextActionService:SetPosition("SwordDash", UDim2.new(1, -230, 1, -95))
	ContextActionService:SetPosition("SwordSpecial", UDim2.new(1, -115, 1, -205))

	Remotes.Knockback.OnClientEvent:Connect(function(velocity)
		if typeof(velocity) ~= "Vector3" then
			return
		end
		local _, _, root = getCharacterParts()
		if root then
			(root :: BasePart).AssemblyLinearVelocity = velocity
		end
	end)
end

return CombatController
