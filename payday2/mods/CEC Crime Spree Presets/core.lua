-- CEC Crime Spree Presets
--
-- Crime Spree asks you to pick a modifier every few levels, and by level 200
-- that is the same decision over and over. Everyone already knows which ones
-- they want first: pagers before civilians, medics before Bulldozers, and so on.
--
-- This mod keeps that decision in a file instead of in your head. A preset is
-- an ordered list of modifier ids; when the selection screen opens, the highest
-- ranked modifier still on offer is pre-highlighted. Confirming is still up to
-- the player, so nothing is ever picked behind your back and a preset that does
-- not match what the game offered simply changes nothing.
--
-- The preset file lives next to the save data so it survives a mod update:
--   PAYDAY 2/mods/saves/cec_crime_spree_presets.json

if CECSpreePresets then
	return
end

CECSpreePresets = {}

CECSpreePresets.path = (rawget(_G, "SavePath") or "") .. "cec_crime_spree_presets.json"

-- Shipped defaults. Ids come from tweak_data.crime_spree.modifiers: the loud
-- table (shield_reflect, medic_*, dozer_*, cloaker_*, heavies, assault_extender)
-- and the stealth table (pagers_1..4, civs_1..3, conceal_1..2).
--
-- Order is priority, best first. Anything absent from the list is only picked
-- when none of the listed modifiers are on offer.
CECSpreePresets.defaults = {
	active = "cheapest_first",
	presets = {
		-- Take the modifiers that cost the least in practice: extra pagers and
		-- concealment matter little on a stealth route, and reflective shields
		-- or angry Cloakers are easier to live with than more Bulldozers.
		cheapest_first = {
			"pagers_1",
			"pagers_2",
			"pagers_3",
			"pagers_4",
			"conceal_1",
			"conceal_2",
			"civs_1",
			"civs_2",
			"civs_3",
			"shield_reflect",
			"cloaker_smoke",
			"cloaker_tear_gas",
			"taser_overcharge",
			"medic_1",
			"medic_2",
			"heavies",
			"assault_extender"
		},
		-- Loud-only crews do not care about stealth modifiers at all, so grab
		-- them first and keep the enemy roster untouched for as long as
		-- possible.
		loud_only = {
			"pagers_1",
			"pagers_2",
			"pagers_3",
			"pagers_4",
			"conceal_1",
			"conceal_2",
			"civs_1",
			"civs_2",
			"civs_3",
			"shield_reflect",
			"heavy_sniper",
			"cloaker_smoke",
			"cloaker_tear_gas"
		},
		-- Keep the healers and the shield walls away as long as possible; a
		-- Bulldozer dies to enough bullets, a phalanx wastes the whole assault.
		anti_support = {
			"pagers_1",
			"pagers_2",
			"pagers_3",
			"pagers_4",
			"conceal_1",
			"conceal_2",
			"civs_1",
			"civs_2",
			"civs_3",
			"dozer_1",
			"dozer_2",
			"dozer_lmg",
			"dozer_minigun",
			"taser_overcharge",
			"cloaker_smoke"
		}
	}
}

function CECSpreePresets:_write_defaults()
	local ok = pcall(function()
		local file = io.open(self.path, "w")
		if not file then
			return
		end

		file:write(json.encode(self.defaults))
		file:close()
	end)

	if ok then
		log("[CEC Crime Spree Presets] preset file created at " .. tostring(self.path))
	end
end

function CECSpreePresets:_load()
	if self._config then
		return self._config
	end

	local config = nil

	pcall(function()
		local file = io.open(self.path, "r")
		if not file then
			return
		end

		local contents = file:read("*all")
		file:close()

		local decoded = json.decode(contents)
		if type(decoded) == "table" and type(decoded.presets) == "table" then
			config = decoded
		end
	end)

	-- No readable file, or one we cannot make sense of: fall back to the
	-- defaults and drop a copy on disk so the player has something to edit.
	if not config then
		self:_write_defaults()
		config = self.defaults
	end

	self._config = config

	return config
end

-- The ordered id list of the active preset, or nil when the preset named in the
-- file does not exist.
function CECSpreePresets:_priorities()
	local config = self:_load()
	local list = config.presets[config.active or ""]

	if type(list) ~= "table" then
		log("[CEC Crime Spree Presets] unknown preset '" .. tostring(config.active) .. "', nothing pre-selected")
		return nil
	end

	return list
end

-- Repeating modifiers get a numeric suffix appended to their base id
-- (damage_health_rpt_12 and so on), so a preset entry matches by prefix too.
function CECSpreePresets:_matches(entry, id)
	return entry == id or string.sub(id, 1, string.len(entry)) == entry
end

function CECSpreePresets:_rank(list, id)
	for i, entry in ipairs(list) do
		if self:_matches(entry, id) then
			return i
		end
	end
	return nil
end

-- Walks the modifier buttons of the selection screen and pre-highlights the
-- best ranked one. The finalize and back buttons share the same list but carry
-- no modifier data, hence the guards.
function CECSpreePresets:Apply(component)
	-- On a controller, selecting a modifier confirms it on the spot. Only the
	-- mouse and keyboard path has a separate confirm button, so that is the only
	-- place where pre-highlighting stays harmless.
	local pc = false
	pcall(function()
		pc = managers.menu:is_pc_controller() and true or false
	end)

	if not pc then
		return
	end

	local list = self:_priorities()
	if not list then
		return
	end

	pcall(function()
		local buttons = component._buttons
		if type(buttons) ~= "table" then
			return
		end

		local best, best_rank, best_id = nil, nil, nil

		for _, btn in ipairs(buttons) do
			if type(btn) == "table" and type(btn.data) == "function" then
				local data = btn:data()
				local id = type(data) == "table" and data.id or nil

				if id then
					local rank = self:_rank(list, id)
					if rank and (not best_rank or rank < best_rank) then
						best, best_rank, best_id = btn, rank, id
					end
				end
			end
		end

		if not best then
			return
		end

		component:_on_select_modifier(best)
		log("[CEC Crime Spree Presets] pre-selected " .. tostring(best_id))
	end)
end
