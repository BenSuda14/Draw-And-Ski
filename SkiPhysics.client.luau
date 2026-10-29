-- SkiPhysics LocalScript
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-------------------------------------------------------------------
-- GRAB INPUT — keyboard (G), mobile touch button, and gamepad (ButtonX)
-------------------------------------------------------------------
local grabButtonHeld = false

if UserInputService.TouchEnabled then
	local grabGui = Instance.new("ScreenGui")
	grabGui.Name = "GrabButtonGui"
	grabGui.ResetOnSpawn = false
	grabGui.Parent = player:WaitForChild("PlayerGui")

	local grabBtn = Instance.new("TextButton")
	grabBtn.Name = "GrabButton"
	grabBtn.Size = UDim2.new(0, 80, 0, 80)
	grabBtn.Position = UDim2.new(1, -110, 1, -220)
	grabBtn.AnchorPoint = Vector2.new(0, 1)
	grabBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
	grabBtn.BackgroundTransparency = 0.3
	grabBtn.Text = "GRAB"
	grabBtn.Font = Enum.Font.GothamBold
	grabBtn.TextScaled = true
	grabBtn.TextColor3 = Color3.new(0,0,0)
	grabBtn.Parent = grabGui
	local grabBtnCorner = Instance.new("UICorner", grabBtn)
	grabBtnCorner.CornerRadius = UDim.new(0.5, 0)

	grabBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			grabButtonHeld = true
		end
	end)
	grabBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			grabButtonHeld = false
		end
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.ButtonX then
		grabButtonHeld = true
	end
end)
UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.ButtonX then
		grabButtonHeld = false
	end
end)
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local animateScript = character:WaitForChild("Animate")
local animator = humanoid:WaitForChild("Animator")
local skis = game.ReplicatedStorage:WaitForChild("Skis")
local thud = game.Workspace.Thud
local treeHitEvent = game.ReplicatedStorage:WaitForChild("TreeHit")
local skiTreeHitEvent = game.ReplicatedStorage:WaitForChild("SkiTreeHit")
local trickEvent, landEvent, wipeoutEvent = nil, nil, nil
task.spawn(function()
	local f = game.ReplicatedStorage:WaitForChild("ScoreEvents")
	trickEvent = f:WaitForChild("TrickScored")
	landEvent = f:WaitForChild("TrickLanded")
	wipeoutEvent = f:WaitForChild("TrickWipeout")
end)
local function fireScore(ref, ...) if ref then ref:Fire(...) end end


-- Add this near the top of SkiPhysics script
local TEX = {
	Cardboard="rbxassetid://13390195",    Bamboo="rbxassetid://1496873192",
	Bone="rbxassetid://148401236",        Foam="rbxassetid://1522748484",
	Rubber="rbxassetid://110634019258977", Fiberglass="rbxassetid://16320000662",
	Carbon="rbxassetid://10812734",       Ceramic="rbxassetid://446458453",
	Cloud="rbxassetid://6956634044",      Shadow="rbxassetid://235781675",
	Slime="rbxassetid://675190919",       Rainbow="rbxassetid://2845339107",
	Rocket="rbxassetid://160970288",
}


ACCELERATION = 20
MAX_SPEED = 120
local FRICTION = 0.995
TURN_SPEED = 80
local WALK_SPEED = 32 -- increased from Roblox default (16) for a snappier lobby feel
local SLOPE_THRESHOLD = 8
local COAST_SPEED_THRESHOLD = 15
local WIPEOUT_STUN = 1.2
local TURN_HOLD_THRESHOLD = 0.6
local MIN_WIPEOUT_AIRTIME = 0.25
local RAMP_BOOST = 45     -- extra pop when leaving a SkiRamp
local lastRampTime = 0
local LAUNCH_BOOST = 12    -- upward velocity added at takeoff
local HANG_FORCE = 30      -- upward studs/s² while airborne (gravity is 196)
local TRICK_MIN_DURATION = {
	spinLeft=0.50, spinRight=0.50,
	frontFlip      = 0.45, backFlip       = 0.45,
	leftMisty      = 0.45, rightMisty     = 0.45,
	leftBackCombo  = 0.42, rightBackCombo = 0.42,
	grab=0.10,
}

local function makeTrack(id, looped, priority)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. id
	local t = animator:LoadAnimation(anim)
	t.Looped = looped
	if priority then t.Priority = priority end
	return t
