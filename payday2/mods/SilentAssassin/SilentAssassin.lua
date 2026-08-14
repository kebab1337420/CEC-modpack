-------------------------------------------------
--  Menu Logic
-------------------------------------------------
_G.SilentAssassin = _G.SilentAssassin or {}
SilentAssassin._path = ModPath
SilentAssassin._loc_path = ModPath .. "loc/"
SilentAssassin._data_path = SavePath .. "silentassassin.txt"
-- num_pagers -> number of pagers allowed.
-- num_pagers_per_player -> maximum number of pagers a single
--  player may use
SilentAssassin.settings = {}
-- I can't get at the player unit at the end game screen. (or at least I don't
-- know how)  So store the local pagers used here.  It'll be easier if I end
-- up having to sync the pagers used to the clients anyway.
SilentAssassin.localPagersUsed = 0

--Loads the options from blt
function SilentAssassin:Load()
    --log(debug.traceback())
    self.settings["num_pagers"] = 2
    self.settings["num_pagers_per_player"] = 2
    self.settings["enabled"] = true
    self.settings["stealth_kill_enabled"] = true
    self.settings["pager_bonus_enabled"] = false
    self.settings["matchmaking_filter"] = 1
    self.settings["pager_detection_threshold"] = 1

    local file = io.open(self._data_path, "r")
    if (file) then
        for k, v in pairs(json.decode(file:read("*all"))) do
            self.settings[k] = v
        end
    end
    --log("In Load " .. json.encode(self.settings))
end

--Saves the options
function SilentAssassin:Save()
    --log("In save " .. json.encode(self.settings))
    local file = io.open(self._data_path, "w+")
    if file then
        file:write(json.encode(self.settings))
        file:close()
    end
end

--Loads the data table for the menuing system.  Menus are
--ones based
function SilentAssassin:getCompleteTable()
    local tbl = {}
    for i, v in pairs(SilentAssassin.settings) do
        if i == "num_pagers" then
            tbl[i] = v + 1
        elseif  i == "num_pagers_per_player" then
            tbl[i] = v + 1
        elseif i == "pager_detection_threshold" then
            tbl[i] = v * 100
        else
            tbl[i] = v
        end
    end

    return tbl
end

--Sets number of pagers.  Called from the menu system.  Menus are all ones
--based
function setNumPagers(this, item)
    SilentAssassin.settings["num_pagers"] = item:value() - 1
end

function setNumPagersPerPlayer(this, item)
    SilentAssassin.settings["num_pagers_per_player"] = item:value() - 1
end

