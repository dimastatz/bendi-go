-- Loads and saves every player's progress (PRD-006, requirements 10 and 11) with a Roblox DataStore.
-- Players can always keep playing, even when the DataStore isn't working:
-- - If loading fails, the game keeps trying in the background. Until it works, nothing is saved, so a failed load
--   can never write over a real save. When loading finally works, progress from this session is added to the save.
-- - If saving fails, the game tries again later.
-- The total star count reaches the client through the player's "Stars" attribute, and "Licensed" is true once the
-- player has a driving license.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Progress = require(ReplicatedStorage.Core.Progress)

local PlayerProgress = {}

local STORE_NAME = "BendiGoProgress"
local SAVE_INTERVAL = 30 -- seconds between saves (and between load retries)
local LOAD_ATTEMPTS = 3
local RETRY_DELAY = 2

-- "new" means the player has never played before, and "failed" that their save couldn't be loaded yet.
export type Status = "loading" | "new" | "loaded" | "failed"

-- `changes` counts changes, so a save knows whether something changed while it was saving.
type Entry = { data: Progress.Data, loaded: boolean, dirty: boolean, changes: number, status: Status }

local entries: { [Player]: Entry } = {}
local readyListeners: { (Player, Status) -> () } = {}
local changedListeners: { (Player) -> () } = {}

-- The DataStore can't be used in Studio until the place is published and API access is turned on.
local hasStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
if not hasStore then
	warn(`Bendi Go: progress won't be saved, the DataStore isn't available: {store}`)
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function showOnPlayer(player: Player, entry: Entry)
	player:SetAttribute("Stars", entry.data.stars)
	player:SetAttribute("Licensed", entry.data.license ~= nil)
end

-- True if the player earned anything this session.
local function hasProgress(data: Progress.Data): boolean
	return data.stars > 0 or next(data.lessons) ~= nil or data.license ~= nil
end

local function notifyChanged(player: Player)
	for _, listener in changedListeners do
		task.spawn(listener, player)
	end
end

-- Tries to load the player's save. On success, adds this session's progress to it.
local function tryLoad(player: Player, entry: Entry): boolean
	if not hasStore then
		return false
	end
	local ok, saved = pcall(store.GetAsync, store, keyFor(player))
	if not ok then
		-- Retries in the background happen every 30 seconds, so only the first failures are reported.
		if entry.status == "loading" then
			warn(`Bendi Go: couldn't load progress for {player.Name}: {saved}`)
		end
		return false
	end
	if entries[player] ~= entry then
		return true -- the player left while loading
	end
	local hadSession = hasProgress(entry.data)
	entry.data = Progress.merge(Progress.sanitize(saved), entry.data)
	entry.loaded = true
	entry.dirty = hadSession
	entry.status = if saved == nil then "new" else "loaded"
	showOnPlayer(player, entry)
	notifyChanged(player)
	return true
end

-- Saves the player's progress. A save that was never loaded is added to whatever is saved instead of replacing it,
-- so leaving before loading worked never loses the saved progress.
local function save(player: Player, entry: Entry)
	if not hasStore or (entry.loaded and not entry.dirty) then
		return
	end
	local data = entry.data
	local changes = entry.changes
	local ok, err = pcall(store.UpdateAsync, store, keyFor(player), function(saved: any)
		if entry.loaded then
			return data
		end
		return Progress.merge(Progress.sanitize(saved), data)
	end)
	if ok then
		if entry.data == data and entry.changes == changes then
			entry.dirty = false
		end
	else
		warn(`Bendi Go: couldn't save progress for {player.Name}, will try again: {err}`)
	end
end

local function onPlayerAdded(player: Player)
	local entry: Entry = { data = Progress.new(), loaded = false, dirty = false, changes = 0, status = "loading" }
	entries[player] = entry

	for attempt = 1, LOAD_ATTEMPTS do
		if tryLoad(player, entry) then
			break
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(RETRY_DELAY)
		end
	end
	if entries[player] ~= entry then
		return
	end
	if not entry.loaded then
		entry.status = "failed"
		showOnPlayer(player, entry)
	end
	for _, listener in readyListeners do
		task.spawn(listener, player, entry.status)
	end
end

local function onPlayerRemoving(player: Player)
	local entry = entries[player]
	entries[player] = nil
	if entry and (entry.dirty or (not entry.loaded and hasProgress(entry.data))) then
		entry.dirty = true
		save(player, entry)
	end
end

-- The player's progress. Change it only through the functions below, or call `changed` afterwards.
function PlayerProgress.get(player: Player): Progress.Data?
	local entry = entries[player]
	return entry and entry.data
end

-- Tells this module the player's progress changed, so it's shown and saved.
function PlayerProgress.changed(player: Player)
	local entry = entries[player]
	if not entry then
		return
	end
	entry.dirty = true
	entry.changes += 1
	showOnPlayer(player, entry)
	notifyChanged(player)
end

function PlayerProgress.addStar(player: Player)
	local entry = entries[player]
	if entry then
		entry.data.stars += 1
		PlayerProgress.changed(player)
	end
end

-- Calls `listener(player, status)` once each player's save has loaded, or failed to load.
function PlayerProgress.onReady(listener: (Player, Status) -> ())
	table.insert(readyListeners, listener)
end

-- Calls `listener(player)` whenever a player's progress changes.
function PlayerProgress.onChanged(listener: (Player) -> ())
	table.insert(changedListeners, listener)
end

function PlayerProgress.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Save every so often, and keep trying to load saves that failed to load.
	task.spawn(function()
		while true do
			task.wait(SAVE_INTERVAL)
			for player, entry in entries do
				if entry.loaded then
					save(player, entry)
				elseif entry.status == "failed" then
					tryLoad(player, entry)
				end
			end
		end
	end)

	-- Save everyone before the server shuts down.
	game:BindToClose(function()
		local saving = 0
		for player in entries do
			saving += 1
			task.spawn(function()
				onPlayerRemoving(player)
				saving -= 1
			end)
		end
		while saving > 0 do
			task.wait(0.1)
		end
	end)
end

return PlayerProgress
