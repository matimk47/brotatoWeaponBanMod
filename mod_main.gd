extends Node

const MOD_DIR = "Matimk-WeaponBans/" # MUST exactly match your folder name
const LOG_NAME = "Matimk-WeaponBans"

var dir = ""

func _init():
	ModLoaderLog.info("Initializing Mod", LOG_NAME)
	dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR
	
	# This tells the ModLoader to overwrite the base game scripts with our custom ones!
	ModLoaderMod.install_script_extension(dir + "extensions/shop_item.gd")
	ModLoaderMod.install_script_extension(dir + "extensions/run_data.gd")

func _ready():
	ModLoaderLog.info("Mod Ready!", LOG_NAME)