function setEnabled(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["enabled"] = value
end

function setStealthKillEnabled(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["stealth_kill_enabled"] = value
end

function setMatchmakingFilter(this, item)
    --log ("setMatchmakingFilter" .. tostring(item:value()))
    SilentAssassin.settings["matchmaking_filter"] = item:value()
end

function setEnablePagerBonusToggle(this, item)
    local value = item:value() == "on" and true or false
    SilentAssassin.settings["pager_bonus_enabled"] = value
end

function setPagerDetectionThreshold(this, item)
    local value = item:value() / 100
    SilentAssassin.settings["pager_detection_threshold"] = value
end
--this only gives you the bonus for not using your pager
function calculateStageStealthBonus()
    --and if you personally didn't use a pager at all, you get a 2% bonus
    local playerBonus
    if getLocalPagersAnswered() == 0 then
        playerBonus = .02
    else
        playerBonus = 0
    end

    return playerBonus
end

--bonus for difficulty too
function calculateLevelStealthBonus()
    --calculate an adjusted stealth bonus for the level/stage
    -- adding or removing pagers (from the default of 2) changes the bonus
    -- each pager used by the party decreases the bonus
    -- reducing pagers per player increases the bonus
    -- not using your pager increases it
    local numPagers = getNumPagers()
    --don't penalize the player for having 2 total pagers but 4 per player
    local numPagersPerPlayer = math.min(numPagers, getNumPagersPerPlayer())
    local difficultyBonus = 0;
    local parPagers

    --par for pagers is 2 when stealth kills are enabled, otherwise 
    --it is the default of 4.
    if isStealthKillEnabled() then
        parPagers = 2
    else
        parPagers = 4
    end
    -- 2% bonus for each pager below 2
    difficultyBonus = difficultyBonus + ((parPagers - numPagers) * .02)
    -- 1% bonus for each pager per player below the number of total pagers
    difficultyBonus = difficultyBonus + ((numPagers - numPagersPerPlayer) * .01)
    --log ("difficulty bonus is " .. tostring(difficultyBonus))

    --you also get a 1% bonus for each pager you had but didn't use
    local missionBonus
    --it seems like this gets called when someone joins a stealth lobby  In
    --that case groupai is undefined.  So try this hack.
    if managers.groupai and managers.groupai:state() then
        missionBonus = (numPagers - managers.groupai:state():get_nr_successful_alarm_pager_bluffs()) * .01
    else
        missionBonus = numPagers
    end
    --log ("mission bonus is " .. tostring(missionBonus))

    --and if you personally didn't use a pager at all, you get a 2% bonus
    local playerBonus
    if getLocalPagersAnswered() == 0 then
        playerBonus = .02
    else
        playerBonus = 0
    end

    --log("Player bonus is " .. tostring(playerBonus))

    local bonus = difficultyBonus + missionBonus + playerBonus
    --log("Level bonus is " .. tostring(bonus))
    return bonus
end

--Load locatization strings
Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_SilentAssassin", function(loc)
    --More or less cribbed from WolfHUD
    --Detect ChnMod to select chinese (simplified) locale
    local lang
    for _, mod in pairs(BLT and BLT.Mods:Mods() or {}) do
        if mod:GetName() == "ChnMod" and mod:IsEnabled() then
            lang = "zh-cn"
        end
    end

    if not lang then
        for _, filename in pairs(file.GetFiles(SilentAssassin._loc_path )) do
            local str = filename:match('^(.*).json$')
            if str and Idstring(str) and Idstring(str):key() == SystemInfo:language():key() then
                lang = str
                break
            end
        end
    end

    if not lang then
        lang = "english"
    end

    --check to see if the locale file for the language exists.  If so, use it.
    --otherwise, default to English
    local path = SilentAssassin._loc_path .. lang .. ".json"
    --log("checking " .. path)
    if io.file_is_readable(path) then
        --log("loading " .. path)
        loc:load_localization_file(path)
    else
        --log("defaulting to english")
        loc:load_localization_file(SilentAssassin._loc_path.."english.json")
    end
end)

--Set up the menu
Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_SilentAssassin", function(menu_manager)
    MenuCallbackHandler.SilentAssassin_setNumPagers = setNumPagers
    MenuCallbackHandler.SilentAssassin_setNumPagersPerPlayer = setNumPagersPerPlayer
    MenuCallbackHandler.SilentAssassin_enabledToggle = setEnabled
    MenuCallbackHandler.SilentAssassin_killPagerEnabledToggle = setStealthKillEnabled
    MenuCallbackHandler.SilentAssassin_enablePagerBonusToggle = setEnablePagerBonusToggle
    MenuCallbackHandler.SilentAssassin_setMatchmakingFilter = setMatchmakingFilter
    MenuCallbackHandler.SilentAssassin_setPagerDetectionThreshold = setPagerDetectionThreshold

    MenuCallbackHandler.SilentAssassin_Close = function(this)
        SilentAssassin:Save()
    end

    SilentAssassin:Load()
    MenuHelper:LoadFromJsonFile(SilentAssassin._path.."options.txt", SilentAssassin, SilentAssassin:getCompleteTable())
end)

-- gets the number of pagers, triggering a load if necessary.  Called
-- by clients
function getNumPagers()
    if not SilentAssassin.settings["num_pagers"] then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["num_pagers"]
end

function getNumPagersPerPlayer()
    if not SilentAssassin.settings["num_pagers_per_player"] then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["num_pagers_per_player"]
end

