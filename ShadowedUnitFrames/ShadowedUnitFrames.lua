--[[
	Shadowed Unit Frames, Shadowed of Mal'Ganis (US) PvP
]]

ShadowUF = select(2, ...)

local L = ShadowUF.L
ShadowUF.dbRevision = 63
ShadowUF.dbRevisionClassic = 61
ShadowUF.playerUnit = "player"
ShadowUF.enabledUnits = {}
ShadowUF.modules = {}
ShadowUF.moduleOrder = {}
ShadowUF.unitList = {"player", "pet", "pettarget", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "partytarget", "partytargettarget", "raid", "raidpet", "boss", "bosstarget", "maintank", "maintanktarget", "mainassist", "mainassisttarget", "arena", "arenatarget", "arenapet", "battleground", "battlegroundtarget", "battlegroundpet", "arenatargettarget", "battlegroundtargettarget", "maintanktargettarget", "mainassisttargettarget", "bosstargettarget"}
ShadowUF.fakeUnits = {["targettarget"] = true, ["targettargettarget"] = true, ["pettarget"] = true, ["arenatarget"] = true, ["arenatargettarget"] = true, ["focustarget"] = true, ["focustargettarget"] = true, ["partytarget"] = true, ["raidtarget"] = true, ["bosstarget"] = true, ["maintanktarget"] = true, ["mainassisttarget"] = true, ["battlegroundtarget"] = true, ["partytargettarget"] = true, ["battlegroundtargettarget"] = true, ["maintanktargettarget"] = true, ["mainassisttargettarget"] = true, ["bosstargettarget"] = true}
L.units = {["raidpet"] = L["Raid pet"], ["PET"] = L["Pet"], ["VEHICLE"] = L["Vehicle"], ["arena"] = L["Arena"], ["arenapet"] = L["Arena Pet"], ["arenatarget"] = L["Arena Target"], ["arenatargettarget"] = L["Arena Target of Target"], ["boss"] = L["Boss"], ["bosstarget"] = L["Boss Target"], ["focus"] = L["Focus"], ["focustarget"] = L["Focus Target"], ["mainassist"] = L["Main Assist"], ["mainassisttarget"] = L["Main Assist Target"], ["maintank"] = L["Main Tank"], ["maintanktarget"] = L["Main Tank Target"], ["party"] = L["Party"], ["partypet"] = L["Party Pet"], ["partytarget"] = L["Party Target"], ["pet"] = L["Pet"], ["pettarget"] = L["Pet Target"], ["player"] = L["Player"],["raid"] = L["Raid"], ["target"] = L["Target"], ["targettarget"] = L["Target of Target"], ["targettargettarget"] = L["Target of Target of Target"], ["battleground"] = L["Battleground"], ["battlegroundpet"] = L["Battleground Pet"], ["battlegroundtarget"] = L["Battleground Target"], ["partytargettarget"] = L["Party Target of Target"], ["battlegroundtargettarget"] = L["Battleground Target of Target"], ["maintanktargettarget"] = L["Main Tank Target of Target"], ["mainassisttargettarget"] = L["Main Assist Target of Target"], ["bosstargettarget"] = L["Boss Target of Target"]}
L.shortUnits = {["battleground"] = L["BG"], ["battlegroundtarget"] = L["BG Target"], ["battlegroundpet"] = L["BG Pet"], ["battlegroundtargettarget"] = L["BG ToT"], ["arenatargettarget"] = L["Arena ToT"], ["partytargettarget"] = L["Party ToT"], ["bosstargettarget"] = L["Boss ToT"], ["maintanktargettarget"] = L["MT ToT"], ["mainassisttargettarget"] = L["MA ToT"]}

-- Cache the units so we don't have to concat every time it updates
ShadowUF.unitTarget = setmetatable({}, {__index = function(tbl, unit) rawset(tbl, unit, unit .. "target"); return unit .. "target" end})
ShadowUF.partyUnits, ShadowUF.raidUnits, ShadowUF.raidPetUnits, ShadowUF.bossUnits, ShadowUF.arenaUnits, ShadowUF.battlegroundUnits = {}, {}, {}, {}, {}, {}
ShadowUF.maintankUnits, ShadowUF.mainassistUnits, ShadowUF.raidpetUnits = ShadowUF.raidUnits, ShadowUF.raidUnits, ShadowUF.raidPetUnits
for i=1, MAX_PARTY_MEMBERS do ShadowUF.partyUnits[i] = "party" .. i end
for i=1, MAX_RAID_MEMBERS do ShadowUF.raidUnits[i] = "raid" .. i end
for i=1, MAX_RAID_MEMBERS do ShadowUF.raidPetUnits[i] = "raidpet" .. i end
for i=1, MAX_BOSS_FRAMES do ShadowUF.bossUnits[i] = "boss" .. i end
for i=1, 5 do ShadowUF.arenaUnits[i] = "arena" .. i end
for i=1, 4 do ShadowUF.battlegroundUnits[i] = "arena" .. i end

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			locked = false,
			advanced = false,
			tooltipCombat = false,
			bossmodSpellRename = true,
			omnicc = false,
			blizzardcc = true,
			tags = {},
			units = {},
			positions = {},
			range = {},
			filters = {zonewhite = {}, zoneblack = {}, zoneoverride = {}, whitelists = {}, blacklists = {}, overridelists = {}},
			visibility = {arena = {}, pvp = {}, party = {}, raid = {}},
			hidden = {cast = false, playerPower = true, buffs = false, party = true, raid = false, player = true, pet = true, target = true, focus = true, boss = true, arena = true, playerAltPower = false},
		},
	}

	self:LoadUnitDefaults()

	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileReset")

	-- Setup tag cache
	self.tagFunc = setmetatable({}, {
		__index = function(tbl, index)
			if( not ShadowUF.Tags.defaultTags[index] and not ShadowUF.db.profile.tags[index] ) then
				tbl[index] = false
				return false
			end

			local func, msg = loadstring("return " .. (ShadowUF.Tags.defaultTags[index] or ShadowUF.db.profile.tags[index].func or ""))
			if( func ) then
				func = func()
			elseif( msg ) then
				error(msg, 3)
			end

			tbl[index] = func
			return tbl[index]
	end})

	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
		self:CheckBuild()
		self:ShowInfoPanel()
	end

	self.db.profile.revision = self.dbRevision
	self.db.profile.revisionClassic = self.dbRevisionClassic
	self:FireModuleEvent("OnInitialize")
	self:HideBlizzardFrames()
	self.Layout:LoadSML()
	self:LoadUnits()
	self.modules.movers:Update()

	local LibDualSpec = LibStub("LibDualSpec-1.0", true)
	if LibDualSpec then LibDualSpec:EnhanceDatabase(self.db, "ShadowedUnitFrames") end
end

function ShadowUF.UnitAuraBySpell(unit, spell, filter)
	local auraData
	if type(spell) == "string" then
		auraData = C_UnitAuras.GetAuraDataBySpellName(unit, spell, filter)
	elseif type(spell) == "number" then
		local index = 0
		while true do
			index = index + 1
			local data = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
			if not data then break end
			if data.spellId == spell then
				auraData = data
				break
			end
		end
	end
	return AuraUtil.UnpackAuraData(auraData)
end

function ShadowUF:CheckBuild()
	local build = select(4, GetBuildInfo())
	if( self.db.profile.wowBuild == build ) then return end

	-- Nothing to add here right now
	self.db.profile.wowBuild = build
end

