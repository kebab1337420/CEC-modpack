-- Modified hardcoded value to allow returning available peer id up to the actual limit.
-- Assigns a free Peer ID to new joining peer
function HostNetworkSession:_get_free_client_id()
	-- The below loop stops when index(i) reaches this value
	local num_player_slots = (BigLobbyGlobals:num_player_slots() + 1)

	-- The player slot to start from(Host is 1 so defaults to 2)
	local i = 2
	repeat
		if not self._peers[i] then
			local is_dirty = false
			for peer_id, peer in pairs(self._peers) do
				if peer:handshakes()[i] then
					is_dirty = true
				end
			end
			if not is_dirty then
				return i
			end
		end
		i = i + 1
	until i == num_player_slots
end


-- Modified hardcoded value to prevent disabling the ability to join the server until actual limit is reached.
function HostNetworkSession:chk_server_joinable_state()
	local num_player_slots = (BigLobbyGlobals:num_player_slots() - 1)




	-- Original Code --
	for peer_id, peer in pairs(self._peers) do
		if peer:force_open_lobby_state() then
			print("force-opening lobby for peer", peer_id)
			managers.network.matchmake:set_server_joinable(true)
			return
		end
	end
	-- End Original Code --




	-- num_player_slots variable instead of hardcoded 3, prevent disabling join early.
	if table.size(self._peers) >= num_player_slots then
		managers.network.matchmake:set_server_joinable(false)
		return
	end




	-- Original Code --
	local game_state_name = game_state_machine:last_queued_state_name()
	if BaseNetworkHandler._gamestate_filter.any_end_game[game_state_name] then
		managers.network.matchmake:set_server_joinable(false)
		return
	end
	if not self:_get_free_client_id() then
		managers.network.matchmake:set_server_joinable(false)
		return
	end
	if not self._state:is_joinable(self._state_data) then
		managers.network.matchmake:set_server_joinable(false)
		return
	end
	if NetworkManager.DROPIN_ENABLED then
		if BaseNetworkHandler._gamestate_filter.lobby[game_state_name] then
			managers.network.matchmake:set_server_joinable(true)
			return
		elseif managers.groupai and not managers.groupai:state():chk_allow_drop_in() or not Global.game_settings.drop_in_allowed then
			managers.network.matchmake:set_server_joinable(false)
			return
		end
	elseif not BaseNetworkHandler._gamestate_filter.lobby[game_state_name] then
		managers.network.matchmake:set_server_joinable(false)
		return
	end
	managers.network.matchmake:set_server_joinable(true)
	-- End Original Code --
end

-- TEMP DIAGNOSTIC PROBE: trace peer id allocation and removal
local probe__get_free_client_id = HostNetworkSession._get_free_client_id

function HostNetworkSession:_get_free_client_id(...)
	local id = probe__get_free_client_id(self, ...)

	if BigLobbyGlobals.join_log then
		local taken = {}
		for pid in pairs(self._peers) do
			table.insert(taken, tostring(pid))
		end

		BigLobbyGlobals:join_log(("FREE ID -> %s (taken=%s)"):format(tostring(id), table.concat(taken, ",")))
	end

	return id
end

local probe__remove_peer = HostNetworkSession.remove_peer

function HostNetworkSession:remove_peer(peer, peer_id, reason, ...)
	if BigLobbyGlobals.join_log then
		BigLobbyGlobals:join_log(("REMOVE PEER id=%s reason=%s"):format(tostring(peer_id), tostring(reason)))
	end

	return probe__remove_peer(self, peer, peer_id, reason, ...)
end