function getEffectiveNumPagersPerPlayer()
    local numPerPlayer = getNumPagersPerPlayer()
    local numPagers = getNumPagers()
    local numPlayers = managers.network:session():amount_of_players()

    --If we're set to 2 pagers total, 1 per player, but there is only one
    --player, then effectively we're set to 1 pager.  But it's a pain to
    --keep changing settings based on number of players.  So set this to be
    --the larger of
    --
    --  The number of pagers per player
    --  the number of pagers total / number of players, rounded up
    --
    --log("numPerPlayer " .. tostring(numPerPlayer))
    --log("numPagers " .. tostring(numPagers))
    --log("numPlayers " .. tostring(numPlayers))
    local effectivePerPlayer = math.max(numPerPlayer, math.ceil(numPagers / numPlayers))
    --log("Effective number per player is " .. tostring(effectivePerPlayer))
    return effectivePerPlayer
end

function isSAEnabled()
    if SilentAssassin.settings["enabled"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["enabled"]
end

function isStealthKillEnabled()
    if not SilentAssassin.settings["stealth_kill_enabled"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["stealth_kill_enabled"]
end

function getPagerDetectionThreshold()
    if not SilentAssassin.settings["pager_detection_threshold"] == nil then
        SilentAssassin:Load()
    end
    return SilentAssassin.settings["pager_detection_threshold"]
end

function isPagerBonusEnabled()
    return false
    --local Net = _G.LuaNetworking
    --if Net:IsClient() then
        --return false
    --end
    --if not SilentAssassin.settings["pager_bonus_enabled"] then
        --SilentAssassin:Load()
    --end
    --return SilentAssassin.settings["pager_bonus_enabled"]

end

function getMatchmakingFilter()
    if not SilentAssassin.settings["matchmaking_filter"] then
        SilentAssassin:Load()
    end
    --log ("getMatchmakingFilter " .. tostring(SilentAssassin.settings["matchmaking_filter"]))
    return SilentAssassin.settings["matchmaking_filter"]
end


function addLocalPagerAnswered()
    --log("Answered pager locally")
    SilentAssassin.localPagersUsed = SilentAssassin.localPagersUsed + 1
end

function getLocalPagersAnswered()
    return SilentAssassin.localPagersUsed
end

-------------------------------------------------
--  Handler for damaged received
-------------------------------------------------

if RequiredScript == "lib/units/enemies/cop/copbrain" then
    if not _CopBrain_clbk_damage then
        _CopBrain_clbk_damage = CopBrain._clbk_damage
    end

    function CopBrain:clbk_damage(my_unit, damage_info)
        --log ("CopBrain:clbk_damage")
        if _CopBrain_clbk_damage then 
            --this seems to get called on damage but not on death
            --So if we take any non-fatal damage, the pager will go off
            --log ("non-fatal damage")
            self._cop_pager_ready = true
            _CopBrain_clbk_damage(self, my_unit, damage_info)
            --log ("made parent callback")
        end
    end

    if not _CopBrain_clbk_death then
        _CopBrain_clbk_death = CopBrain.clbk_death
    end
    function CopBrain:clbk_death(my_unit, damage_info)
        -- COMPAT DIESEL 3.0 : toute cette logique lit des champs internes
        -- du jeu (_logic_data, unit_data, movement()...) qui peuvent être
        -- renommés/déplacés par une mise à jour du moteur. On l'exécute
        -- dans un pcall : si un champ a changé, le mod le note dans le
        -- log au lieu de faire planter la mort du garde (ce qui pourrait
        -- bloquer l'IA/le heist). Le comportement normal du jeu est
        -- toujours garanti par l'appel à la fonction d'origine plus bas.
        local ok, err = pcall(function()
            if managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode() then
                if isSAEnabled() and isStealthKillEnabled() then

                    local head
                    if damage_info and damage_info.col_ray then
                        --the idea was to require a headshot.  It turns out that col_ray is not
                        --set when the client takes the shot so I can only do OHKs on clients.
                        --I figure to make things fair it should be OHKs for everyone
                        head = true
                    else
                        --OHK keeps the pager from going off
                        head = true
                    end
                    if not head then
                        --not headshots will cause the pager to go off
                        self._cop_pager_ready = true
                    end

                    local notice_progress = 0
                    if self._logic_data and self._logic_data.detected_attention_objects then
                        for key, obj in pairs(self._logic_data.detected_attention_objects) do
                            if obj.notice_progress then
                                notice_progress = math.max(notice_progress, obj.notice_progress)
                            end
                        end
                    end
                    if notice_progress > getPagerDetectionThreshold() then
                        self._cop_pager_ready = true
                    end

                    --cool() doesn't work for the camera operator on First World Bank.  For
                    --some reason he's in stance "cbt" (and therefore uncool) even if he's not
                    --alerted.  I figure this is a bug in the map.
                    --ignore the above comment.  They fixed that bug.  Hopefully it stays that way.
                    if not self._cop_pager_ready and self._unit and self._unit:movement() and self._unit:movement():cool() then
                        --we're dead and the pager is not ready, so delete it
                        if self._unit:unit_data() then
                            self._unit:unit_data().has_alarm_pager = false
                        end
                    end
                end
            end
        end)
        if not ok then
            log("[Silent Assassin] clbk_death : erreur de compatibilité (le pager de ce garde se comportera normalement) : " .. tostring(err))
        end
        --log("clbk_death parent")
        _CopBrain_clbk_death(self, my_unit, damage_info)
    end

-------------------------------------------------
--  Setting number of pagers
-------------------------------------------------

    --This is called when a player interacts with a pager.  Swap in the
    --correct table before actually running the pager interaction
elseif RequiredScript == "lib/units/interactions/interactionext" then
    if not _IntimitateInteractionExt_at_interact_start then
        _IntimitateInteractionExt_at_interact_start = IntimitateInteractionExt._at_interact_start
    end
    function IntimitateInteractionExt:_at_interact_start(player, timer)
        -- COMPAT DIESEL 3.0 : cette logique touche à des structures internes
        -- (player:base(), tweak_data.player.alarm_pager...) qui peuvent
        -- changer avec une mise à jour du moteur. On l'isole dans un pcall
        -- pour ne jamais bloquer l'interaction avec le pager en jeu : en
        -- cas d'erreur, le pager se comportera simplement normalement
        -- (comme sans le mod) au lieu de figer l'interaction.
        local ok, err = pcall(function()
            if managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode() then
                --This is eventually going to call CopBrain.on_alarm_pager_interaction.
                --However, it doesn't pass in the player.  So, if we are going to do
                --that, set up the alarm_pager tables here
                if self.tweak_data == "corpse_alarm_pager" then
                    if Network:is_server() then
                        if not self._in_progress then
                            --This is where the pager really runs
                            local bluffChance = {}
                            local numPagers = getNumPagers()

                            --Track the number of pagers a player has answered in the
                            --player object
                            if not player:base().num_answered then
                                player:base().num_answered = 0
                            end

                            --If this player can answer a pager, write up to
                            --getEffectiveNumPagersPerPlayer() 1's into the table,
                            --otherwise write all 0's.  This way the real
                            --on_alarm_pager_interaction will index into the table as
                            --normal
                            player:base().num_answered = player:base().num_answered + 1
                            local tableValue
                            if player:base().num_answered <= getEffectiveNumPagersPerPlayer() then
                                tableValue = 1
                            else
                                tableValue = 0
                            end
                            for i = 0, (numPagers - 1), 1 do
                                table.insert(bluffChance, tableValue)
                            end
                            table.insert(bluffChance, 0)

                            tweak_data.player.alarm_pager["bluff_success_chance"] = bluffChance
                            tweak_data.player.alarm_pager["bluff_success_chance_w_skill"] = bluffChance
                            if player:base().is_local_player then
                                addLocalPagerAnswered()
                            end
                        end
                    end
                end
            end
        end)
        if not ok then
            log("[Silent Assassin] at_interact_start : erreur de compatibilité (le pager se comportera normalement) : " .. tostring(err))
        end
        _IntimitateInteractionExt_at_interact_start(self, player, timer)
    end

elseif RequiredScript == "lib/managers/crimespreemanager" then
    -- This is the last function that is called by NetworkMatchMakingSTEAM:set_attributes before calling
    -- self.lobby_handler:set_lobby_data, which is what ultimately gets sent to Steam when creating a
    -- lobby.  I can hide anything I want in this table and I'll see it in the client in
    -- NetworkMatchMakingSTEAM:_lobby_to_numbers.
    if not _CrimeSpreeManager_apply_matchmake_attributes then 
        _CrimeSpreeManager_apply_matchmake_attributes = CrimeSpreeManager.apply_matchmake_attributes
    end
    function CrimeSpreeManager.apply_matchmake_attributes(self, lobby_attributes)
        _CrimeSpreeManager_apply_matchmake_attributes(self, lobby_attributes)
        if isSAEnabled() then
            lobby_attributes.silent_assassin = 1
        end
        --log("apply_matchmake_attributes returns " .. json.encode(lobby_attributes))
    end

elseif RequiredScript == "lib/network/matchmaking/networkmatchmakingsteam" then
    -- -----------------------------------------------------------------
    -- COMPAT DIESEL 3.0 : l'ancienne version de ce mod copiait/collait
    -- l'intégralité du corps de NetworkMatchMakingSTEAM.search_lobby
    -- (une fonction interne du jeu, figée "telle qu'elle était" dans une
    -- très vieille build). A chaque mise à jour du moteur, cette copie
    -- devient obsolète et peut planter, casser la recherche de lobbies,
    -- ou simplement ne plus s'appliquer du tout.
    --
    -- On n'a plus besoin de dupliquer cette fonction : on se contente
    -- d'ajouter notre filtre "silent_assassin" juste avant que le jeu
    -- lance sa recherche (LobbyBrowser:refresh / refresh_lan), via des
    -- PreHooks sur des méthodes bien plus stables dans le temps que le
    -- corps entier de search_lobby. Si jamais ces méthodes elles-mêmes
    -- ont disparu/changé de nom, le mod le signale dans le log au lieu
    -- de planter, et continue de fonctionner pour le blocage du pager
    -- (la fonctionnalité principale), seul le filtre de matchmaking
    -- optionnel serait alors indisponible.
    -- -----------------------------------------------------------------

    local function sa_apply_matchmaking_filter(browser)
        if not browser or not browser.set_lobby_filter then
            return
        end
        local ok, err = pcall(function()
            local filter = getMatchmakingFilter()
            -- 1 -> aucun filtre, 2 -> exiger Silent Assassin, 3 -> l'éviter
            if filter == 2 then
                browser:set_lobby_filter("silent_assassin", 1, "equal")
            elseif filter == 3 then
                browser:set_lobby_filter("silent_assassin", 1, "not_equal")
            end
        end)
        if not ok then
            log("[Silent Assassin] Impossible d'appliquer le filtre de matchmaking (compat Diesel 3.0) : " .. tostring(err))
        end
    end

    local function sa_add_interest_key(keys)
        if type(keys) ~= "table" then
            return
        end
        local ok, err = pcall(function()
            if getMatchmakingFilter() == 2 then
                table.insert(keys, "silent_assassin")
            end
        end)
        if not ok then
            log("[Silent Assassin] Impossible d'ajouter la clé d'intérêt de matchmaking : " .. tostring(err))
        end
    end

    if type(LobbyBrowser) ~= "table" then
        log("[Silent Assassin] Classe LobbyBrowser introuvable ou incompatible (compat Diesel 3.0, ex. Biglobby3) : le filtre de matchmaking Silent Assassin est désactivé, le reste du mod fonctionne normalement.")
    else
        if LobbyBrowser.set_interest_keys then
            Hooks:PreHook(LobbyBrowser, "set_interest_keys", "SilentAssassin_MM_InterestKeys", function(self, keys)
                sa_add_interest_key(keys)
            end)
        else
            log("[Silent Assassin] LobbyBrowser:set_interest_keys introuvable (compat Diesel 3.0) : le filtre 'exiger' du matchmaking pourrait ne pas fonctionner.")
        end

        if LobbyBrowser.refresh then
            Hooks:PreHook(LobbyBrowser, "refresh", "SilentAssassin_MM_Refresh", function(self, ...)
                sa_apply_matchmaking_filter(self)
            end)
        else
            log("[Silent Assassin] LobbyBrowser:refresh introuvable (compat Diesel 3.0) : le filtre de matchmaking Silent Assassin est désactivé.")
        end

        if LobbyBrowser.refresh_lan then
            Hooks:PreHook(LobbyBrowser, "refresh_lan", "SilentAssassin_MM_RefreshLan", function(self, ...)
                sa_apply_matchmaking_filter(self)
            end)
        end
    end

    -- Diffuse le flag "silent_assassin" dans les données du lobby hébergé
    -- (utilisé par les autres joueurs pour filtrer/repérer les lobbies
    -- Silent Assassin). Wrapper simple et sûr, ne réimplémente rien.
    if NetworkMatchMakingSTEAM._lobby_to_numbers then
        if not _NetworkMatchMakingSTEAM__lobby_to_numbers then
            _NetworkMatchMakingSTEAM__lobby_to_numbers = NetworkMatchMakingSTEAM._lobby_to_numbers
        end
        function NetworkMatchMakingSTEAM._lobby_to_numbers(self, lobby)
            local numbers = _NetworkMatchMakingSTEAM__lobby_to_numbers(self, lobby)
            return numbers
        end
    end
elseif RequiredScript == "lib/managers/jobmanager" then
    if not _JobManager_current_stage_data then
        _JobManager_current_stage_data = JobManager.current_stage_data
    end
    function JobManager.current_stage_data(self)
        if isSAEnabled() and isPagerBonusEnabled() then 
            return modifyGhostBonus(self, _JobManager_current_stage_data(self))
        else
            return _JobManager_current_stage_data(self)
        end
    end

    if not _JobManager_current_level_data then
        _JobManager_current_level_data = JobManager.current_level_data
    end

    function JobManager.current_level_data(self)
        if isSAEnabled() and isPagerBonusEnabled() then
            return modifyGhostBonus(self, _JobManager_current_level_data(self))
        else
            return _JobManager_current_level_data(self)
        end
    end

    function modifyGhostBonus(self, level_data)
        --when the level is completed, modify the ghost_bonus of the stage.
        --This is called from JobManager.accumulate_ghost_bonus, which sets the
        --stealth bonus
        if level_data and level_data.ghost_bonus then
            local new_data = {}
            for k, v in pairs(level_data) do
                if k == "ghost_bonus" then
                    local bonus
                    if JobManager.on_last_stage(self) then
                        bonus = calculateLevelStealthBonus()
                    else
                        bonus = calculateStageStealthBonus()
                    end
                    --make sure the total stealth bonus is never negative
                    new_data[k] = math.clamp(v + bonus, 0, 1)
                else
                    new_data[k] = v
                end
            end

            return new_data
        end
        return level_data
    end
end

function CreateSALobbyMessage()
        local message = managers.localization:text("sa_lobby_notice_1")
        if isStealthKillEnabled() then
            message = message .. managers.localization:text("sa_lobby_notice_2")
        end
            
        local params = {
            num_pagers = getNumPagers(),
            num_per_player = getNumPagersPerPlayer(),
            pager_detection_threshold_pct = getPagerDetectionThreshold() * 100
        }
        message = message .. managers.localization:text("sa_lobby_notice_3", params)
        return message
end

Hooks:Add("NetworkManagerOnPeerAdded", "NetworkManagerOnPeerAdded_SA", function(peer, peer_id)
    if Network:is_server() and isSAEnabled() then

        DelayedCalls:Add("DelayedSAAnnounce" .. tostring(peer_id), 2, function()

            local message = CreateSALobbyMessage()
            local peer2 = managers.network:session() and managers.network:session():peer(peer_id)
            if peer2 then
                peer2:send("send_chat_message", ChatManager.GAME, message)
            end
        end)
    end
end)
