function CancelBuilding(caster, ability, pID, gold_cost, reason)
	Notifications:Top(caster:GetPlayerOwnerID(),{text=reason, duration=4, style={color="red"}, continue=false})

	PlayerResource:ModifyGold(pID, gold_cost,false,0)

	ability:EndCooldown()
	return false
end

function build( keys )
	local player = keys.caster:GetPlayerOwner()
	local hero = player:GetAssignedHero()
	local pID = player:GetPlayerID()
	local caster = keys.caster

	local ability = keys.ability
	
	local gold_cost = ability:GetGoldCost(1)
	local lumber_cost = ability:GetLevelSpecialValueFor("lumber_cost", ability:GetLevel()-1)
	local food_cost = ability:GetLevelSpecialValueFor("food_cost", ability:GetLevel()-1)

	local enough_lumber
	local enough_food

	local ability_name = ability:GetName()

	--Build exit only after 16 min
	if ability:GetName() == "build_petri_exit" then
		if GameRules:GetGameTime() < (60 * PETRI_EXIT_MARK) + 30 then
			return CancelBuilding(caster, ability, pID, gold_cost, "#too_early_for_exit")
		end
	end

	-- Cancel building if limit is reached
	if hero.buildingCount >= PETRI_MAX_BUILDING_COUNT_PER_PLAYER then
		return CancelBuilding(caster, ability, pID, gold_cost, "#building_limit_is_reached")
	end

	-- Cancel building if building helper is active
	if player.waitingForBuildHelper == true then
		PlayerResource:ModifyGold(pID, gold_cost,false,0)

	    player.activeCallbacks.onConstructionCancelled()
	      
	    player.activeBuilder:ClearQueue()
	    player.activeBuilding = nil
	    player.activeBuilder:Stop()
	    player.activeBuilder.ProcessingBuilding = false

	    player.waitingForBuildHelper = false

	    CustomGameEventManager:Send_ServerToPlayer(player, "building_helper_force_cancel", {} )
		return
	end

	if gold_cost ~= nil then
		hero.lastSpentGold = gold_cost
	end

	if lumber_cost ~= nil then
		enough_lumber = CheckLumber(player, lumber_cost,true)
	else
		enough_lumber = true
	end

	if food_cost ~= nil and food_cost ~= 0 then
		enough_food = CheckFood(player, food_cost,true)
	else
		enough_food = true
	end

	if enough_food ~= true or enough_lumber ~= true then
		ReturnGold(player)
		EndCooldown(caster, ability_name)
		return
	else
		SpendLumber(player, lumber_cost)
		SpendFood(player, food_cost)
	end

	player.waitingForBuildHelper = true
	
	local returnTable = BuildingHelper:AddBuilding(keys)

	keys:OnBuildingPosChosen(function(vPos)

	end)

	keys:OnConstructionStarted(function(unit)
		hero.buildingCount = hero.buildingCount + 1

		if unit:GetUnitName() == "npc_petri_exit" then
			Notifications:TopToAll({text="#exit_construction_is_started", duration=10, style={color="blue"}, continue=false})

			local dummy = CreateUnitByName("petri_dummy_1400vision", keys.caster:GetAbsOrigin(), false, nil, nil, DOTA_TEAM_BADGUYS)
			Timers:CreateTimer(600, function() dummy:RemoveSelf() end)
		end

		-- Unit is the building be built.
		-- Play construction sound
		-- FindClearSpace for the builder
		FindClearSpaceForUnit(keys.caster, keys.caster:GetAbsOrigin(), true)
		unit.foodSpent = food_cost
		-- Very bad solution
		-- But when construction is started there is no way of cancelling it so...
		player.activeBuilder.work.callbacks.onConstructionCancelled = nil

		if caster:GetUnitName() == "npc_dota_hero_rattletrap" then
			if caster.currentMenu == 1 then
				caster:CastAbilityNoTarget(caster:FindAbilityByName("petri_close_basic_buildings_menu"), pID)
			elseif caster.currentMenu == 2 then
				caster:CastAbilityNoTarget(caster:FindAbilityByName("petri_close_advanced_buildings_menu"), pID)
			end
		end

		unit:SetMana(0)
		unit.tempManaRegen = unit:GetManaRegen()
		unit:SetBaseManaRegen(0.0)
	end)
	keys:OnConstructionCompleted(function(unit)
		InitAbilities(unit)

		if unit:GetUnitName() == "npc_petri_exit" then
			unit:CastAbilityNoTarget(unit:FindAbilityByName("petri_exit"),caster:GetPlayerOwnerID())
		end

		unit:SetMana(unit:GetMaxMana())
		unit:SetBaseManaRegen(unit.tempManaRegen)
		unit.tempManaRegen = nil

		if unit.controllableWhenReady then
			unit:SetControllableByPlayer(keys.caster:GetPlayerOwnerID(), true)
		end
		
		if caster.currentArea ~= nil then
			if CheckAreaClaimers(caster, keys.caster.currentArea.claimers) or caster.currentArea.claimers == nil then

				if caster.currentArea.claimers == nil then 
					Notifications:Top(pID, {text="#area_claimed", duration=4, style={color="white"}, continue=false})
				end

				keys.caster.currentArea.claimers = keys.caster.currentArea.claimers or {}
				if keys.caster.currentArea.claimers[0] == nil then keys.caster.currentArea.claimers[0] = keys.caster end
			else
				Notifications:Top(pID, {text="#you_cant_build", duration=4, style={color="white"}, continue=false})
				
				ReturnLumber(player)
				ReturnGold(player)
				ReturnFood( player )

				if ability:IsNull() ~= true then ability:EndCooldown() end

				-- Destroy unit
				DestroyEntityBasedOnHealth(caster,unit)
			end
		end
	end)

	-- These callbacks will only fire when the state between below half health/above half health changes.
	-- i.e. it won't unnecessarily fire multiple times.
	keys:OnBelowHalfHealth(function(unit)
	end)

	keys:OnAboveHalfHealth(function(unit)

	end)

	keys:OnConstructionFailed(function( building )
		ReturnLumber(player)
		ReturnGold(player)
		ReturnFood( player )

		EndCooldown(caster, ability_name)
	end)

	keys:OnConstructionCancelled(function( building )
		ReturnLumber(player)
		ReturnGold(player)
		ReturnFood( player )

		EndCooldown(caster, ability_name)
	end)

	-- Have a fire effect when the building goes below 50% health.
	-- It will turn off it building goes above 50% health again.
	keys:EnableFireEffect("modifier_jakiro_liquid_fire_burn")

  	if caster:GetUnitName() == "npc_dota_hero_rattletrap" then
		local basicMenu = caster:FindAbilityByName("petri_close_basic_buildings_menu")
		local advancedMenu = caster:FindAbilityByName("petri_close_advanced_buildings_menu")

		if basicMenu ~= nil then
			caster:CastAbilityNoTarget(basicMenu, pID)
		else
			caster:CastAbilityNoTarget(advancedMenu, pID)
		end
	end
end

function building_canceled( keys )
	BuildingHelper:CancelBuilding(keys)
end

function create_building_entity( keys )
	BuildingHelper:InitializeBuildingEntity(keys)
end

function builder_queue( keys )
    local ability = keys.ability
    local caster = keys.caster  

    if caster.ProcessingBuilding ~= nil then
        -- caster is probably a builder, stop them
        player = PlayerResource:GetPlayer(caster:GetMainControllingPlayer())
        player.activeBuilding = nil
        if player.activeBuilder and IsValidEntity(player.activeBuilder) then
            player.activeBuilder:ClearQueue()
            --player.activeBuilder:Stop()
            player.activeBuilder.ProcessingBuilding = false
        end
    end
end