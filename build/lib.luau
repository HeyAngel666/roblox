--[[
	Funções auxiliares do build (roda no Lune, fora do Roblox).
]]

local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local lib = {}

lib.Instance = Instance
lib.Vector3 = Vector3
lib.CFrame = CFrame
lib.Color3 = Color3
lib.Enum = Enum
lib.UDim2 = roblox.UDim2
lib.UDim = roblox.UDim
lib.Vector2 = roblox.Vector2
lib.ColorSequence = roblox.ColorSequence
lib.NumberSequence = roblox.NumberSequence
lib.NumberRange = roblox.NumberRange
lib.ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
lib.NumberSequenceKeypoint = roblox.NumberSequenceKeypoint

function lib.rgb(r: any, g: number?, b: number?)
	if type(r) == "table" then
		return Color3.fromRGB(r[1], r[2], r[3])
	end
	return Color3.fromRGB(r, g, b)
end

function lib.new(className: string, props: { [string]: any }?, parent: any?)
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			inst[key] = value
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

-- Cria uma peça. props aceita Material como string ("Grass") e Color como {r,g,b}
function lib.part(parent: any, props: { [string]: any })
	local className = props.Class or "Part"
	local part = Instance.new(className)
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key == "Class" or key == "Tags" or key == "Attributes" then
			continue
		elseif key == "Material" and type(value) == "string" then
			part.Material = Enum.Material[value]
		elseif key == "Color" and type(value) == "table" then
			part.Color = lib.rgb(value)
		elseif key == "Shape" and type(value) == "string" then
			part.Shape = Enum.PartType[value]
		else
			part[key] = value
		end
	end
	if props.Tags then
		for _, tag in props.Tags do
			part:AddTag(tag)
		end
	end
	if props.Attributes then
		for name, value in props.Attributes do
			part:SetAttribute(name, value)
		end
	end
	part.Parent = parent
	return part
end

-- Cilindro em pé (o eixo do cilindro no Roblox é o X, então giramos 90°)
function lib.cylinder(parent: any, props: { [string]: any }, position: any, height: number, diameter: number)
	props.Shape = "Cylinder"
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return lib.part(parent, props)
end

function lib.folder(parent: any, name: string)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function lib.model(parent: any, name: string)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Solda p1 em p0 mantendo a posição atual
function lib.weld(p0: any, p1: any, name: string?)
	local weld = Instance.new("Weld")
	weld.Name = name or "Weld"
	weld.Part0 = p0
	weld.Part1 = p1
	weld.C0 = p0.CFrame:Inverse() * p1.CFrame
	weld.C1 = CFrame.new()
	weld.Parent = p1
	return weld
end

-- Move todas as peças de um modelo construído na origem
function lib.transform(root: any, cframe: any)
	local list = root:GetDescendants()
	if root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, inst in list do
		if inst:IsA("BasePart") then
			inst.CFrame = cframe * inst.CFrame
		end
	end
end

function lib.light(parent: any, props: { [string]: any }, tags: { string }?)
	local light = lib.new(props.Class or "PointLight", nil)
	for key, value in props do
		if key ~= "Class" then
			light[key] = value
		end
	end
	if tags then
		for _, tag in tags do
			light:AddTag(tag)
		end
	end
	light.Parent = parent
	return light
end

-- SurfaceGui com um texto simples
function lib.sign(part: any, face: string, text: string, color: any?, background: any?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId[face]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = lib.UDim2.fromScale(1, 1)
	label.BackgroundTransparency = background and 0 or 1
	if background then
		label.BackgroundColor3 = background
	end
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color or Color3.fromRGB(255, 220, 120)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = lib.UDim.new(0.05, 0)
	padding.PaddingRight = lib.UDim.new(0.05, 0)
	padding.PaddingTop = lib.UDim.new(0.1, 0)
	padding.PaddingBottom = lib.UDim.new(0.1, 0)
	padding.Parent = label
	return gui
end

return lib
