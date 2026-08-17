local ThisModPath = ModPath

--[[File Path]]
local ThisOGG = ThisModPath.."sounds/earrapelobstermeme.ogg"
local ThisTexture = "flashbmemes_custom"

if blt.xaudio then
	blt.xaudio.setup()
else
	return
end

if not io.file_is_readable(ThisOGG) then
	return
end

pcall(function()
	DB:create_entry( 
		Idstring("texture"), 
		Idstring(ThisTexture), 
		ThisModPath.."/Assets/"..ThisTexture..".texture", 
		nil 
	)
end)

local ThisModIds = Idstring(ThisModPath):key()
local __Name = function(__id)
	return "BADMEMES_"..Idstring(tostring(__id).."::"..ThisModIds):key()
end

local XAudioBuffer = __Name("XAudioBuffer")
local XAudioSource = __Name("XAudioSource")
local _GName = __Name("_G")
_G[_GName] = _G[_GName] or {}
local ThisBitmap = __Name("ThisBitmap")
_G[ThisBitmap] = _G[ThisBitmap] or nil

local function is_FlashBMemes()
	return type(FlashBMemes) == "table" and type(FlashBMemes.Options) == "table" and type(FlashBMemes.Options.GetValue) == "function"
end

local function __ply_ogg()
	if io.file_is_readable(ThisOGG) then
		local __is_FlashBMemes = is_FlashBMemes()
		local __volume_start = __is_FlashBMemes and FlashBMemes.Options:GetValue("__volume_start") or 1
		local this_buffer = XAudio.Buffer:new(ThisOGG)
		local this_source = XAudio.UnitSource:new(XAudio.PLAYER)
		this_source:set_buffer(this_buffer)
		this_source:play()
		this_source:set_volume(__volume_start)
		_G[_GName][XAudioBuffer] = this_buffer
		_G[_GName][XAudioSource] = this_source
	end
	return
end

local function __end_ogg()
	if _G[_GName][XAudioSource] then
		_G[_GName][XAudioSource]:close(true)
		_G[_GName][XAudioSource] = nil
	end
	if _G[_GName][XAudioBuffer] then
		_G[_GName][XAudioBuffer]:close(true)
		_G[_GName][XAudioBuffer] = nil
	end
	return
end

local function __set_ogg_volume(__volume)
	if _G[_GName][XAudioSource] then
		_G[_GName][XAudioSource]:set_volume(__volume)
	end
	return
end

-- The HUD is torn down and rebuilt on every state change, which destroys the
-- panel and the bitmap. The Lua reference stays behind and points at freed
-- memory, so every use has to be guarded with alive().
local function __get_pic()
	local bitmap = _G[ThisBitmap]
	if bitmap and alive(bitmap) then
		return bitmap
	end
	_G[ThisBitmap] = nil
	return nil
end

local function __ply_pic()
	local bitmap = __get_pic()
	if bitmap then
		bitmap:set_visible(true)
	end
	return
end

local function __end_pic()
	local bitmap = __get_pic()
	if bitmap then
		bitmap:set_visible(false)
	end
	return
end

local function __set_pic_alpha(__alpha)
	local bitmap = __get_pic()
	if bitmap then
		bitmap:set_alpha(math.max(__alpha, 0))
	end
	return
end

if CoreEnvironmentControllerManager then
	Hooks:PostHook(CoreEnvironmentControllerManager, "set_flashbang", __Name("set_flashbang"), function(self)
		__end_ogg()
		__ply_ogg()
		__ply_pic()
	end)
end

if PlayerDamage then
	Hooks:PostHook(PlayerDamage, "update", __Name("update"), function(self)
		if _G[_GName][XAudioSource] then
			if not _G[_GName][XAudioSource]:is_active() then
				__end_ogg()
				__end_pic()
			else
				if managers.environment_controller then
					local _current_flashbang = managers.environment_controller._current_flashbang				
					_current_flashbang = math.clamp(tonumber(tostring(_current_flashbang)), 0, 1)
					local __is_FlashBMemes = is_FlashBMemes()
					if __is_FlashBMemes then
						local __picture_fadeout = FlashBMemes.Options:GetValue("__picture_fadeout")
						local __volume_fadeout = FlashBMemes.Options:GetValue("__volume_fadeout")
						if __picture_fadeout then
							__set_pic_alpha(_current_flashbang)
						end
						if __volume_fadeout then
							local __volume_start = FlashBMemes.Options:GetValue("__volume_start")
							__set_ogg_volume(_current_flashbang * __volume_start)
						end
					end
				end
			end
		end
	end)
	Hooks:PostHook(PlayerDamage, "_stop_tinnitus", __Name("_stop_tinnitus"), function(self)
		__end_ogg()
		__end_pic()
	end)
	Hooks:PreHook(PlayerDamage, "pre_destroy", __Name("pre_destroy"), function(self)
		__end_ogg()
		__end_pic()
	end)
end

if HUDManager then
	-- HUDManager is a singleton that survives every state change, so nothing
	-- here may be cached on it: the original version kept the fullscreen panel
	-- in self[panel1] and reused it on the next layout, by which time the
	-- engine had already destroyed it. Calling :bitmap() on that freed panel is
	-- an access violation, one per heist entry.
	local bitmap_name = __Name("bitmap1")

	Hooks:PostHook(HUDManager, "_player_hud_layout", __Name("_player_hud_layout"), function(self)
		_G[ThisBitmap] = nil

		local hud = managers.hud and managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
		local panel = hud and hud.panel
		if not panel or not alive(panel) then
			return
		end

		-- A layout can run several times on the same panel; drop the previous
		-- bitmap instead of stacking a new one on top of it every time.
		local previous = panel:child(bitmap_name)
		if previous then
			panel:remove(previous)
		end

		local ok, bitmap = pcall(panel.bitmap, panel, {
			name = bitmap_name,
			texture = ThisTexture,
			color = Color.white:with_alpha(1),
			alpha = 1,
			layer = 1
		})
		if not ok or not bitmap then
			return
		end

		bitmap:set_size(panel:w(), panel:h())
		bitmap:set_visible(false)
		_G[ThisBitmap] = bitmap
	end)
end