-- LobbyMusic — loops through lobby tracks while the player isn't skiing
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local TRACKS = {
	"rbxassetid://113158443139294",
	"rbxassetid://138865131493283",
	"rbxassetid://9044539308",
}
local VOLUME = 0.35
local FADE = 1.2

_G.SkiStartedSignal = _G.SkiStartedSignal or Instance.new("BindableEvent")
_G.SkiEndedSignal = _G.SkiEndedSignal or Instance.new("BindableEvent")

local sound = Instance.new("Sound")
sound.Name = "LobbyMusic"
sound.Volume = 0
sound.Parent = SoundService

local index = math.random(1, #TRACKS)
local inLobby = true
local fadeTween

local function fadeTo(vol, onDone)
	if fadeTween then fadeTween:Cancel() end
	fadeTween = TweenService:Create(sound, TweenInfo.new(FADE, Enum.EasingStyle.Sine), {Volume = vol})
	if onDone then fadeTween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then onDone() end
	end) end
	fadeTween:Play()
end

local function playTrack(i)
	index = ((i - 1) % #TRACKS) + 1
	sound.SoundId = TRACKS[index]
	sound.TimePosition = 0
	sound:Play()
	if inLobby then fadeTo(VOLUME) end
	-- skip a track that fails to load instead of sitting in silence
	task.delay(8, function()
		if sound.SoundId == TRACKS[index] and not sound.IsLoaded then
			playTrack(index + 1)
		end
	end)
end

-- next track when one finishes (each track plays once, then the list loops)
sound.Ended:Connect(function()
	playTrack(index + 1)
end)

-- fade out while skiing, resume the same track when back in the lobby
_G.SkiStartedSignal.Event:Connect(function()
	inLobby = false
	fadeTo(0, function()
		if not inLobby then sound:Pause() end
	end)
end)

_G.SkiEndedSignal.Event:Connect(function()
	if inLobby then return end
	inLobby = true
	task.spawn(function()
		-- if the run ended in a death, wait until the player has respawned first
		local player = game:GetService("Players").LocalPlayer
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			player.CharacterAdded:Wait()
			task.wait(0.5)
		end
		if not inLobby then return end
		sound.Volume = 0
		sound:Resume()
		if fadeTween then fadeTween:Cancel() end
		fadeTween = TweenService:Create(sound, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Volume = VOLUME})
		fadeTween:Play()
	end)
end)

-------------------------------------------------------------------
-- Ducking: whenever any other sound effect plays (chest opening, spin
-- ticks, cash, UI clicks...), drop the music to a faint background level,
-- then ease it back up once the effects have finished.
-------------------------------------------------------------------
local Players = game:GetService("Players")
local DUCK_LEVEL = 0.12
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "LobbyMusicGroup"
musicGroup.Volume = 1
musicGroup.Parent = SoundService
sound.SoundGroup = musicGroup

-- Only these duck the music: the chest/present opening screen and the cash sound.
-- UI clicks, hover sounds and everything else leave the music alone.
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local function shouldDuck()
	local spin = playerGui:FindFirstChild("PresentSpinGui")
	if spin and spin.Enabled then return true end
	return false
end

local ducked = false
local duckTween
local quietSince = 0
task.spawn(function()
	while true do
		local playing = shouldDuck()
		if playing then
			quietSince = os.clock()
			if not ducked then
				ducked = true
				if duckTween then duckTween:Cancel() end
				duckTween = TweenService:Create(musicGroup, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {Volume = DUCK_LEVEL})
				duckTween:Play()
			end
		elseif ducked and os.clock() - quietSince > 0.6 then
			ducked = false
			if duckTween then duckTween:Cancel() end
			duckTween = TweenService:Create(musicGroup, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {Volume = 1})
			duckTween:Play()
		end
		task.wait(0.1)
	end
end)

