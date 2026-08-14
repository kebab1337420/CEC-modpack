if not Global.BigLobbyPersist then
	Global.BigLobbyPersist = {
		num_players = nil -- Set when joining lobbies, nil'd upon leaving
	}
end


if not _G.BigLobbyGlobals then
	_G.BigLobbyGlobals = {}

	-- Settings affected by BigLobby Mod Options
	BigLobbyGlobals.num_players_settings     	= nil
	BigLobbyGlobals.num_bots_settings        	= nil
	BigLobbyGlobals.allow_more_bots_settings 	= nil
	BigLobbyGlobals.auto_stop_all_bots_settings = nil

	-- Load custom lua files without specifying them in mod.txt --
	BigLobbyGlobals.ModPath = ModPath
	BigLobbyGlobals.SavePath = SavePath

	BigLobbyGlobals.ClassPath = "lua/_custom/"

	BigLobbyGlobals.Classes = {
		"menu.lua",
		"husl.lua"
	}

	for _, class in pairs(BigLobbyGlobals.Classes) do
		dofile(BigLobbyGlobals.ModPath .. BigLobbyGlobals.ClassPath .. class)
	end
	-- End custom lua load --


	-- Initializing menu will apply the default/saved settings
	BigLobbyGlobals.Menu = bkin_bl__menu:new()

	-- Set to the size of lobby you join, otherwise use your lobby size preferences for hosting
	BigLobbyGlobals.num_players = Global.BigLobbyPersist.num_players or BigLobbyGlobals.num_players_settings


	-- When joining, the host's size wins. When hosting, follow the Mod Options slider
	-- live: `num_players` is only resolved once at load, so reading it alone made every
	-- slider change a no-op until the next restart.
	function BigLobbyGlobals:num_player_slots()
		return Global.BigLobbyPersist.num_players or self.num_players_settings or self.num_players or 4
	end


	-- It's probably not going to cause any problems, but I'm capping the
	-- bot_slots to the lobby size just in case
	function BigLobbyGlobals:num_bot_slots()
		return math.min(self.num_bots_settings, self:num_player_slots())
	end


	-- Regular lobby / Seamless switching support
	function BigLobbyGlobals:is_small_lobby()
		--TODO: Changing lobby slot size without reloading mods such as in
		-- Crime.Net won't properly update filters. Don't enable until working better
		return false --self.num_players<=4
	end


	-- Semantic versioning
	-- Bumped for the Diesel 3.0 port: the value is part of the matchmaking search key,
	-- so Diesel 2 clients and Diesel 3 clients can never see each other's lobbies.
	function BigLobbyGlobals:version()
		return "3.28.0"
	end


	-- GameVersion for matchmaking, integer is expected
	function BigLobbyGlobals:gameversion()
		return 3280
	end


	-- Diesel 3.0 declares peer ids up to 15 in settings/network.network_settings, so the
	-- biglobby__* copies of every network message (and the XML tweak that injected them) are
	-- gone. The one thing they carried that the engine has no room for is the host's lobby
	-- size, which now travels over SuperBLT's hidden chat channel instead.
	BigLobbyGlobals.SIZE_MESSAGE = "biglobby_lobby_size"


	-- Host: tell a freshly joined peer how big this lobby is
	function BigLobbyGlobals:send_lobby_size(peer_id)
		if not LuaNetworking then
			return
		end

		LuaNetworking:SendToPeer(peer_id, self.SIZE_MESSAGE, tostring(self:num_player_slots()))
	end


	-- Client: adopt the host's size for as long as we stay in their lobby
	if LuaNetworking then
		LuaNetworking:AddReceiveHook(BigLobbyGlobals.SIZE_MESSAGE, "BigLobbyGlobals__lobby_size", function(data, sender)
			local size = tonumber(data)

			if not size or size < 4 then
				return
			end

			Global.BigLobbyPersist.num_players = size
			BigLobbyGlobals.num_players = size
		end)
	end


	-- Nothing calls this anymore for the time being.
	local log_data = true -- Can use to turn the logging on/off
	function BigLobbyGlobals:logger(content, use_chat)
		if log_data then
			if not content then return end

			if use_chat then
				managers.chat:_receive_message(ChatManager.GAME, "BigLobby", content, tweak_data.system_chat_color)
			end

			log(content)
		end
	end

end
