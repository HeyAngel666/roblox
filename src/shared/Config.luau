--[[
	Lâminas do Reino - Configuração central
	Todos os números de balanceamento do jogo ficam aqui.
	Cores são listas {R, G, B} (0-255) para o arquivo poder ser lido
	também pelo script de build (fora do Roblox).
]]

local Config = {}

Config.GameName = "Lâminas do Reino"

--------------------------------------------------------------------------
-- COMBATE
--------------------------------------------------------------------------
Config.Combat = {
	BaseWalkSpeed = 16,
	BaseJumpHeight = 7.2,

	ComboWindow = 0.9, -- segundos para continuar o combo
	ComboMultipliers = { 1, 1.1, 1.6 }, -- 3º golpe é o finalizador
	FinisherExtraDelay = 0.25,
	CritChance = 0.1,
	CritMultiplier = 1.5,

	HitDelay = 0.12, -- atraso entre o clique e o acerto (sincroniza com a animação)
	HitboxWidth = 6,
	HitboxHeight = 6,

	BlockReduction = 0.75, -- bloqueio reduz 75% do dano
	BlockStaminaCost = 15,
	BlockSpeedMultiplier = 0.5,
	ParryWindow = 0.3, -- bloquear logo antes do golpe = aparar (parry)
	ParryStun = 1.2,
	GuardBreakStun = 1.0,

	StaminaMax = 100,
	StaminaRegen = 22, -- por segundo
	StaminaRegenDelay = 1,

	DashCost = 25,
	DashCooldown = 0.7,
	DashInvulnerability = 0.3,
	DashSpeed = 75,
	DashDuration = 0.18,

	KnockbackForce = 45,
	KillCreditTime = 15, -- segundos que um golpe conta para o abate
}

--------------------------------------------------------------------------
-- ELEMENTOS DAS ESPADAS
--------------------------------------------------------------------------
Config.Elements = {
	none = { Name = "Nenhum", Color = { 255, 255, 255 } },
	fire = {
		Name = "Fogo",
		Color = { 255, 120, 30 },
		BurnDamage = 4,
		BurnTicks = 4,
		BurnInterval = 0.75,
	},
	ice = {
		Name = "Gelo",
		Color = { 140, 220, 255 },
		SlowMultiplier = 0.55,
		SlowDuration = 2.5,
	},
	shadow = {
		Name = "Sombra",
		Color = { 150, 70, 230 },
		Lifesteal = 0.25,
	},
	lightning = {
		Name = "Raio",
		Color = { 255, 235, 110 },
		ChainTargets = 2,
		ChainRadius = 14,
		ChainMultiplier = 0.5,
	},
	void = {
		Name = "Abismo",
		Color = { 230, 30, 50 },
		ExecuteThreshold = 0.3, -- alvo abaixo de 30% de vida...
		ExecuteMultiplier = 1.25, -- ...recebe +25% de dano
		-- além disso, golpes de Abismo atravessam o bloqueio
	},
}