-- ===== SKI COURSE ZONES: banners, per-zone lighting, finish return =====
task.spawn(function()
	local Players = game:GetService("Players")
	local Lighting = game:GetService("Lighting")
	local RS = game:GetService("ReplicatedStorage")
	local plr = Players.LocalPlayer
	local Z0 = -931
	local ZONES = {
		{name = "Pinewood Pass", start = 0, tint = Color3.fromRGB(255, 244, 228), amb = Color3.fromRGB(80, 74, 66), atm = Color3.fromRGB(205, 220, 235), dens = 0.3},
		{name = "Glacier Gorge", start = 3000, tint = Color3.fromRGB(215, 238, 255), amb = Color3.fromRGB(70, 95, 125), atm = Color3.fromRGB(170, 215, 255), dens = 0.35},
		{name = "Ember Peak", start = 6000, tint = Color3.fromRGB(255, 205, 175), amb = Color3.fromRGB(110, 60, 45), atm = Color3.fromRGB(150, 95, 80), dens = 0.42},
	}
	local cc = Lighting:FindFirstChild("ZoneTint") or Instance.new("ColorCorrectionEffect")
	cc.Name = "ZoneTint"; cc.Parent = Lighting
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local base = {amb = Lighting.Ambient, out = Lighting.OutdoorAmbient, atm = atm and atm.Color, dens = atm and atm.Density}
	local SkiPrompt
	pcall(function() SkiPrompt = require(RS:WaitForChild("SkiPrompt", 10)) end)
	local bannerGui = Instance.new("ScreenGui")
	bannerGui.Name = "ZoneBannerGui"; bannerGui.ResetOnSpawn = false; bannerGui.DisplayOrder = 40; bannerGui.IgnoreGuiInset = true
	bannerGui.Parent = plr:WaitForChild("PlayerGui")
	local banner = SkiPrompt and SkiPrompt.new(bannerGui, {position = UDim2.fromScale(0.5, 0.2), height = 70, seed = 7})
	local TweenService = game:GetService("TweenService")
	local function applyZone(i)
		local ti = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
		if i == 0 then
			TweenService:Create(cc, ti, {TintColor = Color3.new(1, 1, 1)}):Play()
			TweenService:Create(Lighting, ti, {Ambient = base.amb, OutdoorAmbient = base.out}):Play()
			if atm then TweenService:Create(atm, ti, {Color = base.atm, Density = base.dens}):Play() end
			return
		end
		local z = ZONES[i]
		TweenService:Create(cc, ti, {TintColor = z.tint}):Play()
		TweenService:Create(Lighting, ti, {Ambient = z.amb, OutdoorAmbient = z.amb}):Play()
		if atm then TweenService:Create(atm, ti, {Color = z.atm, Density = z.dens}):Play() end
		if banner then
			banner:show(z.name:upper())
			task.delay(3, function() banner:hide() end)
		end
	end
	local current = 0
	local finishing = false
	while true do
		task.wait(0.25)
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			local d = hrp.Position.Z - Z0
			local zi = 0
			if d > 0 and hrp.Position.Y < 1100 then
				zi = 1
				if d > ZONES[2].start then zi = 2 end
				if d > ZONES[3].start then zi = 3 end
			end
			if zi ~= current then current = zi; applyZone(zi) end
			-- Finish area: once stopped past the finish gate, head back to the lobby
			if d > 9100 and not finishing then
				finishing = true
				if banner then banner:show("COURSE COMPLETE!") end
				task.delay(4, function()
					if banner then banner:hide() end
					local c = plr.Character
					local r = c and c:FindFirstChild("HumanoidRootPart")
					local spawnPart = workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("Spawn") and workspace.Lobby.Spawn:FindFirstChildOfClass("SpawnLocation")
					if r and spawnPart then
						if _G.ForceEndSki then pcall(_G.ForceEndSki) end
						r.AssemblyLinearVelocity = Vector3.zero
						c:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
					end
					task.wait(1)
					finishing = false
				end)
			end
		end
	end
end)

playTrack(index)
