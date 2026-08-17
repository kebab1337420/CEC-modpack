-- CEC Auto Ready
--
-- Removes the two ways a lobby stalls:
--
--   * as a client, the READY tick box has to be clicked every single heist even
--     though the answer is always yes. It is ticked automatically a few seconds
--     after the briefing opens, once the local outfit has finished loading so
--     the host does not see a ready peer it cannot spawn.
--   * as a host, one player who alt-tabbed away holds the whole lobby. Peers
--     that never go ready are warned in chat and then kicked.
--
-- Ready state is used as the idle signal because it is the only per-peer
-- activity the host can observe from the lobby. Peers whose outfit is still
-- loading are left alone: they are busy, not away.
--
-- All timings in seconds. Set afk_kick to false to only auto-ready.

if CECAutoReady then
	return
end

CECAutoReady = {}

CECAutoReady.auto_ready = true
CECAutoReady.auto_ready_delay = 4
CECAutoReady.afk_kick = true
CECAutoReady.afk_warn_after = 90
CECAutoReady.afk_kick_after = 150

function CECAutoReady:_is_host()
	local ok, server = pcall(function()
		return Network:is_server()
	end)
	return ok and server or false
end

function CECAutoReady:_session()
	local ok, session = pcall(function()
		return managers.network:session()
	end)
	return ok and session or nil
end

function CECAutoReady:_chat(text)
	pcall(function()
		local session = self:_session()
		managers.chat:send_message(ChatManager.GAME, session:local_peer(), text)
	end)
end

-- Called from the briefing gui hook. Every lobby gets a fresh timer, otherwise
-- a peer that idled in the previous lobby would start the next one already on
-- the way out.
function CECAutoReady:Reset()
	self._elapsed = 0
	self._readied = false
	self._idle = {}
	self._warned = {}
end

function CECAutoReady:_tick_auto_ready(gui)
	if not self.auto_ready or self._readied or self:_is_host() then
		return
	end

	if self._elapsed < self.auto_ready_delay then
		return
	end

	local session = self:_session()
	if not session then
		return
	end

	local ok, loaded = pcall(function()
		return session:local_peer():is_outfit_loaded()
	end)
	if not ok or not loaded then
		return
	end

	-- gui._ready is the tick box state. Already ticked means the player did it
	-- by hand, and pressing again would untick it.
	if gui._ready then
		self._readied = true
		return
	end

	self._readied = true
	pcall(function()
		gui:on_ready_pressed(true)
	end)
	log("[CEC Auto Ready] readied up automatically")
end

function CECAutoReady:_kick(peer)
	local session = self:_session()
	if not session then
		return
	end

	pcall(function()
		-- Reason 0 is the plain "kicked by host" message on the peer's side.
		session:send_to_peers("kick_peer", peer:id(), 0)
		session:on_peer_kicked(peer, peer:id(), 0)
	end)
	log("[CEC Auto Ready] kicked idle peer " .. tostring(peer:id()))
end

function CECAutoReady:_tick_afk(dt)
	if not self.afk_kick or not self:_is_host() then
		return
	end

	local session = self:_session()
	if not session then
		return
	end

	local ok, peers = pcall(function()
		return session:peers()
	end)
	if not ok or type(peers) ~= "table" then
		return
	end

	for id, peer in pairs(peers) do
		local readable, ready, loaded, name = pcall(function()
			return peer:waiting_for_player_ready()
		end)
		ready = readable and ready
		loaded = readable and select(2, pcall(function()
			return peer:is_outfit_loaded()
		end))
		name = readable and select(2, pcall(function()
			return peer:name()
		end)) or tostring(id)

		if not readable then
			-- Peer vanished mid-iteration, nothing to time.
		elseif ready or not loaded then
			self._idle[id] = 0
			self._warned[id] = nil
		else
			local idle = (self._idle[id] or 0) + dt
			self._idle[id] = idle

			if idle >= self.afk_kick_after then
				self._idle[id] = 0
				self._warned[id] = nil
				self:_kick(peer)
			elseif idle >= self.afk_warn_after and not self._warned[id] then
				self._warned[id] = true
				self:_chat(string.format("%s: ready up within %d seconds or you will be kicked.",
					tostring(name), math.floor(self.afk_kick_after - idle)))
			end
		end
	end
end

function CECAutoReady:Update(gui, dt)
	if type(dt) ~= "number" or dt <= 0 then
		return
	end
	if not self._idle then
		self:Reset()
	end

	self._elapsed = (self._elapsed or 0) + dt

	self:_tick_auto_ready(gui)
	self:_tick_afk(dt)
end
