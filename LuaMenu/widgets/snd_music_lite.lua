--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name	= "Music Player Lite",
		desc	= "Plays music for ingame lobby client",
		author	= "GoogleFrog and KingRaptor",
		date	= "25 September 2016",
		license	= "GNU GPL, v2 or later",
		layer	= 2000,
		enabled	= true	--	loaded by default?
	}
end

Spring.CreateDir("music/custom/loading")
Spring.CreateDir("music/custom/peace")
Spring.CreateDir("music/custom/warlow")
Spring.CreateDir("music/custom/warhigh")
Spring.CreateDir("music/custom/interludes")
Spring.CreateDir("music/custom/bossfight")
Spring.CreateDir("music/custom/victory")
Spring.CreateDir("music/custom/defeat")
Spring.CreateDir("music/custom/gameover")
Spring.CreateDir("music/custom/menu")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local playingTrack	-- boolean
local previousTrack
local previousTrackType = "intro" -- intro or peace
local loopTrack	-- string trackPath
local randomTrackList
local introTrackList = {}
local peaceTrackList = {}
local openTrack
local introTracksIndex = 0
local peaceTracksIndex = 0

local musicDirOriginal 			= 'luamenu/configs/gameconfig/byar/lobbyMusic/original'
local musicDirEventAprilFools 	= 'luamenu/configs/gameconfig/byar/lobbyMusic/event/aprilfools'
local musicDirEventSpooktober 	= 'luamenu/configs/gameconfig/byar/lobbyMusic/event/spooktober'
local musicDirEventXmas 		= 'luamenu/configs/gameconfig/byar/lobbyMusic/event/xmas'
local musicDirCustom 			= 'music/custom/menu'
local musicDirCustom2 			= 'music/custom/peace'

local allowedExtensions = "{*.ogg,*.mp3}"
local disabledTracksConfig = "MusicDisabledTracks"

local function NormalizePath(path)
	return string.lower(string.gsub(path or "", "\\", "/"))
end

local function GetTrackTitle(path)
	local title = string.match(NormalizePath(path), "([^/]+)$") or ""
	title = string.gsub(title, "%.%w+$", "")
	-- Chobby ships shortened INTRO copies of BAR's menu-version tracks. These
	-- suffixes describe the copy, rather than being part of the track identity.
	title = string.gsub(title, "%s*%(%s*intro%s*%)%s*$", "")
	title = string.gsub(title, "%s*%(%s*menu%s+version[^%)]*%)%s*$", "")
	title = string.gsub(title, "%s+", " ")
	return title
end

local function GetSavedTrackIdentity(path)
	local normalizedPath = NormalizePath(path)
	local title = GetTrackTitle(normalizedPath)
	local eventPack, category = string.match(normalizedPath, "^music/original/events/([^/]+)/([^/]+)/")

	if eventPack and (category == "menu" or category == "peace") then
		return eventPack .. "/" .. category .. "/" .. title
	end

	local pack, regularCategory = string.match(normalizedPath, "^music/([^/]+)/([^/]+)/")
	if pack and (regularCategory == "menu" or regularCategory == "peace") then
		return pack .. "/" .. regularCategory .. "/" .. title
	end
end

local function GetLobbyTrackIdentity(path)
	local normalizedPath = NormalizePath(path)
	local title = GetTrackTitle(normalizedPath)
	local customCategory = string.match(normalizedPath, "^music/custom/([^/]+)/")
	if customCategory == "menu" or customCategory == "peace" then
		return "custom/" .. customCategory .. "/" .. title
	end

	local eventPack = string.match(normalizedPath, "/lobbymusic/event/([^/]+)/")
	if eventPack then
		-- Chobby's old directory name predates the Halloween config/pack name.
		eventPack = eventPack == "spooktober" and "halloween" or eventPack
		return eventPack .. "/menu/" .. title
	end

	if string.find(normalizedPath, "/lobbymusic/original/", 1, true) then
		local category = string.find(normalizedPath, "%(%s*intro%s*%)%.[^/]+$") and "menu" or "peace"
		return "original/" .. category .. "/" .. title
	end
