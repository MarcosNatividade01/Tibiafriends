SpellTrainer = SpellTrainer or {}

local vocationAliases = {
	["sorcerer"] = VOCATION.BASE_ID.SORCERER,
	["master sorcerer"] = VOCATION.BASE_ID.SORCERER,
	["druid"] = VOCATION.BASE_ID.DRUID,
	["elder druid"] = VOCATION.BASE_ID.DRUID,
	["paladin"] = VOCATION.BASE_ID.PALADIN,
	["royal paladin"] = VOCATION.BASE_ID.PALADIN,
	["knight"] = VOCATION.BASE_ID.KNIGHT,
	["elite knight"] = VOCATION.BASE_ID.KNIGHT,
	["monk"] = VOCATION.BASE_ID.MONK,
	["exalted monk"] = VOCATION.BASE_ID.MONK,
}

local knownPrices = {
	["Find Person"] = 80,
	["Light"] = 0,
	["Light Healing"] = 0,
	["Wound Cleansing"] = 0,
	["Cure Poison"] = 150,
	["Magic Rope"] = 200,
	["Great Light"] = 500,
	["Levitate"] = 500,
	["Haste"] = 600,
	["Conjure Arrow"] = 450,
	["Conjure Poisoned Arrow"] = 700,
	["Conjure Bolt"] = 750,
	["Brutal Strike"] = 1000,
}

local function compactKeyword(text)
	return text:lower():gsub("[^%w]", "")
end

local function spellPrice(spell)
	local price = knownPrices[spell.name]
	if price then
		return price
	end

	if spell.level <= 8 then
		return 0
	end

	return spell.level * 100
end

local function shellQuote(path)
	if package.config:sub(1, 1) == "\\" then
		return '"' .. path:gsub('"', '\\"') .. '"'
	end

	return "'" .. path:gsub("'", "'\\''") .. "'"
end

local function listSpellFiles(root)
	local files = {}
	local command
	if package.config:sub(1, 1) == "\\" then
		command = "dir /b /s " .. shellQuote(root .. "\\*.lua")
	else
		command = "find " .. shellQuote(root) .. " -type f -name '*.lua'"
	end

	local handle = io.popen(command, "r")
	if not handle then
		return files
	end

	for file in handle:lines() do
		files[#files + 1] = file
	end
	handle:close()
	return files
end

local function readFile(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end

	local contents = file:read("*a")
	file:close()
	return contents
end

local function parseVocations(contents)
	local flattenedContents = contents:gsub("[\r\n]+", " ")
	local vocationCall = flattenedContents:match("spell:vocation%((.-)%)")
	if not vocationCall then
		return nil
	end

	local seen = {}
	local vocations = {}
	for rawVocation in vocationCall:gmatch('"([^"]+)"') do
		local vocationName = rawVocation:match("^([^;]+)")
		local vocationId = vocationAliases[vocationName and vocationName:lower()]
		if vocationId and not seen[vocationId] then
			seen[vocationId] = true
			vocations[#vocations + 1] = vocationId
		end
	end

	if #vocations == 0 then
		return nil
	end
	return vocations
end

local function parseSpellFile(path)
	if path:find("\\monster\\") or path:find("/monster/") or path:find("\\house\\") or path:find("/house/") then
		return nil
	end

	local contents = readFile(path)
	if not contents or not contents:find("spell:needLearn%(true%)") then
		return nil
	end

	local name = contents:match('spell:name%("([^"]+)"%)')
	local words = contents:match('spell:words%("([^"]+)"%)')
	local level = tonumber(contents:match("spell:level%((%d+)%)")) or 0
	local vocations = parseVocations(contents)
	if not name or not words or not vocations then
		return nil
	end

	return {
		name = name,
		words = words,
		level = level,
		vocations = vocations,
	}
end

local function loadSpells()
	if SpellTrainer.spells then
		return SpellTrainer.spells
	end

	local spells = {}
	local seenNames = {}
	for _, path in ipairs(listSpellFiles(CORE_DIRECTORY .. "/scripts/spells")) do
		local spell = parseSpellFile(path)
		if spell and not seenNames[spell.name] then
			seenNames[spell.name] = true
			spells[#spells + 1] = spell
		end
	end

	table.sort(spells, function(left, right)
		if left.level == right.level then
			return left.name < right.name
		end
		return left.level < right.level
	end)

	SpellTrainer.spells = spells
	return spells
end

local function hasVocation(spell, vocation)
	for _, spellVocation in ipairs(spell.vocations) do
		if spellVocation == vocation then
			return true
		end
	end
	return false
end

local function registerSpell(keywordHandler, npcHandler, spell, vocation)
	local aliases = {
		compactKeyword(spell.name),
		spell.name:lower(),
		spell.words:lower(),
	}
	local seenAliases = {}

	for _, alias in ipairs(aliases) do
		if alias ~= "" and not seenAliases[alias] then
			seenAliases[alias] = true
			keywordHandler:addSpellKeyword({ alias }, {
				npcHandler = npcHandler,
				spellName = spell.name,
				price = spellPrice(spell),
				level = spell.level,
				vocation = vocation,
			})
		end
	end
end

function SpellTrainer.registerVocation(keywordHandler, npcHandler, vocation, categories)
	local count = 0
	for _, spell in ipairs(loadSpells()) do
		if hasVocation(spell, vocation) then
			registerSpell(keywordHandler, npcHandler, spell, vocation)
			count = count + 1
		end
	end

	local categoryText = categories or "I can teach you spells for your vocation. Tell me the spell name or its magic words."
	keywordHandler:addKeyword({ "spells" }, StdModule.say, {
		npcHandler = npcHandler,
		text = count > 0 and categoryText or "I cannot teach any spells right now.",
	})
	keywordHandler:addKeyword({ "spell" }, StdModule.say, {
		npcHandler = npcHandler,
		text = count > 0 and categoryText or "I cannot teach any spells right now.",
	})
	keywordHandler:addKeyword({ "list" }, StdModule.say, {
		npcHandler = npcHandler,
		text = count > 0 and "Tell me the name of the spell you want to learn. I will check your vocation, level and money before teaching it." or "I cannot teach any spells right now.",
	})
end
