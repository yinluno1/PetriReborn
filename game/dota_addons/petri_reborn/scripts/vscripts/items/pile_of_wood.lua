function Use( event )
	local caster = event.caster
	local ability = event.ability

	local woodModifier = ability:GetLevelSpecialValueFor("wood_modifier", -1)

	caster:EmitSound("ui.inv_pickup_wood")

	local hero = GameMode.assignedPlayerHeroes[caster:GetPlayerOwnerID()]

	local amount = math.floor(GameRules:GetDOTATime(false,false) * woodModifier / 60)

	PlusParticle(amount, Vector(10, 200, 90), 1.0, caster)

	hero.lumber = hero.lumber + amount
end