end

local function GetSavedTrackIdentities(configName)
	local identities = {}
	for path in string.gmatch(Spring.GetConfigString(configName, ""), "[^|]+") do
		local identity = GetSavedTrackIdentity(path)
		if identity then
			identities[identity] = true
		end
	end
	return identities
end

local function IsLobbyTrackEnabled(track, disabledTrackIdentities)
	local identity = GetLobbyTrackIdentity(track)
	return not (identity and disabledTrackIdentities[identity])
end

local function FilterDisabledTracks(playlist, disabledTrackIdentities)
	local filtered = {}
	for _, track in ipairs(playlist) do
		if IsLobbyTrackEnabled(track, disabledTrackIdentities) then
			filtered[#filtered + 1] = track
		end
	end
	return filtered
end

local easterEggCountdown = Spring.GetConfigInt('ChobbyLaunchesCount', 0) + 1 -- Don't play easter egg intro song for first few launches to not make weird first impression
Spring.SetConfigInt('ChobbyLaunchesCount', easterEggCountdown)

if Spring.GetConfigInt('snd_volmaster', 30) > 80 then Spring.SetConfigInt('snd_volmaster', 30) end

local function GetRandomTrack(previousTrack)
	-- randomTrackList
	-- introTrackList
	-- peaceTrackList
	local nextTrack
	local trackType
	for i = 1, #randomTrackList do
		if (previousTrackType == "intro" or (not introTrackList[1])) and peaceTrackList[1] then -- we're checking if there are any peace tracks
			trackType = "peace"
			peaceTracksIndex = peaceTracksIndex + 1
			if not peaceTrackList[peaceTracksIndex] then
				peaceTracksIndex = 1
			end
			nextTrack = peaceTrackList[peaceTracksIndex]
		elseif (previousTrackType == "peace" or (not peaceTrackList[1])) and introTrackList[1] then -- we're checking if there are any intro tracks
			trackType = "intro"
			introTracksIndex = introTracksIndex + 1
			if not introTrackList[introTracksIndex] then
				introTracksIndex = 1
			end
			nextTrack = introTrackList[introTracksIndex]
		end

		if nextTrack and trackType then
			previousTrackType = trackType
			return nextTrack
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function StartTrack(trackName)
	trackName = trackName or GetRandomTrack(previousTrack)
	if not trackName then
		return
	end
	local volume = WG.Chobby.Configuration.menuMusicVolume
	Spring.Echo("Starting Track", trackName, volume)
	if volume == 0 then
		return
	end
	Spring.StopSoundStream()
	Spring.PlaySoundStream(trackName, 1)
	Spring.SetSoundStreamVolume(volume)
	playingTrack = true
end

local function LoopTrack(trackName, trackNameIntro)
	trackNameIntro = trackNameIntro or trackName
	loopTrack = trackName
	StartTrack(trackNameIntro)
end

local function StopTrack()
	Spring.StopSoundStream()
	playingTrack = false
	loopTrack = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SetTrackVolume()
	local volume = WG.Chobby.Configuration.menuMusicVolume
	if volume == 0 then
		StopTrack()
		return
	end
	if playingTrack then
		Spring.SetSoundStreamVolume(volume)
		return
	end
	StartTrack(GetRandomTrack())
	previousTrack = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local firstActivation = true
local ingame = false

function widget:Update()

	if ingame or (WG.Chobby.Configuration.menuMusicVolume == 0 )then
		return
	end

	if not playingTrack then
		return
	end

	local playedTime, totalTime = Spring.GetSoundStreamTime()
	playedTime = math.floor(playedTime)
	totalTime = math.floor(totalTime)

	if (playedTime >= totalTime) then
		local newTrack = loopTrack or GetRandomTrack(previousTrack)
		StartTrack(newTrack)
		previousTrack = newTrack
	end
end

local MusicHandler = {
	StartTrack = StartTrack,
	StopTrack = StopTrack,
	LoopTrack = LoopTrack
}

-- Called just before the game loads
-- This could be used to implement music in the loadscreen
--function widget:GamePreload()
--	-- Ingame, no longer any of our business
--	if Spring.GetGameName() ~= "" then
--		ingame = true
--		StopTrack()
--	end
--end

-- called when returning to menu from a game
function widget:ActivateMenu()
	ingame = false
	if firstActivation then
		firstActivation = false
		if openTrack then
			StartTrack(openTrack)
			previousTrack = openTrack
		end
		return
	end
	-- start playing music again
	if not playlistBuild() then
		return
	end
	local newTrack = GetRandomTrack(previousTrack)
	StartTrack(newTrack)
	previousTrack = newTrack
end


function playlistMerge(t1, t2)
	for k,v in ipairs(t2) do
	   table.insert(t1, v)
	end 
	return t1
end

function tableshuffle(sequence, firstIndex) -- doesn't seem like Chobby has common functions, so i'll put this here
	firstIndex = firstIndex or 1
	for i = firstIndex, #sequence - 2 + firstIndex do
		local j = math.random(i, #sequence)
		sequence[i], sequence[j] = sequence[j], sequence[i]
	end
end

function playlistBuild()
	math.randomseed( math.ceil(os.clock()*1000000) )
	math.random(); math.random(); math.random()
	Spring.Echo("RANDOMSEED", math.ceil(os.clock()*1000000))

	randomTrackList = {}
	introTrackList = {}
	peaceTrackList = {}
	customIntroTrack = nil
	openTrack = nil

	-- Original Soundtrack List
	if Spring.GetConfigInt('UseSoundtrackNew', 1) == 1 then
		customIntroTrack = "luamenu/configs/gameConfig/byar/lobbyMusic/original/matteo dell'acqua - foobar (intro).ogg"
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirOriginal, allowedExtensions))
	end

	-- April Fools
	if Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1 and (tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) <= 7) then
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirEventAprilFools, allowedExtensions))
	end
	if Spring.GetConfigInt('UseSoundtrackAprilFoolsPostEvent', 0) == 1 and (not (tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) <= 7)) then
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirEventAprilFools, allowedExtensions))
	end
	if #VFS.DirList(musicDirEventAprilFools, allowedExtensions) >= 1 and Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1 and (tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) <= 3) then
		customIntroTrack = VFS.DirList(musicDirEventAprilFools, allowedExtensions)[math.random(1,#VFS.DirList(musicDirEventAprilFools, allowedExtensions))]
	end

	-- Spooktober
	-- The lobby directory retains its legacy name, but BAR stores this pack under the Halloween config keys.
	if Spring.GetConfigInt('UseSoundtrackHalloween', 1) == 1 and (tonumber(os.date("%m")) == 10 and tonumber(os.date("%d")) >= 17) then
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirEventSpooktober, allowedExtensions))
	end
	if Spring.GetConfigInt('UseSoundtrackHalloweenPostEvent', 0) == 1 and (not (tonumber(os.date("%m")) == 10 and tonumber(os.date("%d")) >= 17)) then
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirEventSpooktober, allowedExtensions))
	end
	if #VFS.DirList(musicDirEventSpooktober, allowedExtensions) >= 1 and Spring.GetConfigInt('UseSoundtrackHalloween', 1) == 1 and (tonumber(os.date("%m")) == 10 and tonumber(os.date("%d")) >= 17) then
		customIntroTrack = VFS.DirList(musicDirEventSpooktober, allowedExtensions)[math.random(1,#VFS.DirList(musicDirEventSpooktober, allowedExtensions))]
	end

	-- Xmas
	if Spring.GetConfigInt('UseSoundtrackXmas', 1) == 1 and (tonumber(os.date("%m")) == 12 and tonumber(os.date("%d")) >= 12) then
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirEventXmas, allowedExtensions))
	end
	if Spring.GetConfigInt('UseSoundtrackXmasPostEvent', 0) == 1 and (not (tonumber(os.date("%m")) == 12 and tonumber(os.date("%d")) >= 12)) then
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirEventXmas, allowedExtensions))
	end
	if #VFS.DirList(musicDirEventXmas, allowedExtensions) >= 1 and Spring.GetConfigInt('UseSoundtrackXmas', 1) == 1 and (tonumber(os.date("%m")) == 12 and tonumber(os.date("%d")) >= 12 and tonumber(os.date("%d")) <= 26) then
		customIntroTrack = VFS.DirList(musicDirEventXmas, allowedExtensions)[math.random(1,#VFS.DirList(musicDirEventXmas, allowedExtensions))]
	end

	-- Custom Soundtrack List
	if Spring.GetConfigInt('UseSoundtrackCustom', 1) == 1 then
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirCustom, allowedExtensions))
		randomTrackList = playlistMerge(randomTrackList, VFS.DirList(musicDirCustom2, allowedExtensions))
	end

	-- LuaUI writes canonical BAR VFS paths to shared engine config. Translate
	-- Chobby's copied lobby paths to the same logical identities before filtering.
	local disabledTrackIdentities = GetSavedTrackIdentities(disabledTracksConfig)
	randomTrackList = FilterDisabledTracks(randomTrackList, disabledTrackIdentities)
	if customIntroTrack and not IsLobbyTrackEnabled(customIntroTrack, disabledTrackIdentities) then
		customIntroTrack = nil
	end

	if randomTrackList == nil or #randomTrackList == 0 then
		Spring.Log("snd_music.lite.lua", LOG.NOTICE, "No enabled lobby music tracks found; keeping the player silent")
		-- Keep the widget registered while silent. A later game can re-enable tracks,
		-- and ActivateMenu must still be available to rebuild the playlist on return.
		StopTrack()
		return false
	end

	-- put all intro tracks in separate list
	for index, file in pairs(randomTrackList) do
		local trackTest = file
		if string.find(trackTest, "(intro)") or string.find(trackTest, "(INTRO)") then
			introTrackList[#introTrackList+1] = trackTest
		else
			peaceTrackList[#peaceTrackList+1] = trackTest
		end
	end

	tableshuffle(introTrackList)
	tableshuffle(peaceTrackList)
	
	--[[
	Spring.Echo("Intro Tracks")
	for _, file in pairs(introTrackList) do
		Spring.Echo(file)
	end

	Spring.Echo("Peace/Filler Tracks")
	for _, file in pairs(peaceTrackList) do
		Spring.Echo(file)
	end
	]]

	for i = 1,1000 do
		if customIntroTrack then
			openTrack = customIntroTrack
			break
		end
		if openTrack then
			break
		else
			openTrack = introTrackList[1]
			introTracksIndex = 1
		end
		if openTrack then
			break
		else
			openTrack = peaceTrackList[1]
			peaceTracksIndex = 1
		end
		if openTrack then
			break
		end
	end
	return true
end

function widget:Initialize()
	-- Even an empty playlist must continue initialization so the widget can recover later.
	playlistBuild()

	local Configuration = WG.Chobby.Configuration

	local function onConfigurationChange(listener, key, value)
		if key == "menuMusicVolume" then
			SetTrackVolume()
		end
	end
	Configuration:AddListener("OnConfigurationChange", onConfigurationChange)

	local function OnBattleAboutToStart()
		ingame = true
		StopTrack()
	end
	WG.LibLobby.localLobby:AddListener("OnBattleAboutToStart", OnBattleAboutToStart)
	WG.LibLobby.lobby:AddListener("OnBattleAboutToStart", OnBattleAboutToStart)

	WG.MusicHandler = MusicHandler
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
