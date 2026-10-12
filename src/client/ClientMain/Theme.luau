--[[
	Theme
	Estilo visual da interface (cores, fontes) e funções para criar
	elementos bonitos: painéis com degradê, botões animados, barras, ícones.
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(24, 22, 34),
	PanelDark = Color3.fromRGB(12, 11, 18),
	PanelLight = Color3.fromRGB(44, 40, 60),
	Gold = Color3.fromRGB(255, 205, 85),
	GoldDark = Color3.fromRGB(190, 120, 30),
	Text = Color3.fromRGB(245, 242, 250),
	SubText = Color3.fromRGB(175, 170, 195),
	Health = Color3.fromRGB(90, 225, 110),
	HealthLow = Color3.fromRGB(240, 60, 60),
	Stamina = Color3.fromRGB(255, 200, 60),
	XP = Color3.fromRGB(150, 110, 255),
	Green = Color3.fromRGB(70, 200, 105),
	Blue = Color3.fromRGB(70, 140, 235),
	Red = Color3.fromRGB(215, 60, 70),
	Gray = Color3.fromRGB(95, 92, 110),
}

Theme.Fonts = {
	Title = Enum.Font.LuckiestGuy,
	Bold = Enum.Font.GothamBlack,
	Text = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Number = Enum.Font.FredokaOne,
}

Theme.Rarity = {
	Comum = Color3.fromRGB(185, 185, 195),
	Raro = Color3.fromRGB(70, 155, 255),
	["Épico"] = Color3.fromRGB(185, 95, 255),
	["Lendário"] = Color3.fromRGB(255, 190, 40),
	["Mítico"] = Color3.fromRGB(255, 60, 85),
}

function Theme.make(className: string, properties, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in properties do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if properties.Parent then
		instance.Parent = properties.Parent
	end
	return instance
end

local make = Theme.make

function Theme.tween(instance: Instance, seconds: number, properties, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		properties
	)
	t:Play()
	return t
end

function Theme.corner(parent: Instance, radius: number?)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function Theme.round(parent: Instance)
	return make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = parent })
end

function Theme.gradient(parent: Instance, a: Color3, b: Color3, rotation: number?)
	return make("UIGradient", {
		Color = ColorSequence.new(a, b),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?, golden: boolean?)
	local s = make("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	if golden then
		make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 140)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 110, 35)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 120)),
			}),
			Rotation = 45,
			Parent = s,
		})
	end
	return s
end

function Theme.padding(parent: Instance, all: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		Parent = parent,
	})
end

-- Remove chaves que não são propriedades do Roblox
local function take(properties, key: string)
	local value = properties[key]
	properties[key] = nil
	return value
end

-- Painel escuro com degradê e borda dourada
function Theme.panel(properties, golden: boolean?)
	local className = take(properties, "ClassName") or "Frame"
	local radius = take(properties, "Radius") or 12
	properties.BackgroundColor3 = properties.BackgroundColor3 or Color3.new(1, 1, 1)
	properties.BackgroundTransparency = properties.BackgroundTransparency or 0.08
	properties.BorderSizePixel = 0
	local frame = make(className, properties)
	Theme.corner(frame, radius)
	Theme.gradient(frame, Color3.fromRGB(40, 36, 56), Color3.fromRGB(16, 14, 24), 90)
	Theme.stroke(frame, golden ~= false and Color3.new(1, 1, 1) or Color3.fromRGB(70, 65, 90), 2, golden ~= false)
	return frame
end

function Theme.label(properties)
	properties.BackgroundTransparency = 1
	properties.Font = properties.Font or Theme.Fonts.Text
	properties.TextColor3 = properties.TextColor3 or Theme.Colors.Text
	if properties.TextScaled == nil then
		properties.TextScaled = true
	end
	return make("TextLabel", properties)
end

-- Botão com degradê, borda e animação de passar o mouse / clicar
function Theme.recolor(target: GuiObject, newColor: Color3)
	local g = target:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(newColor:Lerp(Color3.new(1, 1, 1), 0.25), newColor:Lerp(Color3.new(0, 0, 0), 0.3))
	end
	local s = target:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = newColor:Lerp(Color3.new(0, 0, 0), 0.55)
	end
end

