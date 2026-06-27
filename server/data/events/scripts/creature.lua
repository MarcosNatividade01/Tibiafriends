local function removeCombatProtection(playerUid)
	local player = Player(playerUid)
	if not player then
		return true
	end

	local time = 0
	if player:isMage() then
		time = 10
	elseif player:isPaladin() then
		time = 20
	else
		time = 30
	end

	player:kv():set("combat-protection", 2)
	addEvent(function(playerFuncUid)
		local playerEvent = Player(playerFuncUid)
		if not playerEvent then
			return
		end

		playerEvent:kv():remove("combat-protection")
		playerEvent:remove()
	end, time * 1000, playerUid)
end

function Creature:onTargetCombat(target)
	if not self then
		return true
	end

	if target:isPlayer() then
		if self:isMonster() then
			local isProtected = target:kv():get("combat-protection") or 0

			if target:getIp() == 0 then -- If player is disconnected, monster shall ignore to attack the player
				if target:isPzLocked() then
					return true
				end
				if isProtected <= 0 then
					addEvent(removeCombatProtection, 30 * 1000, target.uid)
					target:kv():set("combat-protection", 1)
				elseif isProtected == 1 then
					self:searchTarget()
					return RETURNVALUE_YOUMAYNOTATTACKTHISPLAYER
				end

				return true
			end

			if isProtected >= os.time() then
				return RETURNVALUE_YOUMAYNOTATTACKTHISPLAYER
			end
		end
	end

	if (target:isMonster() and self:isPlayer() and target:getMaster() == self) or (self:isMonster() and target:isPlayer() and self:getMaster() == target) then
		return RETURNVALUE_YOUMAYNOTATTACKTHISCREATURE
	end

	if not IsRetroPVP() or PARTY_PROTECTION ~= 0 then
		if self:isPlayer() and target:isPlayer() then
			local party = self:getParty()
			if party then
				local targetParty = target:getParty()
				if targetParty and targetParty == party then
					return RETURNVALUE_YOUMAYNOTATTACKTHISPLAYER
				end
			end
		end
	end

	if not IsRetroPVP() or ADVANCED_SECURE_MODE ~= 0 then
		if self:isPlayer() and target:isPlayer() then
			if self:hasSecureMode() then
				return RETURNVALUE_YOUMAYNOTATTACKTHISPLAYER
			end
		end
	end

	self:addEventStamina(target)
	return true
end

function Creature:onChangeOutfit(outfit)
	if self:isPlayer() then
		local familiarLookType = self:getFamiliarLooktype()
		if familiarLookType ~= 0 then
			for _, summon in pairs(self:getSummons()) do
				if summon:getType():familiar() then
					if summon:getOutfit().lookType ~= familiarLookType then
						summon:setOutfit({ lookType = familiarLookType })
					end
					break
				end
			end
		end
	end
	return true
end

local function isWeaponProficiencyWeapon(item)
	if not item then
		return false
	end

	local itemType = item:getType()
	if not itemType then
		return false
	end

	local weaponType = itemType:getWeaponType()
	return weaponType == WEAPON_SWORD
		or weaponType == WEAPON_CLUB
		or weaponType == WEAPON_AXE
		or weaponType == WEAPON_DISTANCE
		or weaponType == WEAPON_WAND
		or weaponType == WEAPON_MISSILE
		or weaponType == WEAPON_FIST
end

local function getWeaponProficiencyPlayer(creature)
	if not creature then
		return nil
	end

	if creature:isPlayer() then
		return creature
	end

	local master = creature:getMaster()
	if master and master:isPlayer() then
		return master
	end

	return nil
end

local function getWeaponProficiencyKillExperience(monster)
	local monsterType = monster and monster:getType()
	if not monsterType or type(monsterType.experience) ~= "function" then
		return 0
	end

	local success, experience = pcall(function()
		return monsterType:experience()
	end)
	if not success then
		return 0
	end

	return math.max(0, math.floor(experience or 0))
end

local weaponProficiencyMonsterDeath = CreatureEvent("WeaponProficiencyMonsterDeath")

function weaponProficiencyMonsterDeath.onDeath(creature, corpse, killer, mostDamageKiller, unjustified, mostDamageUnjustified)
	if not creature or not creature:isMonster() then
		return true
	end

	local player = getWeaponProficiencyPlayer(killer) or getWeaponProficiencyPlayer(mostDamageKiller)

	if not player then
		return true
	end

	local weapon = player:getSlotItem(CONST_SLOT_LEFT)
	if not isWeaponProficiencyWeapon(weapon) then
		return true
	end

	local proficiencyExperience = getWeaponProficiencyKillExperience(creature)
	if proficiencyExperience > 0 then
		player:sendWeaponProficiencyExperience(weapon:getId(), proficiencyExperience)
	end

	return true
end

weaponProficiencyMonsterDeath:register()

function Creature:onDrainHealth(attacker, typePrimary, damagePrimary, typeSecondary, damageSecondary, colorPrimary, colorSecondary)
	if not self then
		return typePrimary, damagePrimary, typeSecondary, damageSecondary, colorPrimary, colorSecondary
	end

	if not attacker then
		return typePrimary, damagePrimary, typeSecondary, damageSecondary, colorPrimary, colorSecondary
	end

	if self:isMonster() and getWeaponProficiencyPlayer(attacker) then
		self:registerEvent("WeaponProficiencyMonsterDeath")
	end
	return typePrimary, damagePrimary, typeSecondary, damageSecondary, colorPrimary, colorSecondary
end
