local config = {
	[51588] = { gainWeaponProficiencyExperience = 25000 },
	[51589] = { gainWeaponProficiencyExperience = 100000 },
}

local proficiencyCatalysts = Action()

function proficiencyCatalysts.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local now = os.time()
	local nextUse = player:kv():get("proficiency-catalyst-delay") or 0
	if nextUse > now then
		player:sendCancelMessage("Wait a moment before using another proficiency catalyst.")
		return true
	end

	if not target or type(target) ~= "userdata" or not target:isItem() then
		return false
	end

	local targetType = target:getType()
	if not targetType then
		return false
	end

	if targetType:getWeaponType() == WEAPON_SWORD or targetType:getWeaponType() == WEAPON_CLUB or targetType:getWeaponType() == WEAPON_AXE or targetType:getWeaponType() == WEAPON_DISTANCE or targetType:getWeaponType() == WEAPON_WAND or targetType:getWeaponType() == WEAPON_MISSILE or targetType:getWeaponType() == WEAPON_FIST then
		local configData = config[item.itemid]
		if not configData then
			return false
		end

		player:kv():set("proficiency-catalyst-delay", now + 3)
		player:sendWeaponProficiencyExperience(target:getId(), configData.gainWeaponProficiencyExperience)

		item:remove(1)
		return true
	end

	return false
end

proficiencyCatalysts:id(51588, 51589)
proficiencyCatalysts:register()