--------------------------------------------------------------------------
-- ESPADAS
-- Price = nil  -> não está à venda (somente drop)
--------------------------------------------------------------------------
Config.Swords = {
	{
		Id = "madeira",
		Rarity = "Comum",
		Name = "Espada de Madeira",
		Description = "Toda lenda começa com um pedaço de madeira.",
		Price = 0,
		Level = 1,
		Damage = 12,
		Cooldown = 0.45,
		Range = 6,
		Element = "none",
		SpecialName = "Golpe Giratório",
		SpecialDamage = 18,
		SpecialRadius = 10,
		SpecialCooldown = 8,
		Look = {
			Style = "basic",
			BladeLength = 3.2,
			BladeWidth = 0.5,
			BladeColor = { 163, 120, 70 },
			BladeMaterial = "Wood",
			GuardColor = { 110, 78, 45 },
			HandleColor = { 85, 58, 35 },
			PommelColor = { 110, 78, 45 },
			TrailColor = { 230, 205, 160 },
		},
	},
	{
		Id = "ferro",
		Rarity = "Comum",
		Name = "Espada de Ferro",
		Description = "Forjada na vila. Confiável e resistente.",
		Price = 250,
		Level = 2,
		Damage = 17,
		Cooldown = 0.45,
		Range = 6.5,
		Element = "none",
		SpecialName = "Corte Giratório",
		SpecialDamage = 26,
		SpecialRadius = 11,
		SpecialCooldown = 8,
		Look = {
			Style = "basic",
			BladeLength = 3.6,
			BladeWidth = 0.5,
			BladeColor = { 190, 195, 205 },
			BladeMaterial = "Metal",
			GuardColor = { 95, 95, 105 },
			HandleColor = { 70, 45, 30 },
			PommelColor = { 95, 95, 105 },
			TrailColor = { 220, 225, 235 },
		},
	},
	{
		Id = "fogo",
		Rarity = "Raro",
		Name = "Lâmina de Fogo",
		Description = "Queima o inimigo por alguns segundos.",
		Price = 900,
		Level = 5,
		Damage = 21,
		Cooldown = 0.45,
		Range = 6.5,
		Element = "fire",
		SpecialName = "Explosão Flamejante",
		SpecialDamage = 32,
		SpecialRadius = 12,
		SpecialCooldown = 9,
		Look = {
			Style = "broad",
			BladeLength = 3.8,
			BladeWidth = 0.6,
			BladeColor = { 255, 110, 30 },
			BladeMaterial = "Neon",
			GuardColor = { 60, 40, 35 },
			HandleColor = { 40, 25, 20 },
			PommelColor = { 255, 170, 40 },
			TrailColor = { 255, 140, 40 },
			Glow = { 255, 120, 30 },
			Effect = "fire",
		},
	},
	{
		Id = "gelo",
		Rarity = "Raro",
		Name = "Presa de Gelo",
		Description = "Congela e deixa o inimigo lento.",
		Price = 1500,
		Level = 8,
		Damage = 23,
		Cooldown = 0.47,
		Range = 7,
		Element = "ice",
		SpecialName = "Nova Congelante",
		SpecialDamage = 30,
		SpecialRadius = 14,
		SpecialCooldown = 10,
		Look = {
			Style = "basic",
			BladeLength = 4,
			BladeWidth = 0.55,
			BladeColor = { 150, 225, 255 },
			BladeMaterial = "Ice",
			GuardColor = { 200, 240, 255 },
			HandleColor = { 40, 60, 90 },
			PommelColor = { 120, 200, 255 },
			TrailColor = { 160, 230, 255 },
			Glow = { 120, 210, 255 },
			Effect = "ice",
		},
	},
	{
		Id = "sombria",
		Rarity = "Épico",
		Name = "Katana Sombria",
		Description = "Rápida. Rouba a vida de quem corta.",
		Price = 2500,
		Level = 12,
		Damage = 24,
		Cooldown = 0.35,
		Range = 7,
		Element = "shadow",
		SpecialName = "Corte das Sombras",
		SpecialDamage = 38,
		SpecialRadius = 12,
		SpecialCooldown = 9,
		Look = {
			Style = "katana",
			BladeLength = 4.4,
			BladeWidth = 0.32,
			BladeColor = { 90, 30, 140 },
			BladeMaterial = "Neon",
			GuardColor = { 20, 20, 25 },
			HandleColor = { 25, 20, 35 },
			PommelColor = { 120, 50, 180 },
			TrailColor = { 160, 80, 255 },
			Glow = { 140, 60, 220 },
			Effect = "shadow",
		},
	},
	{
		Id = "celestial",
		Rarity = "Lendário",
		Name = "Excalibur Celestial",
		Description = "Raios saltam entre os inimigos.",
		Price = 6000,
		Level = 18,
		Damage = 31,
		Cooldown = 0.42,
		Range = 7.5,
		Element = "lightning",
		SpecialName = "Julgamento Celeste",
		SpecialDamage = 48,
		SpecialRadius = 15,
		SpecialCooldown = 10,
		Look = {
			Style = "broad",
			BladeLength = 4.6,
			BladeWidth = 0.6,
			BladeColor = { 255, 250, 210 },
			BladeMaterial = "Neon",
			GuardColor = { 255, 200, 50 },
			HandleColor = { 30, 50, 130 },
			PommelColor = { 255, 200, 50 },
			TrailColor = { 255, 240, 140 },
			Glow = { 255, 235, 140 },
			Effect = "holy",
		},
	},
	{
		Id = "reicaido",
		Rarity = "Mítico",
		Name = "Lâmina do Rei Caído",
		Description = "Só cai do Rei Caído. Atravessa bloqueios e executa inimigos fracos.",
		Price = nil,
		Level = 1,
		Damage = 36,
		Cooldown = 0.45,
		Range = 8,
		Element = "void",
		SpecialName = "Ira do Abismo",
		SpecialDamage = 55,
		SpecialRadius = 16,
		SpecialCooldown = 10,
		Look = {
			Style = "greatsword",
			BladeLength = 5.2,
			BladeWidth = 0.75,
			BladeColor = { 200, 20, 40 },
			BladeMaterial = "Neon",
			GuardColor = { 25, 20, 25 },
			HandleColor = { 20, 15, 20 },
			PommelColor = { 200, 20, 40 },
			TrailColor = { 255, 40, 60 },
			Glow = { 230, 30, 50 },
			Effect = "void",
		},
	},
}

