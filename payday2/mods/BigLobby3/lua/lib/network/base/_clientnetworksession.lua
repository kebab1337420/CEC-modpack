local orig__ClientNetworkSession = {
	on_join_request_reply = ClientNetworkSession.on_join_request_reply
}


-- The host's lobby size used to ride along as a 16th parameter of `join_request_reply`,
-- which required injecting a modified copy of that message. Diesel 3.0 keeps the vanilla
-- parameter list, so the size now arrives over SuperBLT's hidden channel (see
-- BigLobbyGlobals.SIZE_MESSAGE). Until it does, fall back to the vanilla lobby size so a
-- BigLobby client joining a plain host does not size itself for more peers than exist.
function ClientNetworkSession:on_join_request_reply(reply, ...)
	if reply == HostNetworkSession.JOIN_REPLY.OK and not Global.BigLobbyPersist.num_players then
		Global.BigLobbyPersist.num_players = tweak_data.max_players or 4
		BigLobbyGlobals.num_players = Global.BigLobbyPersist.num_players
	end

	orig__ClientNetworkSession.on_join_request_reply(self, reply, ...)
end
