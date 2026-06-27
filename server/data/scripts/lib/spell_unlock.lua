function syncPlayerSpellsByLevel(player)
	local unlocked = 0

	for _, spell in ipairs(player:getInstantSpells()) do
		local requiredLevel = spell.level or 0
		local requiredMagicLevel = spell.mlevel or 0

		if spell.name
			and (requiredLevel > 0 or requiredMagicLevel > 0)
			and not player:hasLearnedSpell(spell.name) then
			player:learnSpell(spell.name)
			unlocked = unlocked + 1
		end
	end

	return unlocked
end
