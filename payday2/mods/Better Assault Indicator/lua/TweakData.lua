if BAI:CheckHook("tweak_data") then
    return
end

tweak_data.bai =
{
    time_left =
    {
        texture = "guis/dlcs/opera/textures/pd2/specialization/icons_atlas",
        texture_rect = { 0, 0, 64, 64 }
    },
    spawns_left =
    {
        texture = "guis/textures/pd2_mod_bai/spawns_left"
    },
    captain =
    {
        texture = "guis/textures/pd2/hud_buff_shield"
    },
    break_time_left =
    {
        texture = "guis/textures/pd2_mod_bai/spawns_left"
    }
}