local proficiencyCatalysts = Action()

function proficiencyCatalysts.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	player:sendCancelMessage("Weapon proficiency is gained only by killing monsters.")
	return true
end

proficiencyCatalysts:id(51588, 51589)
proficiencyCatalysts:register()
