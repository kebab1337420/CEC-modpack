Hooks:Add('LocalizationManagerPostInit', 'AdvMov_wordswordswords', function(loc)
	AdvMov:Load()
	loc:load_localization_file(AdvMov._path .. 'menu/AdvMov_en.txt', false)
end)

Hooks:Add('MenuManagerInitialize', 'AdvMov_init', function(menu_manager)

	MenuCallbackHandler.advmovsave = function(this, item)
		AdvMov:Save()
	end

	MenuCallbackHandler.advmovcb_donothing = function(this, item)
		-- do nothing
	end

	MenuCallbackHandler.advmovcb_runkick = function(this, item)
		AdvMov.settings[item:name()] = item:value() == 'on'
		AdvMov:Save()
	end
	MenuCallbackHandler.advmovcb_kickyeet = function(this, item)
		AdvMov.settings.kickyeet = tonumber(item:value())
		AdvMov:Save()
	end
	MenuCallbackHandler.advmovcb_dashcontrols = function(this, item)
		AdvMov.settings.dashcontrols = tonumber(item:value())
		AdvMov:Save()
	end
	MenuCallbackHandler.advmovcb_ene_slidestealth = function(this, item)
		AdvMov.settings.slidestealth = tonumber(item:value())
		AdvMov:Save()
	end
	MenuCallbackHandler.advmovcb_ene_slideloud = function(this, item)
		AdvMov.settings.slideloud = tonumber(item:value())
		AdvMov:Save()
	end
	MenuCallbackHandler.advmovcb_slidewpnangle = function(this, item)
		AdvMov.settings.slidewpnangle = tonumber(item:value())
		AdvMov:Save()
	end
	MenuCallbackHandler.advmovcb_wallrunwpnangle = function(this, item)
		AdvMov.settings.wallrunwpnangle = tonumber(item:value())
		AdvMov:Save()
	end

	AdvMov:Load()
	MenuHelper:LoadFromJsonFile(AdvMov._path .. 'menu/AdvMov.txt', AdvMov, AdvMov.settings)
end)