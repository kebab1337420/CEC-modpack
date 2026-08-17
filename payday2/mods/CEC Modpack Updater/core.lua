-- CEC Modpack Updater
--
-- The pack is distributed as a git repository and installed by running
-- install.bat, so there is nothing to auto-download here: the job is to tell
-- the user their installed copy is behind, which otherwise only shows up as
-- "someone else has a mod I don't".
--
-- version.txt next to this file is the single source of truth. The same file is
-- read locally (as deployed into the game) and fetched from the repository over
-- HTTP; if the two differ, the install is stale.
--
-- Format of version.txt: first line is the version, any following lines are
-- release notes shown in the notification.

if CECModpackUpdater then
	return
end

CECModpackUpdater = {}

CECModpackUpdater.version_url =
	"https://raw.githubusercontent.com/kebab1337420/CEC-modpack/main/payday2/mods/CEC%20Modpack%20Updater/version.txt"

function CECModpackUpdater:_parse(content)
	if type(content) ~= "string" then
		return nil
	end

	local version = content:match("^%s*([^\r\n]+)")
	if not version then
		return nil
	end

	local notes = content:match("[\r\n]+(.*)$")
	return version, notes and notes:gsub("^%s+", ""):gsub("%s+$", "") or ""
end

function CECModpackUpdater:LocalVersion()
	local handle = io.open(ModPath .. "version.txt", "r")
	if not handle then
		return nil
	end

	local content = handle:read("*all")
	handle:close()

	return (self:_parse(content))
end

function CECModpackUpdater:_notify(title, text, color)
	if not (BLT and BLT.Notifications) then
		return
	end

	pcall(function()
		BLT.Notifications:add_notification({
			title = title,
			text = text,
			priority = 95,
			color = color
		})
	end)
end

function CECModpackUpdater:_on_response(data)
	local remote, notes = self:_parse(data)
	local localv = self:LocalVersion()

	if not remote then
		log("[CEC Modpack Updater] unreadable answer from the repository")
		return
	end
	if not localv then
		log("[CEC Modpack Updater] version.txt missing from the installed mod")
		return
	end

	if remote == localv then
		log("[CEC Modpack Updater] modpack up to date (" .. localv .. ")")
		return
	end

	log(string.format("[CEC Modpack Updater] installed %s, repository %s", localv, remote))

	local text = string.format("Installed: %s\nAvailable: %s\nPull the repository and run install.bat.",
		localv, remote)
	if notes ~= "" then
		text = text .. "\n\n" .. notes
	end

	self:_notify("Modpack update available", text, Color(0.2, 0.7, 1))
end

function CECModpackUpdater:Check()
	if self._checked then
		return
	end
	self._checked = true

	if type(dohttpreq) ~= "function" then
		log("[CEC Modpack Updater] no HTTP support available")
		return
	end

	-- Fire and forget: a repository that cannot be reached must not delay or
	-- disturb the menu, so failures only reach the log.
	local ok, err = pcall(function()
		dohttpreq(self.version_url, function(data)
			local success, inner = pcall(function()
				self:_on_response(data)
			end)
			if not success then
				log("[CEC Modpack Updater] check failed: " .. tostring(inner))
			end
		end)
	end)

	if not ok then
		log("[CEC Modpack Updater] request failed: " .. tostring(err))
	end
end
