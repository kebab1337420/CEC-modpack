-- CEC Keep Your Mask On
--
-- Masking up is a hold: the game starts a timer when the equipment button goes
-- down and throws it away the moment the button comes back up. On a heist that
-- starts in casing mode this is the single most common misclick in the game,
-- because the same button is used for deployables the rest of the time, and a
-- half-second slip resets the whole gesture with no feedback beyond the bar
-- disappearing.
--
-- Once the gesture has started here, it finishes on its own. The vanilla timer,
-- the progress bar and the teammate progress sync are all left alone, so other
-- peers still see exactly what they saw before; only the cancel-on-release path
-- is suppressed.
--
-- The state also reminds the player, on entering casing mode, which button puts
-- the mask on, because nothing in vanilla says so once the tutorial is off.

if CECMaskOn then
	return
end

CECMaskOn = {}

CECMaskOn.hint_time = 4

function CECMaskOn:Hint()
	pcall(function()
		managers.hud:show_hint({
			text = "Reperage : maintiens la touche d'equipement pour mettre le masque",
			time = self.hint_time
		})
	end)
end