end
local grabTrack      = makeTrack("91404475776849",  true,  Enum.AnimationPriority.Action)
local wipeoutTrack   = makeTrack("121102192283579", false, Enum.AnimationPriority.Action)
local spinLeftTrack  = makeTrack("105585986734893", true,  Enum.AnimationPriority.Action)
local spinRightTrack = makeTrack("132101526415494", true,  Enum.AnimationPriority.Action)
local frontFlipTrack = makeTrack("91915328516250",  true,  Enum.AnimationPriority.Action)
local backFlipTrack  = makeTrack("115472184620074", true,  Enum.AnimationPriority.Action)
local leftMistyTrack     = makeTrack("78857971464880",  true, Enum.AnimationPriority.Action)
local rightMistyTrack    = makeTrack("99430950338849",  true, Enum.AnimationPriority.Action)
local leftBackComboTrack  = makeTrack("114903659508224", true, Enum.AnimationPriority.Action)
local rightBackComboTrack = makeTrack("105131688157498", true, Enum.AnimationPriority.Action)
local leftTurnTrack       = makeTrack("130455430168265", false)
local rightTurnTrack      = makeTrack("125437984323605", false)
local holdLeftTurnTrack   = makeTrack("82662393732382",  true)
local holdRightTurnTrack  = makeTrack("87807761506638",  true)
local returnFromLeftTrack  = makeTrack("110258262595687", false)
local returnFromRightTrack = makeTrack("73639451332188",  false)
local skiIdleTrack = makeTrack("89624866568272", true)

local function stopAllTrickAnims()
	grabTrack:Stop(); spinLeftTrack:Stop(); spinRightTrack:Stop()
	frontFlipTrack:Stop(); backFlipTrack:Stop()
	leftMistyTrack:Stop(); rightMistyTrack:Stop()
	leftBackComboTrack:Stop(); rightBackComboTrack:Stop()
end
local function stopAllAnims()
	for _, t in pairs(animator:GetPlayingAnimationTracks()) do t:Stop(0) end
end

local slideDir = Vector3.new(0,0,1)
local currentHealth, maxHealth, takeDamage -- forward declared; assigned later, but wipeout() needs to see them
local speed = 0
local isSkiing = false
local treeStunned = false
local currentNormal = Vector3.new(0,1,0)
local isInAir = false
local wasInAir = false
local timeInAir = 0
local hasDoubleJumped = false -- resets each time the player lands
local BASE_JUMP_BOOST = 42    -- upward velocity for the base jump, available to everyone
local DOUBLE_JUMP_BOOST = 55  -- upward velocity added by the double jump
local AIR_BOOST_BONUS = 15     -- extra upward velocity added on every takeoff if Air Boost is owned
local ROCKET_BOOST_FORCE = 90  -- forward speed added by Rocket Boost
local ROCKET_BOOST_COOLDOWN = 3 -- seconds between uses
local rocketBoostReady = true
local airTrickState = "none"
local tricksThisJump = {}
local grabHeld = false
local isStunned = false
local currentTurnState = "none"
local turnStartTime = 0
local isHoldingTurn = false
local leftSki, rightSki, leftFoot, rightFoot

local function wipeout()
	speed = 0; isStunned = true
	stopAllAnims(); wipeoutTrack:Play()
	task.delay(WIPEOUT_STUN, function() isStunned = false; wipeoutTrack:Stop() end)
	if isSkiing and maxHealth and maxHealth > 0 and takeDamage then
		takeDamage(maxHealth * 0.03)
	end
end

local function getTrickInfo(trickName, held, minDur)
	local count = math.max(1, math.floor(held / minDur))
	local spinNames = {"360", "720", "1080", "1440"}
	local spinPts   = {100, 250, 450, 700}
	local flipPfx   = {"", "Double ", "Triple "}
	local flipPts   = {150, 350, 600}
	local comboPfx  = {"", "Double ", "Triple "}
	local comboPts  = {300, 700, 1200}
	if trickName == "spinLeft" then
		local c = math.min(count, 4); return spinNames[c] .. " Left", spinPts[c]
	elseif trickName == "spinRight" then
		local c = math.min(count, 4); return spinNames[c] .. " Right", spinPts[c]
	elseif trickName == "frontFlip" then
		local c = held < 1.15 and 1 or held < 1.75 and 2 or 3
		return flipPfx[c] .. "Front Flip", flipPts[c]
	elseif trickName == "backFlip" then
		local c = held < 1.15 and 1 or held < 1.75 and 2 or 3
		return flipPfx[c] .. "Back Flip", flipPts[c]
	elseif trickName == "leftMisty" then
		local c = held < 1.12 and 1 or held < 1.82 and 2 or 3
		return comboPfx[c] .. "Left Misty", comboPts[c]
	elseif trickName == "rightMisty" then
		local c = held < 1.12 and 1 or held < 1.82 and 2 or 3
		return comboPfx[c] .. "Right Misty", comboPts[c]
	elseif trickName == "leftBackCombo" then
		local c = held < 1.30 and 1 or held < 2.00 and 2 or 3
		return comboPfx[c] .. "Left Rodeo", comboPts[c]
	elseif trickName == "rightBackCombo" then
		local c = held < 1.30 and 1 or held < 2.00 and 2 or 3
		return comboPfx[c] .. "Right Rodeo", comboPts[c]
	elseif trickName == "grab" then
		return "Grab", 75
	end
	return trickName, 100
