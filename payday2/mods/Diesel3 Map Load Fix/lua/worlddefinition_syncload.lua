-- Diesel3 Map Load Fix
--
-- Problem this addresses:
-- When a custom (BeardLib) map spawns a static unit that exists in the asset
-- database but is not loaded by any package, BeardLib's pre-hook
-- "BeardLibEnsureUnitsAreLoaded" on WorldDefinition:_create_statics_unit calls
--   managers.dyn_resource:load(ext, path, DYN_RESOURCES_PACKAGE)
-- which is ASYNCHRONOUS. The original _create_statics_unit then spawns the unit
-- in the same frame, while its model/object/material_config may still be
-- loading. The engine dereferences a resource that is not resident yet ->
-- access violation, with no Lua stack in the crash log.
--
-- This file removes that fallback and replaces it with a BLOCKING load, so a
-- unit is guaranteed to be resident before it is spawned.
--
-- The blocking load MUST go through DynamicResourceManager:load() with no
-- completion callback. An earlier version called
--   PackageManager:package("packages/dyn_resources"):load_temp_resource(...)
-- directly (the call BeardLib uses in FileManager:ForceEarlyLoad for single
-- font files). That bypasses the manager's bookkeeping: the resource is not
-- reference counted, so the same unit could be held by our temp load and by the
-- level package at the same time, and the first unload freed memory the other
-- one was still using. The result was heap corruption -- an access violation
-- inside the engine allocator, minutes after loading, with no Lua stack.
--
-- It is deliberately no-worse-than-before: if the blocking load is unavailable
-- or throws, we fall through to BeardLib's original asynchronous call.
--
-- Every preloaded unit is logged. If the game still crashes, the LAST unit
-- logged is the one that failed to spawn.

core:module("CoreWorldDefinition")
WorldDefinition = WorldDefinition or CoreWorldDefinition.WorldDefinition

local unit_ids = Idstring("unit")

local BEARDLIB_HOOK_ID = "BeardLibEnsureUnitsAreLoaded"
local OUR_HOOK_ID = "Diesel3MapLoadFixEnsureUnitsLoaded"

local stats = {sync = 0, async = 0}

-- Blocking, reference counted load through DynamicResourceManager. Passing
-- false as the completion callback makes the load synchronous; the manager
-- keeps the reference count and unloads the resource itself at the end of the
-- level. Returns true only if the unit is actually resident afterwards.
local function sync_load(name_ids)
	local dres = managers and managers.dyn_resource
	if not dres or not dres.load then
		return false
	end

	local pkg = DynamicResourceManager and DynamicResourceManager.DYN_RESOURCES_PACKAGE or dres.DYN_RESOURCES_PACKAGE
	if not pkg then
		return false
	end

	-- Already held by the manager: touching it again would only add a second
	-- reference we never release.
	if dres.has_resource and dres:has_resource(unit_ids, name_ids, pkg) then
		return PackageManager:has(unit_ids, name_ids)
	end

	if not pcall(dres.load, dres, unit_ids, name_ids, pkg, false) then
		return false
	end

	return PackageManager:has(unit_ids, name_ids)
end

local function ensure_unit_loaded(self, data)
	local name = data and data.unit_data and data.unit_data.name
	if not name then
		return
	end

	local ok, name_ids = pcall(function() return name:id() end)
	if not ok or not name_ids then
		return
	end

	-- Already resident, or nothing we could load anyway: leave it alone.
	if PackageManager:has(unit_ids, name_ids) or not DB:has(unit_ids, name_ids) then
		return
	end

	if sync_load(name_ids) then
		stats.sync = stats.sync + 1
		log(string.format("[Diesel3 Map Load Fix] Preloaded (blocking): %s", tostring(name)))
		return
	end

	-- Blocking path unavailable: keep BeardLib's original behaviour rather than
	-- leaving the unit unloaded entirely.
	stats.async = stats.async + 1
	log(string.format("[Diesel3 Map Load Fix] No blocking load for %s, falling back to async", tostring(name)))
	if BeardLib and BeardLib.Managers and BeardLib.Managers.File then
		BeardLib.Managers.File:LoadFileFromDB("unit", name)
	end
end

-- Hooks:PreHook ignores a second registration under an id that already exists,
-- so BeardLib's asynchronous version has to be removed before ours is added.
local function install()
	Hooks:RemovePreHook(BEARDLIB_HOOK_ID)
	Hooks:RemovePreHook(OUR_HOOK_ID)
	Hooks:PreHook(WorldDefinition, "_create_statics_unit", OUR_HOOK_ID, ensure_unit_loaded)
end

install()

-- Mod load order is not guaranteed: if BeardLib's hook file runs after this one
-- it would register its version again. Re-install once a WorldDefinition is
-- actually built, which happens well after every mod has finished loading.
Hooks:PostHook(WorldDefinition, "init", "Diesel3MapLoadFixInstall", function(self)
	stats.sync = 0
	stats.async = 0
	install()
	log("[Diesel3 Map Load Fix] Active for this level")
end)

Hooks:PostHook(WorldDefinition, "create", "Diesel3MapLoadFixSummary", function(self, layer)
	if stats.sync > 0 or stats.async > 0 then
		log(string.format("[Diesel3 Map Load Fix] Layer '%s': %d preloaded, %d fell back to async",
			tostring(layer), stats.sync, stats.async))
	end
end)
