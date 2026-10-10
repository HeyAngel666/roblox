--[[
	Funções utilitárias compartilhadas (servidor e cliente)
]]

local Util = {}

function Util.Color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Formata número com separador de milhar: 12500 -> "12.500"
function Util.FormatNumber(value: number): string
	local text = tostring(math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if result:sub(1, 1) == "." then
		result = result:sub(2)
	end
	return result
end

-- Encontra o modelo (personagem/NPC) que possui Humanoid a partir de uma peça
function Util.GetCharacterFromPart(part: Instance): Model?
	local current = part.Parent
	while current and current ~= workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return current
		end
		current = current.Parent
	end
	return nil
end

function Util.GetHumanoid(model: Instance?): Humanoid?
	if not model then
		return nil
	end
	return model:FindFirstChildOfClass("Humanoid")
end

function Util.GetRoot(model: Instance?): BasePart?
	if not model then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function Util.IsAlive(model: Instance?): boolean
	local humanoid = Util.GetHumanoid(model)
	return humanoid ~= nil and humanoid.Health > 0 and Util.GetRoot(model) ~= nil
end

return Util
