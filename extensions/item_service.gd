extends "res://singletons/item_service.gd"

func _get_rand_item_for_wave(wave: int, player_index: int, type: int, args: GetRandItemForWaveArgs) -> ItemParentData:
	var player_character = RunData.get_player_character(player_index)
	var rand_wanted = randf()
	var item_tier = get_tier_from_wave(wave, player_index, args.increase_tier)

	if args.fixed_tier != - 1:
		item_tier = args.fixed_tier

	if type == TierData.WEAPONS:
		var min_weapon_tier = RunData.get_player_effect(Keys.min_weapon_tier_hash, player_index)
		var max_weapon_tier = RunData.get_player_effect(Keys.max_weapon_tier_hash, player_index)
		item_tier = clamp(item_tier, min_weapon_tier, max_weapon_tier)

	var banned_items = RunData.players_data[player_index].banned_items
	var pool = get_pool(item_tier, type)
	var backup_pool = get_pool(item_tier, type)
	var items_to_remove = []

	if banned_items.size() > 0:
		for item_id in banned_items:
			if item_id is String:
				var item_id_hash = Keys.generate_hash(item_id)
				pool = remove_element_by_id(pool, item_id_hash)
				backup_pool = remove_element_by_id(backup_pool, item_id_hash)
			else:
				pool = remove_element_by_id(pool, item_id)
				backup_pool = remove_element_by_id(backup_pool, item_id)

	for shop_item in args.excluded_items:
		pool = remove_element_by_id_with_item(pool, shop_item[0])
		backup_pool = remove_element_by_id_with_item(backup_pool, shop_item[0])

	if type == TierData.WEAPONS:
		var bonus_chance_same_weapon_set = max(0, (MAX_WAVE_ONE_WEAPON_GUARANTEED + 1 - RunData.current_wave) * (BONUS_CHANCE_SAME_WEAPON_SET / MAX_WAVE_ONE_WEAPON_GUARANTEED))
		var chance_same_weapon_set = CHANCE_SAME_WEAPON_SET + bonus_chance_same_weapon_set
		var bonus_chance_same_weapon = max(0, (MAX_WAVE_ONE_WEAPON_GUARANTEED + 1 - RunData.current_wave) * (BONUS_CHANCE_SAME_WEAPON / MAX_WAVE_ONE_WEAPON_GUARANTEED))
		var chance_same_weapon = CHANCE_SAME_WEAPON + bonus_chance_same_weapon

		var no_melee_weapons: bool = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, player_index)
		var no_ranged_weapons: bool = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, player_index)
		var no_duplicate_weapons: bool = RunData.get_player_effect_bool(Keys.no_duplicate_weapons_hash, player_index)
		var no_structures: bool = RunData.get_player_effect(Keys.remove_shop_items_hash, player_index).has(Keys.structure_hash)

		var player_sets: Array = RunData.get_player_sets(player_index)
		var unique_weapon_ids: Dictionary = RunData.get_unique_weapon_ids(player_index)

		for item in pool:
			if no_melee_weapons and item.type == WeaponType.MELEE:
				backup_pool = remove_element_by_id_with_item(backup_pool, item)
				items_to_remove.push_back(item)
				continue

			if no_ranged_weapons and item.type == WeaponType.RANGED:
				backup_pool = remove_element_by_id_with_item(backup_pool, item)
				items_to_remove.push_back(item)
				continue

			if no_duplicate_weapons:
				for weapon in unique_weapon_ids.values():
					if item.weapon_id_hash == weapon.weapon_id_hash and item.tier < weapon.tier:
						backup_pool = remove_element_by_id_with_item(backup_pool, item)
						items_to_remove.push_back(item)
						break
					elif item.my_id_hash == weapon.my_id_hash and weapon.upgrades_into == null:
						backup_pool = remove_element_by_id_with_item(backup_pool, item)
						items_to_remove.push_back(item)
						break

			if no_structures and EntityService.is_weapon_spawning_structure(item):
				backup_pool = remove_element_by_id_with_item(backup_pool, item)
				items_to_remove.append(item)

			if rand_wanted < chance_same_weapon:
				if not item.weapon_id in unique_weapon_ids:
					items_to_remove.push_back(item)
					continue

			elif rand_wanted < chance_same_weapon_set:
				var remove: = true
				for set in item.sets:
					if set.my_id_hash in player_sets:
						remove = false
				if remove:
					items_to_remove.push_back(item)
					continue

	elif type == TierData.ITEMS:
		var wanted_item_tag_chance = CHANCE_WANTED_ITEM_TAG
		if RunData.get_player_effects(player_index).has(Keys.stat_boosted_wanted_item_tag_hash) and RunData.get_player_effect_bool(Keys.stat_boosted_wanted_item_tag_hash, player_index):
			wanted_item_tag_chance = BOOSTED_WANTED_ITEM_TAG
		if Utils.get_chance_success(wanted_item_tag_chance) and player_character.wanted_tags.size() > 0:
			for item in pool:
				var has_wanted_tag = false
				for tag in item.tags:
					if player_character.wanted_tags.has(tag):
						has_wanted_tag = true
						break
				if not has_wanted_tag:
					items_to_remove.push_back(item)

		if args.forced_shop_tag != null:
			for item in pool:
				if not items_to_remove.has(item) and not item.tags.has(args.forced_shop_tag):
					items_to_remove.push_back(item)

		var remove_item_tags: Array = RunData.get_player_effect(Keys.remove_shop_items_hash, player_index)

		for tag_to_remove in remove_item_tags:
			for item in pool:
				if Keys.hash_to_string[tag_to_remove] in item.tags:
					items_to_remove.append(item)

		if RunData.current_wave < RunData.nb_of_waves:
			if player_character.banned_item_groups.size() > 0:
				for banned_item_group in player_character.banned_item_groups:
					if not banned_item_group in item_groups:
						continue
					for item in pool:
						if item_groups[banned_item_group].has(item.my_id):
							items_to_remove.append(item)

			if player_character.banned_items.size() > 0:
				for item in pool:
					if player_character.banned_items.has(item.my_id):
						items_to_remove.append(item)
		else:
			for item in pool:
				if banned_items_for_endless.has(item.my_id_hash):
					items_to_remove.append(item)

	var limited_items = get_limited_items(args.owned_and_shop_items)

	for key in limited_items:
		if limited_items[key][1] >= limited_items[key][0].max_nb:
			backup_pool = remove_element_by_id_with_item(backup_pool, limited_items[key][0])
			items_to_remove.push_back(limited_items[key][0])

	for item in items_to_remove:
		pool = remove_element_by_id_with_item(pool, item)

	var elt

	if pool.size() == 0:
		if backup_pool.size() > 0:
			elt = Utils.get_rand_element(backup_pool)
		else:
			# --- MODIFIED FALLBACK LOGIC TO PREVENT BANNED ITEMS APPEARING ---
			var valid_items = []
			
			var no_melee_weapons = false
			var no_ranged_weapons = false
			var no_duplicate_weapons = false
			var no_structures = false
			var unique_w_ids = {}
			
			if type == TierData.WEAPONS:
				no_melee_weapons = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, player_index)
				no_ranged_weapons = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, player_index)
				no_duplicate_weapons = RunData.get_player_effect_bool(Keys.no_duplicate_weapons_hash, player_index)
				no_structures = RunData.get_player_effect(Keys.remove_shop_items_hash, player_index).has(Keys.structure_hash)
				unique_w_ids = RunData.get_unique_weapon_ids(player_index)

			for t in range(_tiers_data.size()):
				var t_pool = get_pool(t, type)
				var filtered_t_pool = []
				
				for item in t_pool:
					var is_valid = true
					
					if banned_items.size() > 0:
						for item_id in banned_items:
							var hash_to_check = Keys.generate_hash(item_id) if item_id is String else item_id
							if item.my_id_hash == hash_to_check:
								is_valid = false
								break
					if not is_valid: continue
					
					for shop_item in args.excluded_items:
						if item.my_id_hash == shop_item[0].my_id_hash:
							is_valid = false
							break
					if not is_valid: continue
					
					for key in limited_items:
						if item.my_id_hash == limited_items[key][0].my_id_hash and limited_items[key][1] >= limited_items[key][0].max_nb:
							is_valid = false
							break
					if not is_valid: continue
					
					if type == TierData.WEAPONS:
						if no_melee_weapons and item.type == WeaponType.MELEE: continue
						if no_ranged_weapons and item.type == WeaponType.RANGED: continue
						if no_structures and EntityService.is_weapon_spawning_structure(item): continue
						if no_duplicate_weapons:
							var duplicate_found = false
							for weapon in unique_w_ids.values():
								if item.weapon_id_hash == weapon.weapon_id_hash and item.tier < weapon.tier:
									duplicate_found = true
									break
								elif item.my_id_hash == weapon.my_id_hash and weapon.upgrades_into == null:
									duplicate_found = true
									break
							if duplicate_found: continue
					
					filtered_t_pool.append(item)
				
				valid_items.append_array(filtered_t_pool)
			
			if valid_items.size() > 0:
				elt = Utils.get_rand_element(valid_items)
			else:
				if type == TierData.WEAPONS:
					# Fully exhausted all legal weapons, gracefully spawn an item instead!
					return _get_rand_item_for_wave(wave, player_index, TierData.ITEMS, args)
				else:
					elt = Utils.get_rand_element(_tiers_data[item_tier][type])
			# --- END MODIFIED FALLBACK LOGIC ---
	else:
		elt = Utils.get_rand_element(pool)
		if elt.my_id_hash == Keys.item_axolotl_hash and randf() < 0.5:
			elt = Utils.get_rand_element(pool)

	if DebugService.force_item_in_shop != "" and randf() < 0.5:
		elt = get_element(items, Keys.generate_hash(DebugService.force_item_in_shop))
		if elt == null:
			elt = get_element(weapons, Keys.generate_hash(DebugService.force_item_in_shop))

	if elt.my_id_hash == Keys.item_axolotl_hash and elt.effects.size() > 0 and Keys.stats_swapped_hash in elt.effects[0]:
		elt.effects[0][Keys.stats_swapped_hash] = []

	return apply_item_effect_modifications(elt, player_index)