Config.SwordById = {}
for index, sword in ipairs(Config.Swords) do
	sword.Order = index
	Config.SwordById[sword.Id] = sword
end

Config.DefaultSword = "madeira"

--------------------------------------------------------------------------
-- PROGRESSÃO
--------------------------------------------------------------------------
Config.MaxLevel = 50
Config.StartingCoins = 100

function Config.XPForLevel(level: number): number
	-- XP necessário para sair do nível "level" e ir para o próximo
	return math.floor(100 * level ^ 1.4)
end

function Config.MaxHealthForLevel(level: number): number
	return math.min(100 + (level - 1) * 5, 250)
end

Config.Rewards = {
	PlayerKillXP = 50,
	PlayerKillXPPerLevel = 5,
	PlayerKillCoins = 25,
	PlayerKillCoinsPerLevel = 2,
	BountyPerStreak = 10, -- moedas extras por abate da sequência da vítima
	StreakAnnounce = { [3] = true, [5] = true, [10] = true, [15] = true, [20] = true },
}

--------------------------------------------------------------------------
-- INIMIGOS (NPCs)
--------------------------------------------------------------------------
Config.NPCs = {
	Goblin = {
		DisplayName = "Goblin",
		Level = 2,
		MaxHealth = 70,
		Damage = 7,
		AttackCooldown = 1.3,
		AttackRange = 5,
		WalkSpeed = 15,
		AggroRange = 40,
		LeashRange = 90,
		XP = 25,
		Coins = 10,
		RespawnTime = 12,
		Sword = "madeira",
	},
	Esqueleto = {
		DisplayName = "Esqueleto",
		Level = 5,
		MaxHealth = 130,
		Damage = 11,
		AttackCooldown = 1.4,
		AttackRange = 5.5,
		WalkSpeed = 13,
		AggroRange = 45,
		LeashRange = 90,
		XP = 45,
		Coins = 20,
		RespawnTime = 15,
		Sword = "ferro",
	},
	Orc = {
		DisplayName = "Orc Guerreiro",
		Level = 10,
		MaxHealth = 320,
		Damage = 20,
		AttackCooldown = 1.8,
		AttackRange = 7,
		WalkSpeed = 12,
		AggroRange = 45,
		LeashRange = 80,
		XP = 110,
		Coins = 50,
		RespawnTime = 25,
		Sword = "fogo",
	},
	ReiCaido = {
		DisplayName = "Rei Caído",
		Level = 25,
		MaxHealth = 4000,
		Damage = 28,
		AttackCooldown = 1.6,
		AttackRange = 10,
		WalkSpeed = 14,
		AggroRange = 70,
		LeashRange = 75,
		XP = 1200,
		Coins = 600,
		RespawnTime = 180,
		Sword = "reicaido",
		IsBoss = true,
		SlamDamage = 35,
		SlamRadius = 16,
		SlamInterval = 9,
		SlamWarning = 1.1,
		EnrageAt = 0.5, -- fase 2 com 50% de vida
		MinionKind = "Esqueleto",
		MinionCount = 2,
		DropSword = "reicaido",
		DropChance = 0.3,
		MinContribution = 0.05, -- precisa causar 5% do dano para ganhar recompensa
	},
}

--------------------------------------------------------------------------
-- ZONAS (nomes usados no mapa)
--------------------------------------------------------------------------
Config.Zones = {
	Vila = { DisplayName = "VILA", Subtitle = "Zona segura", Color = { 120, 230, 140 } },
	Arena = { DisplayName = "ARENA", Subtitle = "PvP liberado", Color = { 255, 90, 80 } },
	Floresta = { DisplayName = "FLORESTA SOMBRIA", Subtitle = "Monstros", Color = { 150, 220, 110 } },
	Ruinas = { DisplayName = "RUÍNAS DO REI", Subtitle = "Chefe", Color = { 230, 60, 70 } },
	Campos = { DisplayName = "CAMPOS", Subtitle = "PvP liberado", Color = { 240, 220, 140 } },
}
Config.DefaultZone = "Campos"

--------------------------------------------------------------------------
-- MUNDO
--------------------------------------------------------------------------
Config.DayLengthMinutes = 12 -- duração de um dia completo no jogo

return Config
