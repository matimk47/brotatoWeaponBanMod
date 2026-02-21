extends "res://ui/menus/shop/shop_item.gd"

# 1. We override the button visibility to ALLOW weapons
func manage_ban_button_visibility() -> void :
	# We removed the 'or item_data is WeaponData' that was in the base game!
	if not ChallengeService.is_challenge_completed(ChallengeService.chal_banned_items_hash) or not RunData.is_ban_active_in_current_run():
		_ban_button.disable()
		_ban_button.hide()
		return

	if item_data.my_id_hash == Keys.item_bait_hash:
		if RunData.players_data[player_index].current_character.my_id_hash == Keys.character_fisherman_hash:
			_ban_button.disable()
			_ban_button.hide()
			return

	var remaining_ban_token = RunData.players_data[player_index].remaining_ban_token
	_ban_button.text = Text.text("BAN_SHOP", [str(remaining_ban_token)])
	if remaining_ban_token > 0:
		if not RunData.is_coop_run:
			_ban_button.show()
		_ban_button.activate()
	else:
		_ban_button.disable()
		_ban_button.hide()

# 2. We override the ban logic so it bans ALL tiers of the weapon
func ban_item() -> void :
	var player_run_data = RunData.players_data[player_index]
	
	if item_data is WeaponData:
		# If it's a weapon, we loop through every weapon in the game.
		# If it shares the same base ID (weapon_id_hash) as the one we clicked, we ban it.
		for w in ItemService.weapons:
			if w.weapon_id_hash == item_data.weapon_id_hash:
				if not player_run_data.banned_items.has(w.my_id_hash):
					player_run_data.banned_items.push_back(w.my_id_hash)
	else:
		# Normal item behavior
		if not player_run_data.banned_items.has(item_data.my_id_hash):
			player_run_data.banned_items.push_back(item_data.my_id_hash)
			
	player_run_data.remaining_ban_token -= 1
	deactivate()
	emit_signal("ban_update_remaining_token")
