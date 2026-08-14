local original = CrimenetSearchLobbyCodeGui.searchbox_disconnect_callback
function CrimenetSearchLobbyCodeGui:searchbox_disconnect_callback(...)
    if not EpicSocialHub then
        return
    end
    original(self, ...)
end