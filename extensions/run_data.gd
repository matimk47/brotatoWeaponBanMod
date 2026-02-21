extends "res://singletons/run_data.gd"

# Overriding this allows the "Banned Items" UI in the Pause menu to see your banned weapons
func get_player_banned_items(player_index: int) -> Array:
	if player_index == DUMMY_PLAYER_INDEX:
		return []

	var all_banned: Array = []
	var processed_weapon_ids: Array = [] # This stops the UI from showing 4 identical icons for 1 weapon
	
	for item_id in players_data[player_index].banned_items:
		var hash_to_check = item_id
		if item_id is String:
			hash_to_check = Keys.generate_hash(item_id)
			
		if ItemService.is_item_id(hash_to_check):
			all_banned.append(ItemService.get_item_from_id(hash_to_check))
		else:
			# It must be a weapon! We need to manually fetch it.
			for w in ItemService.weapons:
				if w.my_id_hash == hash_to_check:
					# We only append it if we haven't already appended another tier of this same weapon
					if not processed_weapon_ids.has(w.weapon_id_hash):
						all_banned.append(w)
						processed_weapon_ids.append(w.weapon_id_hash)
					break

	return all_banned