function Theme.button(properties, color: Color3?)
	local base = color or Theme.Colors.Gold
	local radius = take(properties, "Radius") or 10
	local maxText = take(properties, "MaxText") or 30
	properties.AutoButtonColor = false
	properties.TextStrokeTransparency = 0.55
	properties.BorderSizePixel = 0
	properties.BackgroundColor3 = Color3.new(1, 1, 1)
	properties.Font = properties.Font or Theme.Fonts.Title
	properties.TextColor3 = properties.TextColor3 or Color3.new(1, 1, 1)
	properties.TextScaled = true
	local btn = make("TextButton", properties)
	Theme.corner(btn, radius)
	local gradient = Theme.gradient(btn, base:Lerp(Color3.new(1, 1, 1), 0.25), base:Lerp(Color3.new(0, 0, 0), 0.3), 90)
	Theme.stroke(btn, base:Lerp(Color3.new(0, 0, 0), 0.55), 2)
	make("UITextSizeConstraint", { MaxTextSize = maxText, Parent = btn })
	make("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = btn,
	})
	local scale = make("UIScale", { Parent = btn })
	btn.MouseEnter:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.06 })
	end)
	btn.MouseLeave:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.06, { Scale = 0.94 })
	end)
	btn.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	return btn, gradient
end

-- Barra com degradê, brilho e "rastro" que acompanha devagar
function Theme.bar(parent: Instance, properties, color: Color3)
	local radius = take(properties, "Radius") or 8
	properties.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	properties.BackgroundTransparency = 0.15
	properties.BorderSizePixel = 0
	properties.Parent = parent
	local back = make("Frame", properties)
	Theme.corner(back, radius)
	Theme.stroke(back, Color3.fromRGB(0, 0, 0), 2)

	local trail = make("Frame", {
		Name = "Trail",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = back,
	})
	Theme.corner(trail, radius)

	local fill = make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = back,
	})
	Theme.corner(fill, radius)
	local gradient = Theme.gradient(fill, color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.25), 90)
	-- brilho no topo
	make("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -6, 0.35, 0),
		Position = UDim2.new(0, 3, 0, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Parent = fill,
	})

	local text = Theme.label({
		Name = "Label",
		Size = UDim2.new(1, -12, 1, -4),
		Position = UDim2.fromOffset(6, 2),
		Text = "",
		Font = Theme.Fonts.Number,
		ZIndex = 5,
		Parent = back,
	})
	make("UIStroke", { Thickness = 1.5, Transparency = 0.3, Parent = text })

	local api = { Back = back, Fill = fill, Trail = trail, Label = text, Gradient = gradient, Ratio = 1 }
	function api.Set(ratio: number)
		ratio = math.clamp(ratio, 0, 1)
		if math.abs(ratio - api.Ratio) < 0.0005 then
			return
		end
		local dropped = ratio < api.Ratio
		api.Ratio = ratio
		fill.Size = UDim2.fromScale(ratio, 1)
		if dropped then
			task.delay(0.25, function()
				if api.Ratio == ratio then
					Theme.tween(trail, 0.4, { Size = UDim2.fromScale(ratio, 1) })
				end
			end)
		else
			trail.Size = UDim2.fromScale(ratio, 1)
		end
	end
	function api.SetColor(newColor: Color3)
		gradient.Color = ColorSequence.new(newColor:Lerp(Color3.new(1, 1, 1), 0.3), newColor:Lerp(Color3.new(0, 0, 0), 0.25))
	end
	return api
end

-- Ícone de moeda desenhado (sem imagem)
function Theme.coin(parent: Instance, size: number, position: UDim2?)
	local coin = make("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	})
	Theme.round(coin)
	Theme.gradient(coin, Color3.fromRGB(255, 230, 120), Color3.fromRGB(215, 140, 20), 45)
	Theme.stroke(coin, Color3.fromRGB(140, 85, 10), 1.5)
	local inner = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55, 0.55),
		BackgroundTransparency = 1,
		Parent = coin,
	})
	Theme.round(inner)
	Theme.stroke(inner, Color3.fromRGB(190, 120, 20), 1.5)
	return coin
end

-- Ícone de espada desenhado (logo / decoração)
function Theme.swordIcon(parent: Instance, size: number, color: Color3?)
	local holder = make("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Rotation = 45,
		Parent = parent,
	})
	local c = color or Theme.Colors.Gold
	local blade = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.02),
		Size = UDim2.fromScale(0.14, 0.66),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = holder,
	})
	Theme.gradient(blade, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 180, 200), 0)
	Theme.corner(blade, 4)
	local guard = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromScale(0.5, 0.08),
		BackgroundColor3 = c,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Theme.corner(guard, 4)
	local grip = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.74),
		Size = UDim2.fromScale(0.1, 0.2),
		BackgroundColor3 = Color3.fromRGB(90, 55, 30),
		BorderSizePixel = 0,
		Parent = holder,
	})
	Theme.corner(grip, 3)
	local pommel = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.14, 0.14),
		BackgroundColor3 = c,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Theme.round(pommel)
	return holder
end

return Theme
