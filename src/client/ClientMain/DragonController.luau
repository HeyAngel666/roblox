--[[
	DragonController
	Anima os dragões que voam pelo céu (só visual, roda em cada cliente):
	  - voo em círculo com subida/descida e inclinação nas curvas
	  - bater de asas, pescoço e cauda ondulando
	  - de tempos em tempos abre a boca e solta fogo
	Todos os jogadores veem o dragão no mesmo lugar porque a posição é
	calculada a partir do relógio do servidor.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DragonController = {}

local BREATH_EVERY = 16 -- segundos entre cada sopro
local BREATH_TIME = 3.2

type Dragon = {
	Model: Model,
	Root: BasePart,
	Joints: { [string]: Motor6D },
	Center: Vector3,
	Radius: number,
	Altitude: number,
	Speed: number,
	Phase: number,
	Direction: number,
	FlapSpeed: number,
	Breath: ParticleEmitter?,
	BreathLight: Light?,
	Breathing: boolean,
}

local dragons: { Dragon } = {}

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return
	end
	local joints = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			joints[descendant.Name] = descendant
		end
	end
	local breath = model:FindFirstChild("SoproDeFogo", true)
	local light = model:FindFirstChild("LuzDoFogo", true)
	table.insert(dragons, {
		Model = model,
		Root = root,
		Joints = joints,
		Center = model:GetAttribute("Center") or Vector3.zero,
		Radius = model:GetAttribute("Radius") or 100,
		Altitude = model:GetAttribute("Altitude") or 80,
		Speed = model:GetAttribute("Speed") or 30,
		Phase = model:GetAttribute("Phase") or 0,
		Direction = model:GetAttribute("Direction") or 1,
		FlapSpeed = model:GetAttribute("FlapSpeed") or 2.4,
		Breath = breath and breath:IsA("ParticleEmitter") and breath or nil,
		BreathLight = light and light:IsA("Light") and light or nil,
		Breathing = false,
	})
end

local function setJoint(dragon: Dragon, name: string, cframe: CFrame)
	local joint = dragon.Joints[name]
	if joint then
		joint.Transform = cframe
	end
end

local function update(dragon: Dragon, t: number)
	if not dragon.Root.Parent then
		return
	end
	local angular = dragon.Speed / dragon.Radius
	local angle = dragon.Phase + t * angular * dragon.Direction
	local flap = t * dragon.FlapSpeed + dragon.Phase * 3

	-- Trajetória
	local wave = math.sin(t * 0.35 + dragon.Phase)
	local position = dragon.Center
		+ Vector3.new(
			math.cos(angle) * dragon.Radius,
			dragon.Altitude + wave * 10 - math.sin(flap) * 1.2,
			math.sin(angle) * dragon.Radius
		)
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * dragon.Direction
	local climb = math.cos(t * 0.35 + dragon.Phase) * 0.35 * 10 / dragon.Speed
	local bank = -0.28 * dragon.Direction
	dragon.Root.CFrame = CFrame.lookAt(position, position + tangent + Vector3.new(0, climb, 0))
		* CFrame.Angles(0, 0, bank)

	-- Asas (L = esquerda, R = direita)
	local upper = math.sin(flap) * 0.62 + 0.12
	local lower = math.sin(flap - 0.8) * 0.45 + 0.05
	local sweep = math.cos(flap) * 0.08
	setJoint(dragon, "WingL1", CFrame.Angles(0, sweep, -upper))
	setJoint(dragon, "WingL2", CFrame.Angles(0, 0, -lower))
	setJoint(dragon, "WingR1", CFrame.Angles(0, -sweep, upper))
	setJoint(dragon, "WingR2", CFrame.Angles(0, 0, lower))

	-- Pescoço e cabeça
	local look = math.sin(t * 0.5 + dragon.Phase) * 0.12
	for i = 1, 3 do
		setJoint(dragon, "Neck" .. i, CFrame.Angles(math.sin(t * 0.8 + i * 0.5) * 0.05, look * 0.6, 0))
	end
	setJoint(dragon, "Head", CFrame.Angles(math.sin(t * 0.9) * 0.08, look, 0))

	-- Cauda ondulando
	for i = 1, 5 do
		setJoint(
			dragon,
			"Tail" .. i,
			CFrame.Angles(math.sin(t * 1.4 - i * 0.6) * 0.05, math.sin(t * 1.1 - i * 0.7) * 0.13, 0)
		)
	end

	-- Sopro de fogo
	local cycle = (t + dragon.Phase * 37) % BREATH_EVERY
	local breathing = cycle < BREATH_TIME
	local jaw = 0
	if breathing then
		jaw = math.min(cycle / 0.3, 1, (BREATH_TIME - cycle) / 0.3) * 0.45
	end
	setJoint(dragon, "Jaw", CFrame.Angles(-jaw, 0, 0))
	if breathing ~= dragon.Breathing then
		dragon.Breathing = breathing
		if dragon.Breath then
			dragon.Breath.Enabled = breathing
		end
		if dragon.BreathLight then
			dragon.BreathLight.Enabled = breathing
		end
	end
end

function DragonController.Init()
	for _, model in CollectionService:GetTagged("Dragon") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("Dragon"):Connect(register)

	RunService.Stepped:Connect(function()
		local t = workspace:GetServerTimeNow()
		for _, dragon in dragons do
			update(dragon, t)
		end
	end)
end

-- Usado pela câmera do menu inicial
function DragonController.GetDragons(): { Dragon }
	return dragons
end

return DragonController
