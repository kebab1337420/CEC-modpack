local menu_music_broken =
{
    pb_do_you_wanna = true,
    pb_i_need_your_love = true,
    pb_still_breathing = true,
    pb_take_me_down = true,
    biting_elbows_bad_motherfucker = true,
    biting_elbows_for_the_kill = true
}
for _, entry in ipairs(tweak_data.music.track_menu_list) do
    if menu_music_broken[entry.track] then
        entry.hide_unavailable = nil
        entry.lock = "mad"
    end
end