function ShadowUF:CheckUpgrade()
	local revisionClassic = self.db.profile.revisionClassic or (self.db.profile.revision and 1 or self.dbRevisionClassic)
	local revision = self.db.profile.revision or self.dbRevision
	if( revisionClassic <= 45 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( config.auras ) then
				for _, key in pairs({"buffs", "debuffs"}) do
					local aura = config.auras[key]
					aura.show = aura.show or {}
					aura.show.player = true
					aura.show.boss = true
					aura.show.raid = true
					aura.show.consolidated = true
					aura.show.misc = true
				end
			end
		end
	end

	if( revisionClassic <= 44 ) then
		ShadowUF:LoadDefaultLayout(true)

		for unit, config in pairs(self.defaults.profile.units) do
			if( config.indicators and config.indicators.resurrect ) then
				local db = self.db.profile.units[unit]
				
				local options
				if( unit == "target" ) then
					options = {enabled = true, anchorPoint = "RC", size = 28, x = -39, y = -1, anchorTo = "$parent"}
				else
					options = {enabled = true, anchorPoint = "LC", size = 28, x = 37, y = -1, anchorTo = "$parent"}
				end

				for key, value in pairs(options) do
					if( db.indicators.resurrect[key] == nil ) then
						db.indicators.resurrect[key] = value
					end
				end
			end
		end		
	end

	if( revisionClassic <= 43 ) then
		for key, _ in pairs(self.db.profile.auraIndicators.indicators) do
			self.db.profile.auraIndicators.height = nil
			self.db.profile.auraIndicators.filters[key] = {boss = {priority = 100}, curable = {priority = 100}}
		end
	end

	if( revisionClassic <= 42 ) then
		for unit, config in pairs(self.db.profile.units) do
			config.auras.height = nil

			for type, auraConfig in pairs(config.auras) do
				auraConfig.show = {misc = true}
				auraConfig.show.player = auraConfig.player
				auraConfig.show.raid = auraConfig.raid

				auraConfig.enlarge = {}
				auraConfig.enlarge["SELF"] = auraConfig.enlargeSelf
				auraConfig.enlarge["REMOVABLE"] = auraConfig.enlargeStealable

				auraConfig.timers = {}
				if( auraConfig.selfTimers ) then
					auraConfig.timers["SELF"] = true
				else
					auraConfig.timers["ALL"] = true
				end

				auraConfig.selfTimers = nil
				auraConfig.player = nil
				auraConfig.raid = nil
				auraConfig.enlargeSelf = nil
				auraConfig.enlargeStealable = nil
			end

			config.auras.buffs.show.consolidated = true
			config.auras.debuffs.show.boss = true
		end
	end

	if( revisionClassic <= 41 ) then
		local phase = self.db.profile.units.party.indicators.phase
		phase.anchorPoint = phase.anchorPoint or "RC"
		phase.size = phase.size or 14
		phase.x = phase.x or -11
		phase.y = phase.y or 0
		phase.anchorTo = phase.anchorTo or "$parent"
	end

	if( revisionClassic <= 40 ) then
		ShadowUF:LoadDefaultLayout(true)

		for unit, config in pairs(self.db.profile.units) do
			if( config.healAbsorb and not self.defaults.profile.units[unit].healAbsorb ) then
				config.healAbsorb = nil
			end
		end
	end

	if( revisionClassic <= 37 ) then
		self.db.profile.healthColors.healAbsorb = {r = 0.68, g = 0.47, b = 1}
	end

	if( revisionClassic <= 34 ) then
		self.db.profile.units.player.staggerBar = {enabled = true, background = true, height = 0.30, order = 70}
		self.db.profile.powerColors.STAGGER_GREEN = {r = 0.52, g = 1.0, b = 0.52}
		self.db.profile.powerColors.STAGGER_YELLOW = {r = 1.0, g = 0.98, b = 0.72}
		self.db.profile.powerColors.STAGGER_RED = {r = 1.0, g = 0.42, b = 0.42}
	end

	if( revisionClassic <= 33 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( not self.defaults.profile.units[unit].incHeal and config.incHeal ) then
				config.incHeal = nil
			end

			if( not self.defaults.profile.units[unit].incAbsorb and config.incAbsorb ) then
				config.incAbsorb = nil
			end

			if( config.incAbsorb ) then
				config.incAbsorb.cap = config.incAbsorb.cap or 1.30
			end

			if( config.incHeal ) then
				config.incHeal.cap = config.incHeal.cap or 1.30
			end
		end
	end

	if( revisionClassic <= 32 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( config.incAbsorb and not config.incAbsorb.cap ) then
				config.incAbsorb.cap = 1.30
			end
		end
	end

	if( revisionClassic <= 31 or not self.db.profile.healthColors.incAbsorb ) then
		self.db.profile.healthColors.incAbsorb = {r = 0.93, g = 0.75, b = 0.09}

		for unit, config in pairs(self.db.profile.units) do
			if( config.incHeal ) then
				config.incHeal.enabled = config.incHeal.heals
				config.incHeal.heals = nil
				config.incAbsorb = {enabled = config.incHeal.enabled}
			end
		end
	end

	if( revisionClassic <= 30 ) then
		self.db.profile.powerColors.RUNEOFPOWER = {r = 0.35, g = 0.45, b = 0.60}
	end

	if( revisionClassic <= 29 ) then
		self.db.profile.units.player.totemBar.showAlways = true
	end

	if( revisionClassic <= 28 ) then
		self.db.profile.units.target.indicators.questBoss = {enabled = true, anchorPoint = "BR", size = 22, x = 9, y = 24, anchorTo = "$parent"}
		self.db.profile.units.focus.indicators.questBoss = {enabled = false, anchorPoint = "BR", size = 22, x = 7, y = 14, anchorTo = "$parent"}

		for unit, config in pairs(self.db.profile.units) do
			for key, module in pairs(ShadowUF.modules) do
				if( config[key] and ( module.moduleHasBar or module.isComboPoints or config[key].isBar or config[key].order ) ) then
					config[key].height = config[key].height or 0.40
				end
			end
		end
	end

	if( revisionClassic <= 27 ) then
		self.db.profile.healthColors.aggro = CopyTable(self.db.profile.healthColors.hostile)
	end

	if( revisionClassic <= 26 ) then
		for _, unit in pairs(self.unitList) do
			if( unit ~= "player" ) then
				for id, text in pairs(self.db.profile.units[unit].text) do
					if( text.anchorTo == "$demonicFuryBar" ) then
						self.db.profile.units[unit].text[id] = nil
					end
				end
			end
		end
	end

	-- if( revisionClassic <= 25 ) then
		-- table.insert(self.db.profile.units.player.text, {enabled = true, width = 1, name = L["Eclipse Power"], text = "[druid:balance]", anchorTo = "$eclipseBar", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	-- end
	if( revisionClassic <= 24 ) then
		self.db.profile.powerColors.AURAPOINTS = {r = 1.0, g = 0.80, b = 0}
		self.db.profile.units.player.auraPoints = {enabled = false, showAlways = true, anchorTo = "$parent", order = 60, anchorPoint = "BR", x = -3, y = 8, size = 14, spacing = -4, growth = "LEFT", isBar = true, height = 0.40}
	end

	if( revisionClassic <= 23 ) then
		self.db.profile.hidden.playerAltPower = false
		self.db.profile.powerColors.ALTERNATE = {r = 0.815, g = 0.941, b = 1}
	end

	if( revisionClassic <= 22 ) then
		self:LoadDefaultLayout(true)

		for _, unit in pairs(self.unitList) do
			if( ShadowUF.fakeUnits[unit] ) then
				self.db.profile.units[unit].altPowerBar.enabled = false
			end
		end
	end

	if( revisionClassic <= 21 ) then
		self.db.profile.powerColors["POWER_TYPE_FEL_ENERGY"] = {r = 0.878, g = 0.980, b = 0}
	end
	
	if( revisionClassic <= 20 ) then
		self.db.profile.powerColors["ALTERNATE"] = {r = 0.71, g = 0.0, b = 1.0}
		
		for _, unit in pairs(self.unitList) do
			self.db.profile.units[unit].altPowerBar.enabled = true
			self.db.profile.units[unit].altPowerBar.background = true
			self.db.profile.units[unit].altPowerBar.height = 0.40
			self.db.profile.units[unit].altPowerBar.order = 100
		end
	end
	if( revisionClassic <= 19 ) then
		table.insert(self.db.profile.units.player.text, {enabled = true, width = 1, name = L["Demonic Power"], text = "", anchorTo = "$demonicFuryBar", anchorPoint = "C", x = 3, y = 0, size = -1})
		table.insert(self.db.profile.units.player.text, {enabled = true, width = 1, name = L["Eclipse Power"], text = "", anchorTo = "$eclipseBar", anchorPoint = "C", size = 0, x = 0, y = 0})
		table.insert(self.db.profile.units.player.text, {enabled = true, width = 1, name = L["Timer Text"], text = "", anchorTo = "$runeBar", anchorPoint = "C", size = 0, x = 0, y = 0})
		table.insert(self.db.profile.units.player.text, {enabled = true, width = 1, name = L["Timer Text"], text = "", anchorTo = "$totemBar", anchorPoint = "C", size = 0, x = 0, y = 0})
		table.insert(self.db.profile.units.player.text, {enabled = true, width = 1, name = L["Stagger Power"], text = "", anchorTo = "$staggerBar", anchorPoint = "C", size = 0, x = 0, y = 0})
	end
	if( revisionClassic <= 18 ) then
		self.db.profile.powerColors["MUSHROOMS"] = {r = 0.20, g = 0.90, b = 0.20}
		self.db.profile.powerColors["STATUE"] = {r = 0.35, g = 0.45, b = 0.60}
	end

	if( revisionClassic <= 17 ) then
		self.db.profile.units.target.indicators.petBattle = {enabled = true, anchorPoint = "BL", size = 18, x = -6, y = 14, anchorTo = "$parent"}
		self.db.profile.units.focus.indicators.petBattle = {enabled = false, anchorPoint = "BL", size = 18, x = -6, y = 12, anchorTo = "$parent"}
		self.db.profile.units.party.indicators.phase = {enabled = true}
	end

	if( revisionClassic <= 16 ) then
		self.db.profile.units.target.indicators.questBoss = {enabled = true, anchorPoint = "BR", size = 22, x = 9, y = 24, anchorTo = "$parent"}
		self.db.profile.units.focus.indicators.questBoss = {enabled = false, anchorPoint = "BR", size = 22, x = 7, y = 14, anchorTo = "$parent"}
	end

	if( revisionClassic <= 15 ) then
		self.db.profile.powerColors["DEMONICFURY"] = {r = 0.58, g = 0.51, b = 0.79}
		self.db.profile.powerColors["BURNINGEMBERS"] = {r = 0.58, g = 0.51, b = 0.79}
		self.db.profile.powerColors["FULLBURNINGEMBER"] = {r = 0.88, g = 0.09, b = 0.062}
		self.db.profile.powerColors["SHADOWORBS"] = {r = 0.58, g = 0.51, b = 0.79}

		self.db.profile.units.player.shadowOrbsBar = {anchorTo = "$parent", order = 60, height = 0.40, anchorPoint = "BR", x = -3, y = 6, size = 14, spacing = -4, growth = "LEFT", isBar = true, showAlways = true}
		self.db.profile.units.player.burningEmbersBar = {enabled = true, background = false, height = 0.40, order = 70}
		self.db.profile.units.player.demonicFuryBar = {enabled = true, background = false, height = 0.40, order = 70}
	end

	if( revisionClassic <= 14 ) then
		self.db.profile.powerColors["CHI"] = {r = 0.71, g = 1.0, b = 0.92}

		self.db.profile.units.player.chi = {anchorTo = "$parent", order = 60, height = 0.40, anchorPoint = "BR", x = -3, y = 6, size = 14, spacing = -4, growth = "LEFT", isBar = true, showAlways = true}
	end
	if( revisionClassic <= 13 ) then
		self.db.profile.powerColors["BANKEDHOLYPOWER"] = {r = 0.96, g = 0.61, b = 0.84}
	end

	if( revisionClassic <= 12 ) then
		self.db.profile.classColors["MONK"] = {r = 0.0, g = 1.00, b = 0.59}
	end

	if( revisionClassic <= 11 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( config.powerBar ) then
				config.powerBar.colorType = "type"
			end
		end
	end

	if( revisionClassic <= 5 ) then
		local config = self.db.profile.units
		config.player.soulShards = {anchorTo = "$parent", order = 60, height = 0.40, anchorPoint = "BR", x = -8, y = 6, size = 12, spacing = -2, growth = "LEFT", isBar = true, showAlways = true}
		config.player.holyPower = {anchorTo = "$parent", order = 60, height = 0.40, anchorPoint = "BR", x = -3, y = 6, size = 14, spacing = -4, growth = "LEFT", isBar = true, showAlways = true}

		self.db.profile.classColors.VEHICLE = {r = 0.23, g = 0.41, b = 0.23}
		self.db.profile.healthColors.aggro = {r = 0.9, g = 0, b = 0}
	end
	if( revisionClassic <= 4 ) then
		-- new resources
		self.db.profile.powerColors.RUNES_BLOOD = {r = 0.95, g = 0.0, b = 0.08}
		self.db.profile.powerColors.RUNES_FROST = {r = 0.0, g = 0.85, b = 1.0}
		self.db.profile.powerColors.RUNES_UNHOLY = {r = 0.0, g = 1.0, b = 0.35}
		self.db.profile.powerColors.RUNES_DEATH = {r = 0.69, g = 0.15, b = 1.0}

		-- new bars
		local config = self.db.profile.units
		config.player.runeBar = {enabled = true, background = false, height = 0.40, order = 70}
		local hasRuneText = false
		for i, text in ipairs(config.player.text) do
			if text and text.anchorTo == "$runeBar" and text == "[rune:timer]" then
				hasRuneText = true
			end
		end
	end
	if( revisionClassic <= 4 or not self.db.profile.revisionClassic ) then
		ShadowUF:LoadDefaultLayout(true)
	end
	if( revisionClassic <= 1 ) then
		local indicators = self.db.profile.units.pet.indicators or {}
		self.db.profile.units.pet.indicators = indicators
		if( revision <= 59 or not indicators.happiness ) then
			indicators.happiness = {enabled = true, anchorPoint = "RC", size = 20, x = 0, y = 0, anchorTo = "$parent"}
		else
			local happiness = indicators.happiness
			if happiness.size == 0 then
				happiness.size = 20
			end
			if not happiness.anchorPoint then
				happiness.anchorPoint = "RC"
			end
			if not happiness.anchorTo then
				happiness.anchorTo = "$parent"
			end
		end
	end													 
	if( revision <= 58 ) then
		for unit, config in pairs(self.db.profile.units) do
			if config.text then
				local i = 1
				while i <= #config.text do
					local text
					if rawget(config.text, i) or i <= #(self.defaults.profile.units[unit].text) then
						text = config.text[i]
					end

					if not text then
						table.remove(config.text, i)
					elseif text.anchorTo == "$demonicFuryBar" or text.anchorTo == "$eclipseBar" or text.anchorTo == "$burningEmbersBar" or text.anchorTo == "$monkBar" then
						table.remove(config.text, i)
					elseif i > 6 and text.default and text.anchorTo == "$emptyBar" then
						table.remove(config.text, i)
					else
						if text.anchorTo == "$emptyBar" and text.name == L["Left text"] then
							text.width = 0.50
						end

						i = i + 1
					end
				end

				if not config.text[6] or config.text[6].anchorTo ~= "$emptyBar" then
					table.insert(config.text, 6, {enabled = true, width = 0.60, name = L["Right text"], text = "", anchorTo = "$emptyBar", anchorPoint = "CRI", size = 0, x = -3, y = 0, default = true})
				else
					config.text[6].width = 0.60
					config.text[6].name = L["Right text"]
					config.text[6].anchorPoint = "CRI"
					config.text[6].size = 0
					config.text[6].x = -3
					config.text[6].y = 0
					config.text[6].default = true
				end
			end
		end
end										

	if( revision <= 49 ) then
		ShadowUF:LoadDefaultLayout(true)
		self.db.profile.classColors.DEMONHUNTER = {r = 0.64, g = 0.19, b = 0.79}
	end

	if( revision <= 49 ) then
		if( ShadowUF.db.profile.font.extra == "MONOCHROME" ) then
			ShadowUF.db.profile.font.extra = ""
		end
	end

	if( revision <= 47 ) then
		local config = self.db.profile.units
		config.player.comboPoints = config.target.comboPoints
	end

	if( revision <= 46 ) then
		local config = self.db.profile.units.arena
		config.indicators.arenaSpec = {enabled = true, anchorPoint = "LC", size = 28, x = 0, y = 0, anchorTo = "$parent"}
		config.indicators.lfdRole = {enabled = true, anchorPoint = "BR", size = 14, x = 3, y = 14, anchorTo = "$parent"}
	end

	if( revision <= 45 ) then
		for unit, config in pairs(self.db.profile.units) do
			if( config.auras ) then
				for _, key in pairs({"buffs", "debuffs"}) do
					local aura = config.auras[key]
					aura.show = aura.show or {}
					aura.show.player = true
					aura.show.boss = true
					aura.show.raid = true
					aura.show.misc = true
				end
			end
		end
	end

	if( revisionClassic <= 15 ) then
		self.db.profile.powerColors["DEMONICFURY"] = {r = 0.58, g = 0.51, b = 0.79}
		self.db.profile.powerColors["BURNINGEMBERS"] = {r = 0.58, g = 0.51, b = 0.79}
		self.db.profile.powerColors["FULLBURNINGEMBER"] = {r = 0.88, g = 0.09, b = 0.062}
		self.db.profile.powerColors["SHADOWORBS"] = {r = 0.58, g = 0.51, b = 0.79}

		self.db.profile.units.player.shadowOrbs = {anchorTo = "$parent", order = 60, height = 0.40, anchorPoint = "BR", x = -3, y = 6, size = 14, spacing = -4, growth = "LEFT", isBar = true, showAlways = true}
		self.db.profile.units.player.burningEmbersBar = {enabled = true, background = false, height = 0.40, order = 70}
		self.db.profile.units.player.demonicFuryBar = {enabled = true, background = false, height = 0.40, order = 70}
	end		
end

local function zoneEnabled(zone, zoneList)
	if( type(zoneList) == "string" ) then
		return zone == zoneList
	end

	for id, row in pairs(zoneList) do
		if( zone == row ) then return true end
	end

	return false
end

function ShadowUF:LoadUnits()
	-- CanHearthAndResurrectFromArea() returns true for world pvp areas, according to BattlefieldFrame.lua
	local instanceType = CanHearthAndResurrectFromArea() and "pvp" or select(2, IsInInstance())
	if( instanceType == "scenario" ) then instanceType = "party" end

	if( not instanceType ) then instanceType = "none" end

	for _, type in pairs(self.unitList) do
		local enabled = self.db.profile.units[type].enabled
		if( ShadowUF.Units.zoneUnits[type] ) then
			enabled = enabled and zoneEnabled(instanceType, ShadowUF.Units.zoneUnits[type])
		elseif( instanceType ~= "none" ) then
			if( self.db.profile.visibility[instanceType][type] == false ) then
				enabled = false
			elseif( self.db.profile.visibility[instanceType][type] == true ) then
				enabled = true
			end
		end

		self.enabledUnits[type] = enabled

		if( enabled ) then
			self.Units:InitializeFrame(type)
		else
			self.Units:UninitializeFrame(type)
		end
	end
end

function ShadowUF:LoadUnitDefaults()
	for _, unit in pairs(self.unitList) do
		self.defaults.profile.positions[unit] = {point = "", relativePoint = "", anchorPoint = "", anchorTo = "UIParent", x = 0, y = 0}

		-- The reason why the defaults are so sparse, is because the layout needs to specify most of this. The reason I set tables here is basically
		-- as an indication that hey, the unit wants this, if it doesn't that it won't want it.
		self.defaults.profile.units[unit] = {
			enabled = false, height = 0, width = 0, scale = 1.0,
			healthBar = {enabled = true},
			powerBar = {enabled = true},
			emptyBar = {enabled = false},
			portrait = {enabled = false},
			castBar = {enabled = false, name = {}, time = {}},
			text = {
				{enabled = true, name = L["Left text"], text = "[name]", anchorPoint = "CLI", anchorTo = "$healthBar", width = 0.50, size = 0, x = 3, y = 0, default = true},
				{enabled = true, name = L["Right text"], text = "[curmaxhp]", anchorPoint = "CRI", anchorTo = "$healthBar", width = 0.60, size = 0, x = -3, y = 0, default = true},
				{enabled = true, name = L["Left text"], text = "[level] [race]", anchorPoint = "CLI", anchorTo = "$powerBar", width = 0.50, size = 0, x = 3, y = 0, default = true},
				{enabled = true, name = L["Right text"], text = "[curmaxpp]", anchorPoint = "CRI", anchorTo = "$powerBar", width = 0.60, size = 0, x = -3, y = 0, default = true},
				{enabled = true, name = L["Left text"], text = "", anchorTo = "$emptyBar", anchorPoint = "CLI", width = 0.50, size = 0, x = 3, y = 0, default = true},
				{enabled = true, name = L["Right text"], text = "", anchorTo = "$emptyBar", anchorPoint = "CRI", width = 0.60, size = 0, x = -3, y = 0, default = true},
				['*'] = {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0},
			},
			indicators = {raidTarget = {enabled = true, size = 0}},
			highlight = {},
			auraIndicators = {enabled = false},
			auras = {
				buffs = {enabled = false, perRow = 10, maxRows = 4, selfScale = 1.30, prioritize = true, show = {player = true, boss = true, raid = true, misc = true}, enlarge = {}, timers = {ALL = true}},
				debuffs = {enabled = false, perRow = 10, maxRows = 4, selfScale = 1.30, show = {player = true, boss = true, raid = true, misc = true}, enlarge = {SELF = true}, timers = {ALL = true}},
			},
		}

		if( not self.fakeUnits[unit] ) then
			self.defaults.profile.units[unit].combatText = {enabled = true, anchorTo = "$parent", anchorPoint = "C", x = 0, y = 0}

			if( unit ~= "battleground" and unit ~= "battlegroundpet" and unit ~= "arena" and unit ~= "arenapet" and unit ~= "boss" ) then
				self.defaults.profile.units[unit].incHeal = {enabled = true, cap = 1.20}
				self.defaults.profile.units[unit].incAbsorb = {enabled = true, cap = 1.30}
				self.defaults.profile.units[unit].healAbsorb = {enabled = true, cap = 1.30}
			end
		end

		if( unit ~= "player" ) then
			self.defaults.profile.units[unit].range = {enabled = false, oorAlpha = 0.80, inAlpha = 1.0}

			if( not string.match(unit, "pet") ) then
				self.defaults.profile.units[unit].indicators.class = {enabled = false, size = 19}
			end
		end

		if( unit == "player" or unit == "party" or unit == "target" or unit == "raid" or unit == "focus" or unit == "mainassist" or unit == "maintank" ) then
			self.defaults.profile.units[unit].indicators.leader = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.masterLoot = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.role = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.status = {enabled = false, size = 19}
			self.defaults.profile.units[unit].indicators.resurrect = {enabled = true}
			self.defaults.profile.units[unit].indicators.sumPending = {enabled = true}

			if( unit ~= "focus" and unit ~= "target" ) then
				self.defaults.profile.units[unit].indicators.ready = {enabled = true, size = 0}
			end
		end

		if( unit == "battleground" ) then
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true, size = 0}
		end

		self.defaults.profile.units[unit].altPowerBar = {enabled = not ShadowUF.fakeUnits[unit]}
	end

	-- PLAYER
	self.defaults.profile.units.player.enabled = true
	self.defaults.profile.units.player.healthBar.predicted = true
	self.defaults.profile.units.player.powerBar.predicted = true
	self.defaults.profile.units.player.indicators.status.enabled = true
	self.defaults.profile.units.player.runeBar = {enabled = false}
	self.defaults.profile.units.player.totemBar = {enabled = false}
	self.defaults.profile.units.player.druidBar = {enabled = false}
	self.defaults.profile.units.player.monkBar = {enabled = false}
	self.defaults.profile.units.player.shamanBar = {enabled = true}
	self.defaults.profile.units.player.xpBar = {enabled = false}
	self.defaults.profile.units.player.fader = {enabled = false}
	self.defaults.profile.units.player.soulShards = {enabled = true, isBar = true}
	self.defaults.profile.units.player.arcaneCharges = {enabled = true, isBar = true}
	self.defaults.profile.units.player.staggerBar = {enabled = true}
	self.defaults.profile.units.player.comboPoints = {enabled = true, isBar = true}
	self.defaults.profile.units.player.demonicFuryBar = {enabled = true}
	self.defaults.profile.units.player.burningEmbersBar = {enabled = true}
	self.defaults.profile.units.player.eclipseBar = {enabled = true}
	self.defaults.profile.units.player.holyPower = {enabled = true, isBar = true}
	self.defaults.profile.units.player.shadowOrbs = {enabled = true, isBar = true}
	self.defaults.profile.units.player.chi = {enabled = true, isBar = true}
	self.defaults.profile.units.player.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.player.auraPoints = {enabled = false, isBar = true}
	self.defaults.profile.units.player.essence = {enabled = true, isBar = true}
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
	table.insert(self.defaults.profile.units.player.text, {enabled = true, text = "", anchorTo = "", anchorPoint = "C", size = 0, x = 0, y = 0, default = true})
    -- PET
	self.defaults.profile.units.pet.enabled = true
	self.defaults.profile.units.pet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.pet.xpBar = {enabled = false}
    -- FOCUS
	self.defaults.profile.units.focus.enabled = true
	self.defaults.profile.units.focus.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.focus.indicators.lfdRole = {enabled = false, size = 0, x = 0, y = 0}
	self.defaults.profile.units.focus.indicators.questBoss = {enabled = true, size = 0, x = 0, y = 0}
	-- FOCUSTARGET
	self.defaults.profile.units.focustarget.enabled = true
	self.defaults.profile.units.focustarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- TARGET
	self.defaults.profile.units.target.enabled = true
	self.defaults.profile.units.target.indicators.lfdRole = {enabled = false, size = 0, x = 0, y = 0}
	self.defaults.profile.units.target.indicators.questBoss = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.target.comboPoints = {enabled = false, isBar = true}
	-- TARGETTARGET/TARGETTARGETTARGET
	self.defaults.profile.units.targettarget.enabled = true
	self.defaults.profile.units.targettargettarget.enabled = true
	-- PARTY
	self.defaults.profile.units.party.enabled = true
	self.defaults.profile.units.party.auras.debuffs.maxRows = 1
	self.defaults.profile.units.party.auras.buffs.maxRows = 1
	self.defaults.profile.units.party.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.party.combatText.enabled = false
	self.defaults.profile.units.party.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.party.indicators.phase = {enabled = true, size = 0, x = 0, y = 0}
	-- ARENA
	self.defaults.profile.units.arena.enabled = false
	self.defaults.profile.units.arena.attribPoint = "TOP"
	self.defaults.profile.units.arena.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.arena.auras.debuffs.maxRows = 1
	self.defaults.profile.units.arena.auras.buffs.maxRows = 1
	self.defaults.profile.units.arena.offset = 0
	self.defaults.profile.units.arena.indicators.arenaSpec = {enabled = true, size = 0, x = 0, y = 0}
	self.defaults.profile.units.arena.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	-- BATTLEGROUND
	self.defaults.profile.units.battleground.enabled = false
	self.defaults.profile.units.battleground.attribPoint = "TOP"
	self.defaults.profile.units.battleground.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.battleground.auras.debuffs.maxRows = 1
	self.defaults.profile.units.battleground.auras.buffs.maxRows = 1
	self.defaults.profile.units.battleground.offset = 0
	-- BOSS
	self.defaults.profile.units.boss.enabled = false
	self.defaults.profile.units.boss.attribPoint = "TOP"
	self.defaults.profile.units.boss.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.boss.auras.debuffs.maxRows = 1
	self.defaults.profile.units.boss.auras.buffs.maxRows = 1
	self.defaults.profile.units.boss.offset = 0
	self.defaults.profile.units.boss.altPowerBar.enabled = true
	-- RAID
	self.defaults.profile.units.raid.groupBy = "GROUP"
	self.defaults.profile.units.raid.sortOrder = "ASC"
	self.defaults.profile.units.raid.sortMethod = "INDEX"
	self.defaults.profile.units.raid.attribPoint = "TOP"
	self.defaults.profile.units.raid.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.raid.offset = 0
	self.defaults.profile.units.raid.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raid.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raid.combatText.enabled = false
	self.defaults.profile.units.raid.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	-- RAID PET
	self.defaults.profile.units.raidpet.groupBy = "GROUP"
	self.defaults.profile.units.raidpet.sortOrder = "ASC"
	self.defaults.profile.units.raidpet.sortMethod = "INDEX"
	self.defaults.profile.units.raidpet.attribPoint = "TOP"
	self.defaults.profile.units.raidpet.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.raidpet.offset = 0
	self.defaults.profile.units.raidpet.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raidpet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raidpet.combatText.enabled = false
	-- MAINTANK
	self.defaults.profile.units.maintank.roleFilter = "TANK"
	self.defaults.profile.units.maintank.groupFilter = "MAINTANK"
	self.defaults.profile.units.maintank.groupBy = "GROUP"
	self.defaults.profile.units.maintank.sortOrder = "ASC"
	self.defaults.profile.units.maintank.sortMethod = "INDEX"
	self.defaults.profile.units.maintank.attribPoint = "TOP"
	self.defaults.profile.units.maintank.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.maintank.offset = 0
	self.defaults.profile.units.maintank.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- MAINASSIST
	self.defaults.profile.units.mainassist.groupFilter = "MAINASSIST"
	self.defaults.profile.units.mainassist.groupBy = "GROUP"
	self.defaults.profile.units.mainassist.sortOrder = "ASC"
	self.defaults.profile.units.mainassist.sortMethod = "INDEX"
	self.defaults.profile.units.mainassist.attribPoint = "TOP"
	self.defaults.profile.units.mainassist.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.mainassist.offset = 0
	self.defaults.profile.units.mainassist.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYPET
	self.defaults.profile.positions.partypet.anchorTo = "$parent"
	self.defaults.profile.positions.partypet.anchorPoint = "RB"
	self.defaults.profile.units.partypet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGET
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGETTARGET
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}

	-- Aura indicators
	self.defaults.profile.auraIndicators = {
		disabled = {},
		missing = {},
		linked = {},
		indicators = {
			["tl"] = {name = L["Top Left"], anchorPoint = "TLI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = 4, y = -4, friendly = true, hostile = true},
			["tr"] = {name = L["Top Right"], anchorPoint = "TRI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = -3, y = -3, friendly = true, hostile = true},
			["bl"] = {name = L["Bottom Left"], anchorPoint = "BLI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = 4, y = 4, friendly = true, hostile = true},
			["br"] = {name = L["Bottom Right"], anchorPoint = "BRI", anchorTo = "$parent", height = 8, width = 8, alpha = 1.0, x = -4, y = -4, friendly = true, hostile = true},
			["c"] = {name = L["Center"], anchorPoint = "C", anchorTo = "$parent", height = 20, width = 20, alpha = 1.0, x = 0, y = 0, friendly = true, hostile = true},
		},
		filters = {
			["tl"] = {boss = {priority = 100}, curable = {priority = 100}},
			["tr"] = {boss = {priority = 100}, curable = {priority = 100}},
			["bl"] = {boss = {priority = 100}, curable = {priority = 100}},
			["br"] = {boss = {priority = 100}, curable = {priority = 100}},
			["c"] = {boss = {priority = 100}, curable = {priority = 100}},
		},
		auras = {
			["20707"] = [[{indicator = '', group = "Warlock", priority = 10, r = 0.42, g = 0.21, b = 0.65}]],
			["116849"] = [[{r=0.19607843137255, group="Monk", indicator="c", g=1, player=false, duration=true, b=0.3843137254902, alpha=1, priority=0, icon=true, iconTexture="Interface\\Icons\\ability_monk_chicocoon"}]],
			["155777"] = [[{r=0.57647058823529, group="Druid", indicator="tr", g=0.28235294117647, player=true, duration=true, b=0.6156862745098, priority=100, alpha=1, iconTexture="Interface\\Icons\\Spell_Nature_Rejuvenation"}]],
			["121176"] = [[{alpha=1, b=0, priority=0, r=0.062745098039216, group="PvP Flags", indicator="bl", g=1, iconTexture="Interface\\Icons\\INV_BannerPVP_03"}]],
			["19705"] = [[{r=0.80392156862745, group="Food", indicator="", g=0.76470588235294, missing=true, duration=true, priority=0, alpha=1, b=0.24313725490196}]],
			["53563"] = [[{r=0.64313725490196, group="Paladin", indicator="tr", g=0.24705882352941, player=true, alpha=1, b=0.73333333333333, priority=100, duration=false, iconTexture="Interface\\Icons\\Ability_Paladin_BeaconofLight"}]],
			["774"] = [[{r=0.57647058823529, group="Druid", indicator="tr", g=0.28235294117647, player=true, duration=true, b=0.6156862745098, priority=100, alpha=1, iconTexture="Interface\\Icons\\Spell_Nature_Rejuvenation"}]],
			["33206"] = [[{r=0, group="Priest", indicator="c", g=0, b=0, duration=true, priority=0, icon=true, iconTexture="Interface\\Icons\\Spell_Holy_PainSupression"}]],
			["6788"] = [[{b=0.29019607843137, group="Priest", indicator="tl", alpha=1, player=false, g=0.56862745098039, duration=true, r=0.83921568627451, priority=20, icon=false, iconTexture="Interface\\Icons\\Spell_Holy_AshesToAshes"}]],
			["33763"] = [[{r=0.23137254901961, group="Druid", indicator="tl", g=1, player=true, duration=true, alpha=1, priority=0, b=0.2, iconTexture="Interface\\Icons\\INV_Misc_Herb_Felblossom"}]],
			["139"] = [[{r=0.23921568627451, group="Priest", indicator="tr", g=1, player=true, alpha=1, duration=true, b=0.39607843137255, priority=10, icon=false, iconTexture="Interface\\Icons\\Spell_Holy_Renew"}]],
			["41635"] = [[{r=1, group="Priest", indicator="br", g=0.90196078431373, missing=false, player=true, duration=false, alpha=1, b=0, priority=50, icon=false, iconTexture="Interface\\Icons\\Spell_Holy_PrayerOfMendingtga"}]],
			["47788"] = [[{r=0, group="Priest", indicator="c", g=0, b=0, duration=true, priority=0, icon=true, iconTexture="Interface\\Icons\\Spell_Holy_GuardianSpirit"}]],
			["61295"] = [[{r=0.17647058823529, group="Shaman", indicator="tl", g=0.4, player=true, alpha=1, duration=true, b=1, priority=0, icon=false, iconTexture="Interface\\Icons\\spell_nature_riptide"}]],
			["17"] = [[{r=1, group="Priest", indicator="tl", g=0.41960784313725, player=true, alpha=1, duration=true, b=0.5843137254902, priority=0, icon=false, iconTexture="Interface\\Icons\\Spell_Holy_PowerWordShield"}]],
			["152118"] = [[{r=1, group="Priest", indicator="tl", g=0.41960784313725, player=true, alpha=1, duration=true, b=0.5843137254902, priority=0, icon=false, iconTexture="Interface\\Icons\\Ability_Priest_ClarityOfWill"}]],
			["23335"] = [[{r=0, group="PvP Flags", indicator="bl", g=0, duration=false, b=0, priority=0, icon=true, iconTexture="Interface\\Icons\\INV_BannerPVP_02"}]],
			["102342"] = [[{r=0, group="Druid", indicator="c", g=0, duration=true, b=0, priority=0, icon=true, iconTexture="Interface\\Icons\\spell_druid_ironbark"}]],
			["121177"] = [[{r=0.78039215686275, group="PvP Flags", indicator="bl", g=0.42352941176471, alpha=1, b=0, priority=0, icon=false, iconTexture="Interface\\Icons\\INV_BannerPVP_03"}]],
			["586"] = [[{r=0, group="Priest", indicator="", g=0.85882352941176, selfColor={alpha=1, b=1, g=0.93725490196078, r=0, }, alpha=1, priority=0, b=1, iconTexture="Interface\\Icons\\Spell_Magic_LesserInvisibilty"}]],
			["23333"] = [[{icon=true, b=0, priority=0, r=0, group="PvP Flags", indicator="bl", g=0, iconTexture="Interface\\Icons\\INV_BannerPVP_01"}]],
			["119611"] = [[{r=0.26274509803922, group="Monk", indicator="tl", g=0.76078431372549, player=true, duration=true, alpha=1, b=0.53725490196078, priority=0, icon=false, iconTexture="Interface\\Icons\\ability_monk_renewingmists"}]],
			["8936"] = [[{r=0.12156862745098, group="Druid", indicator="br", g=0.45882352941176, player=true, duration=true, b=0.12156862745098, priority=100, alpha=1, iconTexture="Interface\\Icons\\Spell_Nature_ResistNature"}]],
			["34976"] = [[{r=0, group="PvP Flags", indicator="bl", g=0, player=false, b=0, priority=0, icon=true, iconTexture="Interface\\Icons\\INV_BannerPVP_03"}]],
			["121164"] = [[{alpha=1, b=1, priority=0, r=0, group="PvP Flags", indicator="bl", g=0.003921568627451, iconTexture="Interface\\Icons\\INV_BannerPVP_03"}]],
			["48438"] = [[{r=0.55294117647059, group="Druid", indicator="31685", g=1, player=true, duration=true, b=0.3921568627451, priority=100, alpha=1, iconTexture="Interface\\Icons\\Ability_Druid_Flourish"}]],
			["1022"] = [[{r=0, group="Paladin", indicator="c", g=0, player=false, duration=true, b=0, priority=0, icon=true, iconTexture="Interface\\Icons\\Spell_Holy_SealOfProtection"}]],
			["121175"] = [[{r=1, group="PvP Flags", indicator="bl", g=0.24705882352941, b=0.90196078431373, alpha=1, priority=0, icon=false, iconTexture="Interface\\Icons\\INV_BannerPVP_03"}]],
			["64844"] = [[{r=0.67843137254902, group="Priest", indicator="31685", g=0.30588235294118, player=true, alpha=1, priority=0, b=0.14117647058824, iconTexture="Interface\\Icons\\Spell_Holy_DivineProvidence"}]],
			["124081"] = [[{r=0.51372549019608, group="Monk", indicator="br", g=1, player=true, duration=true, b=0.90588235294118, alpha=1, priority=100, icon=false, iconTexture="Interface\\Icons\\ability_monk_forcesphere"}]],
			["29166"] = [[{r=0, group="Druid", indicator="c", g=0, b=0, duration=true, priority=0, icon=true, iconTexture="Interface\\Icons\\Spell_Nature_Lightning"}]],
			["189895"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\INV_Enchant_VoidSphere\";}",
			["189627"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\achievement_zone_cataclysmgreen\";}",
			["181306"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Mage_LivingBomb\";}",
			["181753"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_felarakkoa_feldetonation_green\";}",
			["188929"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Hunter_MarkedForDeath\";}",
			["189032"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_green\";}",
			["182826"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Fire_FelFlameRing\";}",
			["181515"] = "{b=0;g=0;priority=1;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_SeedOfDestruction\";}",
			["179219"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_felarakkoa_feldetonation_red\";}",
			["179864"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Arcane_PrismaticCloak\";}",
			["184124"] = "{b=0;g=0;priority=1;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_AntiMagicShell\";}",
			["184450"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfelorcs_necromancer_purple\";}",
			["186134"] = "{icon=true;b=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"tr\";g=0;iconTexture=\"Interface\\\\Icons\\\\spell_fel_elementaldevastation\";}",
			["185066"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfelorcs_necromancer_red\";}",
			["183817"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Ability_Warlock_EverlastingAffliction\";}",
			["179978"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossgorefiend_touchofdoom\";}",
			["182280"] = "{icon=true;b=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\Ability_Hunter_MarkedForDeath\";}",
			["189031"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_yellow\";}",
			["186500"] = "{b=0;g=0;priority=1;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"INTERFACE\\\\ICONS\\\\inv_misc_steelweaponchain\";}",
			["188666"] = "{b=0;g=0;priority=1;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"INTERFACE\\\\ICONS\\\\ability_warlock_soulsiphon\";}",
			["186333"] = "{b=0;g=0;priority=1;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_DevouringPlague\";}",
			["186135"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"tr\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_AntiShadow\";}",
			["181275"] = "{icon=true;b=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;iconTexture=\"Interface\\\\Icons\\\\spell_warlock_summonterrorguard\";}",
			["181957"] = "{b=0;g=0;priority=2;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Frost_ArcticWinds\";}",
			["189030"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_malkorok_blightofyshaarj_red\";}",
			["182178"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_arakkoa_spinning_blade\";}",
			["189777"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"INTERFACE\\\\ICONS\\\\inv_misc_steelweaponchain\";}",
			["186407"] = "{r=0;indicator=\"c\";b=0;group=\"Hellfire Citadel\";priority=2;g=0;iconTexture=\"Interface\\\\Icons\\\\spell_fel_incinerate\";}",
			["180166"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"tr\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_ChillTouch\";}",
			["180079"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\inv_blacksmithdye_black\";}",
			["184449"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfelorcs_necromancer_purple\";}",
			["185510"] = "{r=0;icon=true;indicator=\"tr\";b=0;group=\"Hellfire Citadel\";priority=1;g=0;iconTexture=\"INTERFACE\\\\ICONS\\\\inv_misc_steelweaponchain\";}",
			["185065"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossfelorcs_necromancer_orange\";}",
			["182769"] = "{r=0;icon=true;indicator=\"tr\";b=0;group=\"Hellfire Citadel\";priority=0;g=0;iconTexture=\"Interface\\\\Icons\\\\ability_fixated_state_purple\";}",
			["181508"] = "{b=0;group=\"Hellfire Citadel\";indicator=\"c\";g=0;alpha=1;r=0;priority=1;icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_SeedOfDestruction\";}",
			["181099"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_AuraOfDarkness\";}",
			["181307"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\Spell_Shadow_Requiem\";}",
			["183865"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_warlock_shadowfurytga\";}",
			["186961"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_warlock_moltencoregreen\";}",
			["182200"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_arakkoa_spinning_blade\";}",
			["181597"] = "{b=0;g=0;priority=0;r=0;group=\"Hellfire Citadel\";indicator=\"c\";icon=true;iconTexture=\"Interface\\\\Icons\\\\ability_bossmannoroth_mannorothsgaze\";}",
		}
	}

	for classToken in pairs(RAID_CLASS_COLORS) do
		self.defaults.profile.auraIndicators.disabled[classToken] = {}
	end
end

-- Module APIs
function ShadowUF:RegisterModule(module, key, name, isBar, class, spec, level)
	-- Prevent duplicate registration for deprecated plugin
	if( key == "auraIndicators" and C_AddOns.IsAddOnLoaded("ShadowedUF_Indicators") and self.modules.auraIndicators ) then
		self:Print(L["WARNING! ShadowedUF_Indicators has been deprecated as v4 and is now built in. Please delete ShadowedUF_Indicators, your configuration will be saved."])
		return
	end

	self.modules[key] = module

	module.moduleKey = key
	module.moduleHasBar = isBar
	module.moduleName = name
	module.moduleClass = class
	module.moduleLevel = level

	if( type(spec) == "number" ) then
		module.moduleSpec = {}
		module.moduleSpec[spec] = true
	elseif( type(spec) == "table" ) then
		module.moduleSpec = {}
		for _, id in pairs(spec) do
			module.moduleSpec[id] = true
		end
	end

	table.insert(self.moduleOrder, module)
end

function ShadowUF:FireModuleEvent(event, frame, unit)
	for _, module in pairs(self.moduleOrder) do
		if( module[event] ) then
			module[event](module, frame, unit)
		end
	end
end

-- Profiles changed
-- I really dislike this solution, but if we don't do it then there is setting issues
-- because when copying a profile, AceDB-3.0 fires OnProfileReset -> OnProfileCopied
-- SUF then sees that on the new reset profile has no profile, tries to load one in
-- ... followed by the profile copying happen and it doesn't copy everything correctly
-- due to variables being reset already.
local resetTimer
function ShadowUF:ProfileReset()
	if( not resetTimer ) then
		resetTimer = CreateFrame("Frame")
		resetTimer:SetScript("OnUpdate", function(f)
			ShadowUF:ProfilesChanged()
			f:Hide()
		end)
	end

	resetTimer:Show()
end

function ShadowUF:ProfilesChanged()
	if( self.layoutImporting ) then return end
	if( resetTimer ) then resetTimer:Hide() end

	self.db:RegisterDefaults(self.defaults)

	-- No active layout, register the default one
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
		self:CheckBuild()
	end

	self.db.profile.revision = self.dbRevision

	self:FireModuleEvent("OnProfileChange")
	self:LoadUnits()
	self:HideBlizzardFrames()
	self.Layout:CheckMedia()
	self.Units:ProfileChanged()
	self.modules.movers:Update()
end

ShadowUF.noop = function() end
ShadowUF.hiddenFrame = CreateFrame("Frame")
ShadowUF.hiddenFrame:Hide()

local rehideFrame = function(self)
	if( not InCombatLockdown() ) then
		self:Hide()
	end
end

local function basicHideBlizzardFrames(...)
	for i=1, select("#", ...) do
		local frame = select(i, ...)
		frame:UnregisterAllEvents()
		frame:HookScript("OnShow", rehideFrame)
		frame:Hide()
	end
end

local function hideBlizzardFrames(taint, ...)
	for i=1, select("#", ...) do
		local frame = select(i, ...)
		UnregisterUnitWatch(frame)
		frame:UnregisterAllEvents()
		frame:Hide()

		if( frame.manabar ) then frame.manabar:UnregisterAllEvents() end
		if( frame.healthbar ) then frame.healthbar:UnregisterAllEvents() end
		if( frame.spellbar ) then frame.spellbar:UnregisterAllEvents() end
		if( frame.powerBarAlt ) then frame.powerBarAlt:UnregisterAllEvents() end

		if( taint ) then
			frame.Show = ShadowUF.noop
		else
			frame:SetParent(ShadowUF.hiddenFrame)
			frame:HookScript("OnShow", rehideFrame)
		end
	end
end

local active_hiddens = {}
function ShadowUF:HideBlizzardFrames()
	if( self.db.profile.hidden.cast and not active_hiddens.cast ) then
		hideBlizzardFrames(true, CastingBarFrame, PetCastingBarFrame)
	end

	if( self.db.profile.hidden.party and not active_hiddens.party ) then
		for i=1, MAX_PARTY_MEMBERS do
			local name = "PartyMemberFrame" .. i
			hideBlizzardFrames(false, _G[name], _G[name .. "HealthBar"], _G[name .. "ManaBar"])
		end

		-- This stops the compact party frame from being shown
		UIParent:UnregisterEvent("GROUP_ROSTER_UPDATE")

		-- This just makes sure
		if( CompactPartyFrame ) then
			hideBlizzardFrames(false, CompactPartyFrame)
		end
	end

	if( CompactRaidFrameManager ) then
		if( self.db.profile.hidden.raid and not active_hiddens.raidTriggered ) then
			active_hiddens.raidTriggered = true

			local function hideRaid()
				CompactRaidFrameManager:UnregisterAllEvents()
				CompactRaidFrameContainer:UnregisterAllEvents()
				if( InCombatLockdown() ) then return end

				CompactRaidFrameManager:Hide()
				local shown = CompactRaidFrameManager_GetSetting("IsShown")
				if( shown and shown ~= "0" ) then
					CompactRaidFrameManager_SetSetting("IsShown", "0")
				end
			end

			hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
				if( self.db.profile.hidden.raid ) then
					hideRaid()
				end
			end)

			hideRaid()
			CompactRaidFrameContainer:HookScript("OnShow", hideRaid)
			CompactRaidFrameManager:HookScript("OnShow", hideRaid)
		end
	end

	if( self.db.profile.hidden.buffs and not active_hiddens.buffs ) then
		hideBlizzardFrames(false, BuffFrame, TemporaryEnchantFrame)
	end

	if( self.db.profile.hidden.player and not active_hiddens.player ) then
		hideBlizzardFrames(false, PlayerFrame)

		-- We keep these in case someone is still using the default auras, otherwise it messes up vehicle stuff
		PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		PlayerFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_EXITED_VEHICLE")											  
		PlayerFrame:SetMovable(true)
		PlayerFrame:SetUserPlaced(true)
		PlayerFrame:SetDontSavePosition(true)
	end

	if( self.db.profile.hidden.pet and not active_hiddens.pet ) then
		hideBlizzardFrames(false, PetFrame)
	end

	if( self.db.profile.hidden.target and not active_hiddens.target ) then
		hideBlizzardFrames(false, TargetFrame, ComboFrame, TargetFrameToT)
	end

	if( self.db.profile.hidden.focus and not active_hiddens.focus and FocusFrame and FocusFrameToT ) then
		hideBlizzardFrames(false, FocusFrame, FocusFrameToT)
	end

	if( self.db.profile.hidden.boss and not active_hiddens.boss ) then
													
		for i=1, MAX_BOSS_FRAMES do
			local name = "Boss" .. i .. "TargetFrame"

			hideBlizzardFrames(false, _G[name], _G[name .. "HealthBar"], _G[name .. "ManaBar"])

		end
	end

	-- As a reload is required to reset the hidden hooks, we can just set this to true if anything is true
	for type, flag in pairs(self.db.profile.hidden) do
		if( flag ) then
			active_hiddens[type] = true
		end
	end
end

-- Upgrade info
local infoMessages = {
	-- Old messages we don't need anymore
	{}, {},
	{
		L["You must restart Shadowed Unit Frames."],
		L["If you don't, you will be unable to use any combo point features (Chi, Holy Power, Combo Points, Aura Points, etc) until you do so."]
	}
}

function ShadowUF:ShowInfoPanel()
	local infoID = ShadowUF.db.global.infoID or 0
	if( ShadowUF.ComboPoints and infoID < 3 ) then infoID = 3 end

	ShadowUF.db.global.infoID = #(infoMessages)
	if( infoID < 0 or infoID >= #(infoMessages) ) then return end

	local frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetWidth(500)
	frame:SetHeight(285)
	frame:SetBackdrop({
		  bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		  edgeSize = 26,
		  insets = {left = 9, right = 9, top = 9, bottom = 9},
	})
	frame:SetBackdropColor(0, 0, 0, 0.85)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

	frame.titleBar = frame:CreateTexture(nil, "ARTWORK")
	frame.titleBar:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	frame.titleBar:SetPoint("TOP", 0, 8)
	frame.titleBar:SetWidth(350)
	frame.titleBar:SetHeight(45)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.title:SetPoint("TOP", 0, 0)
	frame.title:SetText("Shadowed Unit Frames")

	frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	frame.text:SetText(table.concat(infoMessages[ShadowUF.db.global.infoID], "\n"))
	frame.text:SetPoint("TOPLEFT", 12, -22)
	frame.text:SetWidth(frame:GetWidth() - 20)
	frame.text:SetJustifyH("LEFT")
	frame:SetHeight(frame.text:GetHeight() + 70)

	frame.hide = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.hide:SetText(L["Ok"])
	frame.hide:SetHeight(20)
	frame.hide:SetWidth(100)
	frame.hide:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
	frame.hide:SetScript("OnClick", function(f)
		f:GetParent():Hide()
	end)
end

function ShadowUF:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Shadow UF|r: " .. msg)
end

CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS["Shadowed Unit Frames"] = function(mode)
	if( mode == "ON" ) then
		ShadowUF.db.profile.locked = false
		ShadowUF.modules.movers.isConfigModeSpec = true
	elseif( mode == "OFF" ) then
		ShadowUF.db.profile.locked = true
	end

	ShadowUF.modules.movers:Update()
end

SLASH_SHADOWEDUF1 = "/suf"
SLASH_SHADOWEDUF2 = "/shadowuf"
SLASH_SHADOWEDUF3 = "/shadoweduf"
SLASH_SHADOWEDUF4 = "/shadowedunitframes"
SlashCmdList["SHADOWEDUF"] = function(msg)
	msg = msg and string.lower(msg)
	if( msg and string.match(msg, "^profile (.+)") ) then
		local profile = string.match(msg, "^profile (.+)")

		for id, name in pairs(ShadowUF.db:GetProfiles()) do
			if( string.lower(name) == profile ) then
				ShadowUF.db:SetProfile(name)
				ShadowUF:Print(string.format(L["Changed profile to %s."], name))
				return
			end
		end

		ShadowUF:Print(string.format(L["Cannot find any profiles named \"%s\"."], profile))
		return
	end

	local loaded, reason = C_AddOns.LoadAddOn("ShadowedUF_Options")
	if( not ShadowUF.Config ) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(L["Failed to load ShadowedUF_Options, cannot open configuration. Error returned: %s"], reason and _G["ADDON_" .. reason] or ""))
		return
	end

	ShadowUF.Config:Open()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
	if( event == "PLAYER_LOGIN" ) then
		ShadowUF:OnInitialize()
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif( event == "ADDON_LOADED" and ( addon == "Blizzard_ArenaUI" or addon == "Blizzard_CompactRaidFrames" ) ) then
		ShadowUF:HideBlizzardFrames()
	end
end)