end

local function checkLanding()
	stopAllTrickAnims(); grabHeld = false; airTrickState = "none"
	local last = tricksThisJump[#tricksThisJump]
	if last and not last.endTime then last.endTime = os.clock() end
	if #tricksThisJump == 0 then return end
	local ok = true
	for _, trick in ipairs(tricksThisJump) do
		local held = (trick.endTime or os.clock()) - trick.startTime
		if held < (TRICK_MIN_DURATION[trick.name] or 0.30) then ok = false; break end
	end
	if not ok then
		tricksThisJump = {}; wipeout(); fireScore(wipeoutEvent)
	else
		-- Build display name and points from all tricks done this jump
		local parts = {}
		local totalPts = 0
		for _, trick in ipairs(tricksThisJump) do
			local minDur = TRICK_MIN_DURATION[trick.name] or 0.30
			local held = (trick.endTime or os.clock()) - trick.startTime
			local displayName, pts = getTrickInfo(trick.name, held, minDur)
			table.insert(parts, displayName)
			totalPts = totalPts + pts
		end
		-- 25% combo bonus when multiple tricks are combined
		local bonus = #parts > 1 and math.floor(totalPts * 0.25) or 0
		local comboName = table.concat(parts, " + ")
		print("[SkiPhysics] firing trickEvent: " .. comboName .. " pts=" .. tostring(totalPts+bonus))
		fireScore(trickEvent, comboName, totalPts + bonus)
		tricksThisJump = {}
		fireScore(landEvent)
	end
end

-- ── CUSTOM SKI GENERATOR ──────────────────────────────────────────────────
-- Reads _G.SkiDesign and builds 3D ski parts welded together.
-- Returns a root Part that gets repositioned each frame (same as leftSki/rightSki).
local leftSkiModel, rightSkiModel  -- track for cleanup


--new code
local function generateSki(footPart, isLeft)
	local design = _G.SkiDesign
	local CELL_W = 0.20
	local CELL_L = 0.38
	local CELL_H = 0.07
	local GAP = 0.015

	-- Get texture ID from design
	local texId = nil
	local matColor = Color3.fromRGB(180,140,90)
	local matMaterial = Enum.Material.SmoothPlastic

	if design and design.material then
		matColor = design.material.color or design.material.c or matColor
		matMaterial = design.material.material or design.material.m or matMaterial

		-- Find texture ID
		for matName, id in pairs(TEX) do
			if matName == design.material.n then
				texId = id
				break
			end
		end
	end

	local root = Instance.new("Part")
	root.Size = Vector3.new(CELL_W*5, CELL_H, CELL_L*12)
	root.Transparency = 1
	root.CanCollide = false
	root.Massless = true
	root.CFrame = footPart.CFrame * CFrame.new(0, -0.15, 0)

	local model = Instance.new("Model")
	model.Name = isLeft and "LeftCustomSki" or "RightCustomSki"
	root.Name = isLeft and "LeftBlueSki" or "RightBlueSki"
	root.Parent = model

	local grid = design and design.grid
	if grid then
		for r = 1, 12 do
			for c = 1, 5 do
				if grid[r] and grid[r][c] then
					local part = Instance.new("Part")
					part.Size = Vector3.new(CELL_W-GAP, CELL_H, CELL_L-GAP)
					part.Color = matColor
					part.Material = matMaterial
					part.CanCollide = false
					part.Massless = true
					part.CastShadow = false
					part.Transparency = 0
					part.Name = "SkiCell"

					local xOff = (c - 3) * CELL_W * (isLeft and 1 or -1)
					local zOff = (r - 6.5) * CELL_L

					part.CFrame = root.CFrame * CFrame.new(xOff, 0, zOff)

					-- Apply texture to each cell
					if texId then
						local decal = Instance.new("Decal")
						decal.Texture = texId
						decal.Face = Enum.NormalId.Top
						decal.Parent = part
					end

					part.Parent = model

					local wc = Instance.new("WeldConstraint")
					wc.Part0 = root
					wc.Part1 = part
					wc.Parent = part
				end
			end
		end
	end

	model.Parent = character
	return root, model
end



-- Apply speed/turn stats from the design
local function applyDesignStats()
	local design = _G.SkiDesign
	if not design or not design.grid then return end
	local filled, totalW = 0, 0
	for r = 1, 12 do
		local w = 0
		for c = 1, 5 do if design.grid[r] and design.grid[r][c] then filled=filled+1; w=w+1 end end
		totalW = totalW + w
	end
	-- Speed no longer varies by shape/square-count — baseline drawing shouldn't meaningfully
	-- affect speed at all (only massive perk-level boosts like Rainbow Trail/Rocket Aura should)
	local spd = 0.5

	-- Turning: simple inverse relationship with total square count.
	-- Small ski = nimble/fast-turning. Big ski = tanky but turns slower.
	local MAX_POSSIBLE_SQUARES = 12 * 5
	local fillRatio = filled / MAX_POSSIBLE_SQUARES
	local man = math.clamp(1 - fillRatio, 0.05, 1)

	MAX_SPEED  = 40 + spd * 80
	TURN_SPEED = 70 -- turning no longer depends on ski size

	-- Apply perk speed multipliers (stack together)
	local player = game:GetService("Players").LocalPlayer
	if player then
		local mult = 1
		if player:GetAttribute("Perk_SnowAura")     then mult = mult * 1.5  end
		if player:GetAttribute("Perk_RainbowTrail") and player:GetAttribute("EquippedTrail") == "RainbowTrail" then mult = mult * 3.3  end
		if player:GetAttribute("Perk_RocketAura")   then mult = mult * 5   end
		MAX_SPEED = MAX_SPEED * mult
		ACCELERATION = 20 * mult  -- scale acceleration too so top speed is reachable quickly
		TURN_SPEED = TURN_SPEED * math.sqrt(mult)  -- boost turning too, but less aggressively, so control keeps up with speed
	end
end

-- Ski health UI + state
local player2 = game:GetService("Players").LocalPlayer
local playerGui2 = player2:WaitForChild("PlayerGui")
local healthGui = playerGui2:WaitForChild("HealthGui", 10)
local healthFrame = healthGui and healthGui:FindFirstChild("Health")
local healthFill = healthFrame and healthFrame:FindFirstChild("HealthFill")
local healthLabelUI = healthFrame and healthFrame:FindFirstChild("HealthLabel")
local drawButtonGui = playerGui2:WaitForChild("DrawButton", 10)

if healthGui then healthGui.Enabled = false end
-- Safety net: wipeout()/takeDamage() never call disableSkiing() before killing the
-- character, so anything waiting on _G.SkiEndedSignal (like the tutorial) would get
-- stuck forever if the run ends via death instead of a clean stop. Fire it here too.
if humanoid then
	humanoid.Died:Connect(function()
		if _G.SkiEndedSignal then _G.SkiEndedSignal:Fire() end
	end)
end
if drawButtonGui then drawButtonGui.Enabled = true end -- force correct baseline in case last session ended mid-ski

-- Safety net: if a previous life died mid-ski before it could restore hidden GUIs,
-- force every known persistent game GUI back to its correct baseline (enabled) here,
-- since respawning doesn't naturally undo whatever hideOtherGuisForSkiing() left disabled
for _, guiName in ipairs({"DrawGui", "MoneyGui", "ShopGui", "TrailGui", "AuraGui", "PresentGui", "TheBuilderGui", "TrickGui", "CashGui", "TutorialPromptGui", "TrickTutorialGui", "RewardFlightGui", "TutorialHighlightGui", "TutorialSpotlightGui", "TutorialFxGui"}) do
	local g = playerGui2:FindFirstChild(guiName)
	if g then g.Enabled = true end
end

-- Safety net: if the trick tutorial got interrupted mid-sequence (e.g. died before
-- completing it), these globals could be stuck on forever, breaking all movement/speed
-- in every future run. Force them back to a safe default on every single spawn.
_G.TrickTutorialLocked = false
_G.SlowMoFactor = 1
if workspace.Gravity < 100 then
	workspace.Gravity = 196 -- restore default if a prior session left it scaled down
end

-- Hide every OTHER game GUI while skiing (only HealthGui should show), and restore them after
local otherGuisHiddenForSkiing = {}
local function hideOtherGuisForSkiing()
	for _, other in ipairs(playerGui2:GetChildren()) do
		if other:IsA("ScreenGui") and other.Name ~= "HealthGui" and other.Name ~= "MoneyGui" and other.Enabled then
			other.Enabled = false
			table.insert(otherGuisHiddenForSkiing, other)
		end
	end
end
local function restoreOtherGuisAfterSkiing()
	for _, other in ipairs(otherGuisHiddenForSkiing) do
		if other.Parent then
			other.Enabled = true
		end
	end
	otherGuisHiddenForSkiing = {}
end

maxHealth = 0
currentHealth = 0
local TREE_HIT_DAMAGE = 80 -- health lost per tree collision

local function updateHealthUI()
	if not healthFill or not healthLabelUI then return end
	local pct = maxHealth > 0 and math.clamp(currentHealth / maxHealth, 0, 1) or 0
	healthFill.Size = UDim2.new(pct, 0, 1, 0)
	healthLabelUI.Text = math.max(0, math.floor(currentHealth)) .. " / " .. maxHealth
end

takeDamage = function(amount)
	if _G.TrickTutorialLocked then return end -- no health loss during the jump/grab tutorial
	if currentHealth <= 0 then return end -- already broken, don't re-trigger
	if player2 and player2:GetAttribute("Perk_Shield") then
		amount = amount * 0.7 -- Shield reduces damage taken by 30%
	end
	currentHealth = math.max(0, currentHealth - amount)
	updateHealthUI()
	if currentHealth <= 0 then
		wipeout() -- ski broke — treat like a wipeout
		if _G.SkiEndedSignal then _G.SkiEndedSignal:Fire() end -- direct, redundant with Humanoid.Died
		if humanoid then
			humanoid.Health = 0 -- actually kill the character so death/respawn flow triggers
		end
	end
end

local hasCrossedBarrier = false
local skiBarrier = workspace:FindFirstChild("SkiBarrier") or workspace:FindFirstChild("skiBarrier")
if skiBarrier then
	skiBarrier.Touched:Connect(function(hit)
		if hit:IsDescendantOf(character) then
			hasCrossedBarrier = true
		end
	end)
else
	-- No barrier placed — don't block skiing
	hasCrossedBarrier = true
end

local function enableSkiing()
	if isSkiing then return end
	if not hasCrossedBarrier then return end
	isSkiing = true; humanoid.WalkSpeed = 0; humanoid.AutoRotate = false
	stopAllAnims(); animateScript.Disabled = true
	leftFoot  = character:WaitForChild("LeftFoot")
	rightFoot = character:WaitForChild("RightFoot")
	applyDesignStats()

	-- Re-apply speed multipliers live when a perk is purchased mid-run
	local plr = game:GetService("Players").LocalPlayer
	if plr then
		plr:GetAttributeChangedSignal("Perk_SnowAura"):Connect(applyDesignStats)
		plr:GetAttributeChangedSignal("Perk_RainbowTrail"):Connect(applyDesignStats)
		plr:GetAttributeChangedSignal("Perk_RocketAura"):Connect(applyDesignStats)
	end

	leftSki,  leftSkiModel  = generateSki(leftFoot,  true)
	rightSki, rightSkiModel = generateSki(rightFoot, false)

	-- Initialize health from the equipped design and show the health UI
	maxHealth = (_G.SkiDesign and _G.SkiDesign.health) or 0
	currentHealth = maxHealth
	updateHealthUI()
	if drawButtonGui then drawButtonGui.Enabled = false end
	if healthGui then healthGui.Enabled = true end
	hideOtherGuisForSkiing()
	if _G.SkiStartedSignal then _G.SkiStartedSignal:Fire() end

	local function onTouch(hit)
		local CS = game:GetService("CollectionService")
		local isObstacle = CS:HasTag(hit, "SkiObstacle")
		-- Clearing an obstacle mid-jump shouldn't count as a crash: only collide-able
		-- obstacles you actually run into on the ground (or land on) stop you.
		if isObstacle and isInAir and hit.Name == "FallenLog" then return end
		local tree = hit.Parent and hit.Parent.Parent
		if not isObstacle then
			if hit.Name ~= "Trunk" then return end
			if not tree or tree.Parent ~= workspace.BunnyHillTrees then return end
			skiTreeHitEvent:FireServer(tree)
		end
		if not treeStunned then
			treeStunned = true; speed = 2; thud:Play()
			takeDamage(TREE_HIT_DAMAGE)
			task.delay(0.5, function() treeStunned = false end)
		end
	end
	leftSki.Touched:Connect(onTouch); rightSki.Touched:Connect(onTouch)
	skiIdleTrack:Play()
end

local function disableSkiing()
	if not isSkiing then return end
	isSkiing = false; speed = 0
	if drawButtonGui then drawButtonGui.Enabled = true end
	if healthGui then healthGui.Enabled = false end
	restoreOtherGuisAfterSkiing()
	if _G.SkiEndedSignal then _G.SkiEndedSignal:Fire() end
	currentTurnState = "none"; isHoldingTurn = false
	tricksThisJump = {}; airTrickState = "none"
	leftTurnTrack:Stop(); rightTurnTrack:Stop()
	holdLeftTurnTrack:Stop(); holdRightTurnTrack:Stop()
	returnFromLeftTrack:Stop(); returnFromRightTrack:Stop()
	skiIdleTrack:Stop(); stopAllTrickAnims()
	if leftSkiModel and leftSkiModel.Parent then leftSkiModel:Destroy() end
	if rightSkiModel and rightSkiModel.Parent then rightSkiModel:Destroy() end
	leftSkiModel = nil; rightSkiModel = nil
	leftSki, rightSki, leftFoot, rightFoot = nil, nil, nil, nil
	humanoid.WalkSpeed = WALK_SPEED; humanoid.AutoRotate = true
	animateScript.Disabled = false
end

treeHitEvent.OnClientEvent:Connect(function()
	if treeStunned then return end
	treeStunned = true; speed = 2
	task.delay(0.5, function() treeStunned = false end)
end)

local PASSIVE_DRAIN_PER_SECOND = 4 -- health lost per second while skiing on the ground

RunService.Heartbeat:Connect(function(dt)
	if isStunned then return end

	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {character}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(rootPart.Position, Vector3.new(0,-3.2,0), rp)

	wasInAir = isInAir; isInAir = (hit == nil)

	-- Passive health drain — only while actively skiing AND on the ground
	if isSkiing and not isInAir and currentHealth > 0 then
		takeDamage(PASSIVE_DRAIN_PER_SECOND * dt)
	end
	local prevAir = timeInAir
	if isInAir then timeInAir = timeInAir + dt else timeInAir = 0 end

	-- Just left the ground
	if not wasInAir and isInAir then
		hasDoubleJumped = false
		if isSkiing then
			local v = rootPart.AssemblyLinearVelocity
			local boost = LAUNCH_BOOST * (_G.SlowMoFactor or 1)
			if player:GetAttribute("Perk_AirBoost") then
				boost = boost + AIR_BOOST_BONUS
			end
			if os.clock() - (lastRampTime or 0) < 0.25 then
				boost = boost + RAMP_BOOST
			end
			rootPart.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + boost, v.Z)
		end
		skiIdleTrack:Stop(); leftTurnTrack:Stop(); rightTurnTrack:Stop()
		holdLeftTurnTrack:Stop(); holdRightTurnTrack:Stop()
		returnFromLeftTrack:Stop(); returnFromRightTrack:Stop()
		currentTurnState = "none"; isHoldingTurn = false
	end

	-- Just landed
	if wasInAir and not isInAir then
		if prevAir < MIN_WIPEOUT_AIRTIME then
			stopAllTrickAnims(); airTrickState = "none"; tricksThisJump = {}
		else
			checkLanding()
		end
	end

	if hit then
		-- GROUND
		local normal = hit.Normal
		local slopeAngle = math.deg(math.acos(math.clamp(normal.Y,-1,1)))
		if slopeAngle >= SLOPE_THRESHOLD or (isSkiing and speed >= COAST_SPEED_THRESHOLD) then
			enableSkiing(); currentNormal = normal
			local grav = Vector3.new(0,-1,0)
			local dh = grav - normal * grav:Dot(normal)
			local onRamp = hit.Instance and game:GetService("CollectionService"):HasTag(hit.Instance, "SkiRamp")
			if onRamp then lastRampTime = os.clock() end
			if dh.Magnitude > 0.01 and slopeAngle >= SLOPE_THRESHOLD and not onRamp then
				if speed < 1 then slideDir = dh.Unit end
				slideDir = slideDir:Lerp(dh.Unit, 0.08).Unit
				speed = math.min(speed + ACCELERATION * (_G.SlowMoFactor or 1) * dt, MAX_SPEED * (_G.SlowMoFactor or 1))
			end
			local steer = 0
			if _G.TrickTutorialLocked ~= "grab" then
				if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then steer = -1
				elseif UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer = 1 end
			end
			local dts = steer == -1 and "left" or steer == 1 and "right" or "none"
			if dts ~= currentTurnState and dts ~= "none" then
				skiIdleTrack:Stop(); returnFromLeftTrack:Stop(); returnFromRightTrack:Stop()
				holdLeftTurnTrack:Stop(); holdRightTurnTrack:Stop(); leftTurnTrack:Stop(); rightTurnTrack:Stop()
				if dts == "left" then leftTurnTrack:Play() else rightTurnTrack:Play() end
				turnStartTime = os.clock(); isHoldingTurn = false
			elseif dts == "none" and currentTurnState ~= "none" then
				if currentTurnState == "left" then
					leftTurnTrack:Stop(); holdLeftTurnTrack:Stop(); returnFromLeftTrack:Play()
					task.delay(0.3, function() if isSkiing and currentTurnState == "none" then skiIdleTrack:Play() end end)
				else
					rightTurnTrack:Stop(); holdRightTurnTrack:Stop(); returnFromRightTrack:Play()
					task.delay(0.3, function() if isSkiing and currentTurnState == "none" then skiIdleTrack:Play() end end)
				end
				isHoldingTurn = false
			elseif dts ~= "none" and dts == currentTurnState then
				if not isHoldingTurn and (os.clock() - turnStartTime) >= TURN_HOLD_THRESHOLD then
					isHoldingTurn = true
					if dts == "left" then leftTurnTrack:Stop(); holdLeftTurnTrack:Play()
					else rightTurnTrack:Stop(); holdRightTurnTrack:Play() end
				end
			end
			currentTurnState = dts
			if steer ~= 0 then
				local a = math.rad(TURN_SPEED * (_G.SlowMoFactor or 1) * dt * steer)
				local c, s2 = math.cos(a), math.sin(a)
				slideDir = Vector3.new(slideDir.X*c - slideDir.Z*s2, slideDir.Y, slideDir.X*s2 + slideDir.Z*c).Unit
			end
			speed = speed * FRICTION
			-- Use full slope direction including Y so steep terrain is followed smoothly
		if not _G.TrickTutorialLocked then
			if onRamp then
				local flatDir = Vector3.new(slideDir.X, 0, slideDir.Z)
				if flatDir.Magnitude > 0.01 then
					local upDir = (flatDir.Unit - normal * flatDir.Unit:Dot(normal)).Unit
					rootPart.AssemblyLinearVelocity = upDir * math.max(speed, 60)
				end
			else
				local v = slideDir * speed
				local st = humanoid:GetState()
				if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then
					-- don't cancel a jump that's just leaving the ground
					v = Vector3.new(v.X, math.max(v.Y, rootPart.AssemblyLinearVelocity.Y), v.Z)
				end
				rootPart.AssemblyLinearVelocity = v
			end
		end
			local flat = Vector3.new(slideDir.X, 0, slideDir.Z)
			if flat.Magnitude > 0 then
				local cl2 = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
				if cl2.Magnitude > 0.01 then
					rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + cl2.Unit:Lerp(flat.Unit, 0.12).Unit)
				end
			end
			if isSkiing and leftSki and rightSki and leftFoot and rightFoot then
				local su = currentNormal
				local fw = Vector3.new(slideDir.X, 0, slideDir.Z)
				if fw.Magnitude > 0.01 then
					fw = fw.Unit
					local r = fw:Cross(su)
					if r.Magnitude > 0.01 then
						r = r.Unit
						local af = su:Cross(r).Unit
						leftSki.CFrame  = CFrame.fromMatrix(leftFoot.Position  + Vector3.new(0,-0.15,0), r, su, -af)
						rightSki.CFrame = CFrame.fromMatrix(rightFoot.Position + Vector3.new(0,-0.15,0), r, su, -af)
					end
				end
			end
		else
			disableSkiing()
		end
	else
		-- AIR
		if isSkiing then
			local cy = rootPart.AssemblyLinearVelocity.Y
			-- Apply gentle upward force for hang time
			rootPart.AssemblyLinearVelocity = Vector3.new(slideDir.X*speed, cy + HANG_FORCE*dt, slideDir.Z*speed)
		end
		if isSkiing and leftSki and rightSki and leftFoot and rightFoot then
			leftSki.CFrame  = leftFoot.CFrame  * CFrame.new(0,-0.15,0)
			rightSki.CFrame = rightFoot.CFrame * CFrame.new(0,-0.15,0)
		end
		if not isSkiing then return end
		local si = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then si = -1
		elseif UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then si = 1 end
		local fi = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then fi = 1
		elseif UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then fi = -1 end
		local gk = UserInputService:IsKeyDown(Enum.KeyCode.G) or grabButtonHeld
		local dt2 = "none"
		if _G.TrickTutorialLocked == "grab" then
			-- Tutorial is waiting specifically for a grab — block every other trick input
			if gk then dt2 = "grab" end
		else
			if si == -1 and fi == 1 then dt2 = "leftMisty"
			elseif si == 1 and fi == 1 then dt2 = "rightMisty"
			elseif si == -1 and fi == -1 then dt2 = "leftBackCombo"
			elseif si == 1 and fi == -1 then dt2 = "rightBackCombo"
			elseif fi == 1 then dt2 = "frontFlip"
			elseif fi == -1 then dt2 = "backFlip"
			elseif si == -1 then dt2 = "spinLeft"
			elseif si == 1 then dt2 = "spinRight"
			elseif gk then dt2 = "grab" end
		end
		if dt2 ~= airTrickState then
			stopAllTrickAnims()
			local last = tricksThisJump[#tricksThisJump]
			if last and not last.endTime then last.endTime = os.clock() end
			if dt2 == "grab" then grabTrack:AdjustSpeed(1); grabTrack:Play()
			elseif dt2 == "frontFlip" then frontFlipTrack:Play()
			elseif dt2 == "backFlip" then backFlipTrack:Play()
			elseif dt2 == "spinLeft" then spinLeftTrack:Play()
			elseif dt2 == "spinRight" then spinRightTrack:Play()
			elseif dt2 == "leftMisty" then leftMistyTrack:Play()
			elseif dt2 == "rightMisty" then rightMistyTrack:Play()
			elseif dt2 == "leftBackCombo" then leftBackComboTrack:Play()
			elseif dt2 == "rightBackCombo" then rightBackComboTrack:Play() end
			if dt2 ~= "none" then
				table.insert(tricksThisJump, {name=dt2, startTime=os.clock()})
			end
			airTrickState = dt2
		end
		if airTrickState == "grab" then
			if gk then
				if grabTrack.TimePosition >= grabTrack.Length - 0.03 then grabTrack:AdjustSpeed(0) end
			else grabTrack:AdjustSpeed(1); grabTrack:Stop(); airTrickState = "none" end
		end
		grabHeld = gk
		_G.IsGrabbing = gk
	end
	_G.IsInAir = isInAir
end)
-------------------------------------------------------------------
-- DOUBLE JUMP (Space bar) — one extra upward boost per airtime
-------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.Space then return end
	if not player:GetAttribute("Perk_DoubleJump") then return end
	if not isInAir then return end
	if hasDoubleJumped then return end
	if not rootPart then return end

	hasDoubleJumped = true
	local v = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(v.X, DOUBLE_JUMP_BOOST, v.Z)
