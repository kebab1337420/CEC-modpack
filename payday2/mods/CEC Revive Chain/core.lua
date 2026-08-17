-- CEC Revive Chain
--
-- Picking teammates up is the least rewarded thing a player can do in a heist:
-- it costs time, it costs position, and the only payoff is that the crew keeps
-- moving. Going down yourself, meanwhile, costs almost nothing beyond the down
-- counter.
--
-- This mod puts a value on both. Every teammate you pick up without going down
-- yourself builds a chain, and each link heals you a little more; a full chain
-- also puts your armour back. Going down breaks the chain and, from the second
-- down onwards, cuts the health you get back when someone picks you up.
--
-- Everything is local: the chain only tracks what this player does, the health
-- and armour changes go through the vanilla setters that already sync, and the
-- revive penalty rides on the same _revive_health_multiplier the game uses for
-- its own effects. Nothing is sent to other peers.

if CECReviveChain then
	return
end

CECReviveChain = {}

-- Health given back per link, as a share of maximum health, and the number of
-- links that still count. Three teammates in a row is already a good streak.
CECReviveChain.heal_per_link = 0.1
CECReviveChain.max_links = 3

-- Health lost on the revive that follows each down after the first, and the
-- floor the penalty cannot go under: a bad run must stay playable.
CECReviveChain.penalty_per_down = 0.15
CECReviveChain.min_revive_multiplier = 0.4

CECReviveChain.links = 0
CECReviveChain.downs = 0

function CECReviveChain:Reset()
	self.links = 0
	self.downs = 0
end

function CECReviveChain:_hint(text)
	pcall(function()
		managers.hud:show_hint({
			text = text,
			time = 3
		})
	end)
end

function CECReviveChain:_local_damage()
	local unit = nil

	pcall(function()
		unit = managers.player:player_unit()
	end)

	if not unit or not alive(unit) then
		return nil
	end

	local damage = nil

	pcall(function()
		damage = unit:character_damage()
	end)

	return damage
end

-- Called once per teammate actually picked up by this player.
function CECReviveChain:OnRevivedTeammate()
	self.links = self.links + 1

	local links = math.min(self.links, self.max_links)
	local damage = self:_local_damage()

	if not damage then
		return
	end

	pcall(function()
		damage:change_health(damage:_max_health() * self.heal_per_link * links)

		-- The reward for holding a full chain is the part that actually keeps a
		-- medic alive, so it only lands once the chain is complete.
		if links >= self.max_links then
			damage:set_armor(damage:_max_armor())
		end
	end)

	if links >= self.max_links then
		self:_hint("Revive chain " .. tostring(self.links) .. " : sante et gilet restaures")
	else
		self:_hint("Revive chain " .. tostring(self.links) .. " : sante restauree")
	end

	log("[CEC Revive Chain] chain at " .. tostring(self.links))
end

function CECReviveChain:OnDowned()
	local had_chain = self.links > 0

	self.links = 0
	self.downs = self.downs + 1

	if self.downs > 1 then
		self:_hint("Chaine brisee : relevage affaibli (chute " .. tostring(self.downs) .. ")")
	elseif had_chain then
		self:_hint("Chaine brisee")
	end

	log("[CEC Revive Chain] down " .. tostring(self.downs) .. ", chain reset")
end

-- Multiplier handed to PlayerDamage:revive. The first down of a heist is free;
-- every one after that bites, down to the floor.
function CECReviveChain:ReviveMultiplier()
	if self.downs <= 1 then
		return 1
	end

	local mul = 1 - self.penalty_per_down * (self.downs - 1)

	return math.max(mul, self.min_revive_multiplier)
end