end)
-------------------------------------------------------------------
-- ROCKET BOOST (Shift) — forward speed burst with fire/smoke trail
-------------------------------------------------------------------
local function createRocketBoostBurst()
	if not rootPart then return end
	local fireSource = workspace:FindFirstChild("SourceAssets") and workspace.SourceAssets:FindFirstChild("Realistic Fire")
	if not fireSource then return end

	local attachment = Instance.new("Attachment")
	attachment.Name = "RocketBoostBurst"
	attachment.Position = Vector3.new(0, -1, 1.5) -- behind the player, roughly waist height
	attachment.Parent = rootPart

	for _, child in ipairs(fireSource:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			local clone = child:Clone()
			clone.Rate = clone.Rate * 2.5 -- big burst, stronger than the ambient rocket aura
			clone.Speed = NumberRange.new(8, 14)
			clone.Enabled = true -- source is disabled so it doesn't render at its own location
			clone.Parent = attachment
		elseif child:IsA("Smoke") then
			local clone = child:Clone()
			clone.Opacity = math.min(1, clone.Opacity * 1.5)
			clone.RiseVelocity = 0
			clone.Enabled = true
			clone.Parent = attachment
		elseif child:IsA("PointLight") then
			local clone = child:Clone()
			clone.Range = clone.Range * 1.5
			clone.Brightness = clone.Brightness * 2
			clone.Parent = attachment
		end
		-- Sound skipped, same as rocket aura
	end

	-- Burst lasts briefly, then cleans itself up
	task.delay(0.6, function()
		for _, child in ipairs(attachment:GetChildren()) do
			if child:IsA("ParticleEmitter") or child:IsA("Smoke") then
				child.Enabled = false
			end
		end
		task.delay(1.5, function()
			attachment:Destroy()
		end)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.LeftShift and input.KeyCode ~= Enum.KeyCode.RightShift then return end
	if not player:GetAttribute("Perk_RocketBoost") then return end
	if not rocketBoostReady then return end
	if not rootPart then return end
	if not isSkiing then return end

	rocketBoostReady = false

	local v = rootPart.AssemblyLinearVelocity
	local boostVelocity = slideDir * ROCKET_BOOST_FORCE
	rootPart.AssemblyLinearVelocity = Vector3.new(v.X + boostVelocity.X, v.Y, v.Z + boostVelocity.Z)

	createRocketBoostBurst()

	task.delay(ROCKET_BOOST_COOLDOWN, function()
		rocketBoostReady = true
	end)
end)