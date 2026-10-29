-- SkiPrompt — shared ski-themed tutorial prompt
-- Usage: local p = SkiPrompt.new(screenGui, {position = UDim2, height = 78, small = false, plain = false, seed = 7})
--        p:show("Text")  /  p:hide()
--   height -> every part of the sign (text, border, snow, icicles, emblems) scales from this
--   small  -> compact sign: lighter snow, no icicles
--   plain  -> no sign at all, just outlined text (for secondary lines)
-- The sign's width is measured from its text on every show, so it always fits snugly.
local TweenService = game:GetService("TweenService")
local TextService  = game:GetService("TextService")

local SkiPrompt = {}
SkiPrompt.__index = SkiPrompt

local FONT        = Enum.Font.LuckiestGuy
local ICE_LIGHT   = Color3.fromRGB(215, 240, 255)
local ICE         = Color3.fromRGB(178, 224, 255)
local ICE_DEEP    = Color3.fromRGB(108, 178, 238)
local SNOW        = Color3.fromRGB(252, 254, 255)
local SNOW_SHADE  = Color3.fromRGB(206, 226, 246)
local SNOW_SHADOW = Color3.fromRGB(150, 188, 226)
local DEEP        = Color3.fromRGB(12, 40, 92)
-- Snow cap texture (cropped to the snow itself; the source image has transparent padding)
local SNOW_TEX         = "rbxassetid://95940216636821"
local SNOW_RECT_OFFSET = Vector2.new(80, 0)
local SNOW_RECT_SIZE   = Vector2.new(863, 160)
local SNOW_ASPECT      = 863 / 160
local SNOW_EDGE        = 38 / 160 -- portion of the texture that sits ABOVE the sign's top edge (smaller = snow sits lower)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

local function shadedSnow(frame, bottomColor)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, SNOW),
		ColorSequenceKeypoint.new(0.45, SNOW),
		ColorSequenceKeypoint.new(1, bottomColor or SNOW_SHADE),
	})
	g.Parent = frame
end

function SkiPrompt.new(parent, opts)
	opts = opts or {}
	local self = setmetatable({}, SkiPrompt)
	local H = opts.height or 78
	self.H = H
	self.compact = opts.small == true
	self.plain = opts.plain == true
	self.seed = opts.seed or 7
	self.basePosition = opts.position or UDim2.new(0.5, 0, 0.3, 0)
	self.swayAmount = self.plain and 0.6 or 1.1
	self.radius = math.floor(H * 0.32)
	self.emblemSize = math.floor(H * 0.46)
	self.pad = math.floor(H * 0.26)
	self.baseFades = {}
	self.decorFades = {}
	self.decor = {}
	self.flakes = {}
	self.emblems = {}
	self.sparkles = {}
	self.drips = {}
	self.token = 0
	self.lastW = nil

	local function track(inst, prop, shown)
		table.insert(self.baseFades, {inst, prop, shown})
		inst[prop] = 1
	end

	local root = Instance.new("Frame")
	root.Name = "SkiPrompt"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = self.basePosition
	root.Size = UDim2.new(0, H * 4, 0, H)
	root.BackgroundTransparency = 1
	root.Visible = false
	root.ZIndex = 10
	root.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = root
	self.scale = scale
	self.root = root

	local textParent = root
	if not self.plain then
		local shadow = Instance.new("Frame")
		shadow.Size = UDim2.new(1, 0, 1, 0)
		shadow.Position = UDim2.new(0, 0, 0, math.floor(H * 0.09))
		shadow.BackgroundColor3 = Color3.fromRGB(5, 20, 50)
		shadow.BorderSizePixel = 0
		shadow.ZIndex = 10
		shadow.Parent = root
		corner(shadow, UDim.new(0, self.radius))
		track(shadow, "BackgroundTransparency", 0.68)

		local sign = Instance.new("Frame")
		sign.Name = "Sign"
		sign.Size = UDim2.new(1, 0, 1, 0)
		sign.BackgroundColor3 = Color3.new(1, 1, 1)
		sign.BorderSizePixel = 0
		sign.ZIndex = 11
		sign.Parent = root
		corner(sign, UDim.new(0, self.radius))
		track(sign, "BackgroundTransparency", 0.03)
		local bgGrad = Instance.new("UIGradient")
		bgGrad.Rotation = 90
		bgGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(92, 172, 245)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(48, 118, 210)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 60, 132)),
		})
		bgGrad.Parent = sign
		local border = Instance.new("UIStroke")
		border.Color = ICE_LIGHT
		border.Thickness = math.max(2, H * 0.045)
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Parent = sign
		track(border, "Transparency", 0)
		self.sign = sign

		local gloss = Instance.new("Frame")
		gloss.AnchorPoint = Vector2.new(0.5, 0)
		gloss.Position = UDim2.new(0.5, 0, 0, math.floor(H * 0.12))
		gloss.Size = UDim2.new(1, -math.floor(H * 0.18), 0.4, 0)
		gloss.BackgroundColor3 = Color3.new(1, 1, 1)
		gloss.BorderSizePixel = 0
		gloss.ZIndex = 12
		gloss.Parent = sign
		corner(gloss, UDim.new(0, math.floor(self.radius * 0.8)))
		local glossGrad = Instance.new("UIGradient")
		glossGrad.Rotation = 90
		glossGrad.Transparency = NumberSequence.new(0.2, 1)
		glossGrad.Parent = gloss
		track(gloss, "BackgroundTransparency", 0.74)

		local clip = Instance.new("Frame")
		clip.AnchorPoint = Vector2.new(0.5, 0.5)
		clip.Position = UDim2.new(0.5, 0, 0.5, 0)
		clip.Size = UDim2.new(1, -math.floor(self.radius * 0.6), 1, -4)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.ZIndex = 13
		clip.Parent = sign
		local rng = Random.new(self.seed + 99)
		for _ = 1, (self.compact and 8 or 14) do
			local flake = Instance.new("Frame")
			local sz = math.max(2, math.floor(H * rng:NextNumber(0.04, 0.065)))
			flake.Size = UDim2.new(0, sz, 0, sz)
			flake.AnchorPoint = Vector2.new(0.5, 0.5)
			flake.Position = UDim2.new(rng:NextNumber(), 0, rng:NextNumber(), 0)
			flake.BackgroundColor3 = SNOW
			flake.BorderSizePixel = 0
			flake.ZIndex = 13
			flake.Parent = clip
			corner(flake, UDim.new(1, 0))
			track(flake, "BackgroundTransparency", 0.35)
			table.insert(self.flakes, flake)
		end

		for _, side in ipairs({-1, 1}) do
			local emblem = Instance.new("TextLabel")
			emblem.AnchorPoint = Vector2.new(0.5, 0.5)
			emblem.Size = UDim2.new(0, self.emblemSize, 0, self.emblemSize)
			local edge = self.pad + self.emblemSize / 2
			emblem.Position = side == -1 and UDim2.new(0, edge, 0.54, 0) or UDim2.new(1, -edge, 0.54, 0)
			emblem.BackgroundTransparency = 1
			emblem.Font = Enum.Font.GothamBold
			emblem.Text = "\u{2744}"
			emblem.TextScaled = true
			emblem.TextColor3 = ICE_LIGHT
			emblem.ZIndex = 29
			emblem.Parent = sign
			track(emblem, "TextTransparency", 0)
			table.insert(self.emblems, emblem)
		end

		textParent = sign
	end

	if self.plain then
		local tshadow = Instance.new("TextLabel")
		tshadow.AnchorPoint = Vector2.new(0.5, 0.5)
		tshadow.Position = UDim2.new(0.5, math.max(2, math.floor(H * 0.05)), 0.5, math.max(2, math.floor(H * 0.07)))
		tshadow.Size = UDim2.new(1, 0, 1, 0)
		tshadow.BackgroundTransparency = 1
		tshadow.Font = FONT
		tshadow.TextColor3 = Color3.fromRGB(5, 20, 50)
		tshadow.Text = ""
		tshadow.ZIndex = 13
		tshadow.Parent = root
		track(tshadow, "TextTransparency", 0.55)
		self.textShadow = tshadow
	end

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, self.plain and 0.52 or 0.56, 0)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.ZIndex = 30
	label.Parent = textParent
	track(label, "TextTransparency", 0)
	local textGrad = Instance.new("UIGradient")
	textGrad.Rotation = 90
	textGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(188, 228, 255))
	textGrad.Parent = label
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = DEEP
	textStroke.Thickness = math.max(1.5, H * (self.plain and 0.06 or 0.042))
	textStroke.Parent = label
	track(textStroke, "Transparency", 0)
	self.label = label

	return self
end

function SkiPrompt:_layout(text)
	local H = self.H
	local textSize = math.floor(H * (self.plain and 0.62 or 0.44))
	local side = self.plain and math.floor(H * 0.3) or (self.pad * 2 + self.emblemSize)
	local function measure(sz)
		return TextService:GetTextSize(text, sz, FONT, Vector2.new(5000, 1000)).X
	end
	local tw = measure(textSize)
	local cam = workspace.CurrentCamera
	local maxW = (cam and cam.ViewportSize.X or 1280) * 0.9
	if tw + side * 2 > maxW then
		textSize = math.max(10, math.floor(textSize * (maxW - side * 2) / tw))
		tw = measure(textSize)
	end
	local W = math.floor(math.max(tw + side * 2, H * 3.2))

	self.label.TextSize = textSize
	if self.textShadow then self.textShadow.TextSize = textSize end
	self.root.Size = UDim2.new(0, W, 0, H)
	if W ~= self.lastW then
		self.lastW = W
		self:_buildDecor(W)
	end
end

function SkiPrompt:_buildDecor(W)
	for _, inst in ipairs(self.decor) do inst:Destroy() end
	self.decor = {}
	self.decorFades = {}
	self.sparkles = {}
	self.drips = {}
	if self.plain then return end

	local H, R = self.H, self.radius
	local sign = self.sign
	local rng = Random.new(self.seed)
	local cap = self.compact and 0.7 or 1

	local function own(inst)
		table.insert(self.decor, inst)
		return inst
	end
	local function track(inst, prop, shown)
		table.insert(self.decorFades, {inst, prop, shown})
		inst[prop] = 1
	end
	local function frame(props)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		for k, v in pairs(props) do f[k] = v end
		return f
	end

	-- How far the sign's rounded top edge has dropped at a given x
	local function surfaceDrop(px)
		local d = math.min(px, W - px)
		if d >= R then return 0 end
		local dx = R - d
		return R - math.sqrt(math.max(0, R * R - dx * dx))
	end
	local function edgeFactor(px)
		return math.clamp(math.min(px, W - px) / (R * 1.8), 0.35, 1)
	end

	---------------------------------------------------------------
	-- TOP: snow cap texture laid across the sign. Rather than stretching one copy
	-- (which would distort it on wide signs), overlapping copies are tiled across the
	-- width, each kept close to its natural proportions, with slightly varied height and
	-- overlap so the repetition isn't noticeable. It sits behind the text/emblems so the
	-- drips can hang over the front without ever covering a letter.
	---------------------------------------------------------------
	-- One continuous drape image (1024x150). Its top edge region sits just above the
	-- sign, it's ~4% wider than the sign so the curled ends wrap over the corners,
	-- and it sits behind the text so drips never cover letters.
	local DRAPE = "rbxassetid://71191460827662"
	local capH = math.floor(H * (self.compact and 0.85 or 1.1))
	local img = Instance.new("ImageLabel")
	img.Name = "SnowDrape"
	img.BackgroundTransparency = 1
	img.Image = DRAPE
	img.ScaleType = Enum.ScaleType.Stretch
	local extra = math.floor(W * 0.008) + 2
	img.Size = UDim2.new(0, W + extra * 2, 0, capH)
	img.Position = UDim2.new(0, -extra, 0, -math.floor(capH * 0.36))
	img.ZIndex = 15
	img.Parent = sign
	own(img)
	track(img, "ImageTransparency", 0)

	if self.compact then return end

	---------------------------------------------------------------
	-- BOTTOM: frozen rim with naturally clustered icicles
	---------------------------------------------------------------
	local rimThick = math.max(3, math.floor(H * 0.06))
	local rim = own(frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, -math.floor(R * 1.1), 0, rimThick),
		BackgroundColor3 = ICE,
		ZIndex = 13,
		Parent = sign,
	}))
	corner(rim, UDim.new(1, 0))
	track(rim, "BackgroundTransparency", 0.04)

	-- Frozen beads along the rim at uneven spacing
	local bx = R * 0.7 + rng:NextNumber(0, H * 0.3)
	while bx < W - R * 0.7 do
		local bw = math.floor(H * rng:NextNumber(0.07, 0.15))
		local bead = own(frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, bx, 1, math.floor(rimThick * 0.2)),
			Size = UDim2.new(0, bw, 0, math.floor(bw * rng:NextNumber(0.55, 0.8))),
			BackgroundColor3 = ICE,
			ZIndex = 13,
			Parent = sign,
		}))
		corner(bead, UDim.new(1, 0))
		track(bead, "BackgroundTransparency", 0.15)
		bx += H * rng:NextNumber(0.25, 0.7)
	end

	local function icicle(px, len, wid, tilt)
		local holder = own(frame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0, px, 1, -math.floor(rimThick * 0.3)),
			Size = UDim2.new(0, wid, 0, len),
			BackgroundTransparency = 1,
			Rotation = tilt,
			ZIndex = 12,
			Parent = sign,
		}))
		-- Four segments narrowing smoothly to a point
		local segs = {{1.0, 0.34}, {0.74, 0.27}, {0.48, 0.22}, {0.22, 0.17}}
		local y = 0
		for si, seg in ipairs(segs) do
			local sh = math.max(2, math.floor(len * seg[2]))
			local part = frame({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, y),
				Size = UDim2.new(0, math.max(2, math.floor(wid * seg[1])), 0, sh + 2),
				BackgroundColor3 = si == 1 and ICE or ICE:Lerp(ICE_DEEP, (si - 1) / 4),
				ZIndex = 12,
				Parent = holder,
			})
			corner(part, UDim.new(1, 0))
			track(part, "BackgroundTransparency", (si - 1) * 0.05)
			y += sh
		end
		-- Glassy highlight down the left side
		if wid >= 5 then
			local hl = frame({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, -math.floor(wid * 0.2), 0, math.floor(len * 0.05)),
				Size = UDim2.new(0, math.max(1, math.floor(wid * 0.2)), 0, math.floor(len * 0.5)),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 13,
				Parent = holder,
			})
			corner(hl, UDim.new(1, 0))
			track(hl, "BackgroundTransparency", 0.15)
		end
		return y
	end

	-- Pick cluster centres with uneven spacing (rejection sampling keeps them apart)
	local usableL, usableR = R * 1.0, W - R * 1.0
	local clusterCount = math.max(2, math.floor(W / (H * 1.7)))
	local centres = {}
	for _ = 1, clusterCount * 6 do
		if #centres >= clusterCount then break end
		local c = rng:NextNumber(usableL, usableR)
		local ok = true
		for _, other in ipairs(centres) do
			if math.abs(other - c) < H * 0.9 then ok = false break end
		end
		if ok then table.insert(centres, c) end
	end

	local longest = {}
	for _, c in ipairs(centres) do
		-- One dominant icicle, flanked by a few shorter ones of differing sizes
		local mainLen = H * rng:NextNumber(0.26, 0.44)
		local mainWid = math.floor(H * rng:NextNumber(0.14, 0.19))
		local tipY = icicle(c, mainLen, mainWid, rng:NextNumber(-3, 3))
		table.insert(longest, {px = c, tip = tipY, len = mainLen})
		for _ = 1, rng:NextInteger(1, 3) do
			local dir = rng:NextNumber() < 0.5 and -1 or 1
			local off = H * rng:NextNumber(0.1, 0.24) * dir
			local px = math.clamp(c + off, usableL, usableR)
			icicle(px, mainLen * rng:NextNumber(0.25, 0.6), math.floor(mainWid * rng:NextNumber(0.5, 0.8)), rng:NextNumber(-5, 5))
		end
	end

	-- A few stray tiny icicles for texture
	for _ = 1, math.max(2, math.floor(W / (H * 1.3))) do
		local px = rng:NextNumber(usableL, usableR)
		icicle(px, H * rng:NextNumber(0.07, 0.14), math.max(4, math.floor(H * rng:NextNumber(0.07, 0.1))), rng:NextNumber(-6, 6))
	end

	-- The longest one or two icicles get occasional dripping water
	table.sort(longest, function(a, b) return a.len > b.len end)
	for i = 1, math.min(2, #longest) do
		local spot = longest[i]
		local d = math.max(4, math.floor(H * 0.07))
		local drop = own(frame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0, spot.px, 1, spot.tip - math.floor(rimThick * 0.3) - 2),
			Size = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(220, 244, 255),
			BackgroundTransparency = 0.1,
			ZIndex = 12,
			Parent = sign,
		}))
		corner(drop, UDim.new(1, 0))
		table.insert(self.drips, {frame = drop, size = d, start = drop.Position})
	end
end

function SkiPrompt:_fadeTo(info, hidden)
	for _, list in ipairs({self.baseFades, self.decorFades}) do
		for _, f in ipairs(list) do
			TweenService:Create(f[1], info, {[f[2]] = hidden and 1 or f[3]}):Play()
		end
	end
end

function SkiPrompt:show(text)
	self.token += 1
	local token = self.token
	local root = self.root
	self.label.Text = text
	if self.textShadow then self.textShadow.Text = text end
	self:_layout(text)

	root.Visible = true
	root.Position = self.basePosition + UDim2.new(0, 0, 0, -math.floor(self.H * 0.4))
	root.Rotation = -3
	self.scale.Scale = 0.75
	local popInfo = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(self.scale, popInfo, {Scale = 1}):Play()
	TweenService:Create(root, popInfo, {Position = self.basePosition, Rotation = 0}):Play()
	self:_fadeTo(TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), false)

	local amount = self.swayAmount
	task.delay(0.55, function()
		local swayInfo = TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		while self.token == token do
			TweenService:Create(root, swayInfo, {Rotation = amount}):Play()
			task.wait(1.8)
			if self.token ~= token then break end
			TweenService:Create(root, swayInfo, {Rotation = -amount}):Play()
			task.wait(1.8)
		end
	end)

	for _, flake in ipairs(self.flakes) do
		task.spawn(function()
			task.wait(math.random() * 1.2)
			while self.token == token do
				local x = math.random()
				flake.Position = UDim2.new(x, 0, 0, -6)
				local dur = 1.8 + math.random() * 1.6
				TweenService:Create(flake, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
					Position = UDim2.new(x + (math.random() - 0.5) * 0.08, 0, 1, 6),
				}):Play()
				task.wait(dur)
			end
		end)
	end

	for i, emblem in ipairs(self.emblems) do
		task.spawn(function()
			local dir = (i == 1) and 1 or -1
			while self.token == token do
				emblem.Rotation = 0
				TweenService:Create(emblem, TweenInfo.new(7, Enum.EasingStyle.Linear), {Rotation = 360 * dir}):Play()
				task.wait(7)
			end
		end)
	end

	-- Ice glitter: each sparkle twinkles on its own random rhythm
	for _, sScale in ipairs(self.sparkles) do
		task.spawn(function()
			task.wait(0.6 + math.random() * 2)
			while self.token == token do
				local spark = sScale.Parent
				if not spark then break end
				spark.Rotation = 0
				TweenService:Create(sScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
				TweenService:Create(spark, TweenInfo.new(0.45, Enum.EasingStyle.Linear), {Rotation = 45}):Play()
				task.wait(0.2)
				TweenService:Create(sScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0}):Play()
				task.wait(1.5 + math.random() * 3)
			end
			sScale.Scale = 0
		end)
	end

	-- Water drips forming at icicle tips and falling
	for _, drip in ipairs(self.drips) do
		task.spawn(function()
			task.wait(1 + math.random() * 2.5)
			while self.token == token do
				local f = drip.frame
				if not f.Parent then break end
				f.Position = drip.start
				f.Size = UDim2.new(0, 0, 0, 0)
				f.BackgroundTransparency = 0.1
				TweenService:Create(f, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, drip.size, 0, math.floor(drip.size * 1.25)),
				}):Play()
				task.wait(1)
				if self.token ~= token then break end
				TweenService:Create(f, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = drip.start + UDim2.new(0, 0, 0, math.floor(self.H * 0.7)),
					BackgroundTransparency = 1,
				}):Play()
				task.wait(0.5 + 2 + math.random() * 3.5)
			end
			drip.frame.Size = UDim2.new(0, 0, 0, 0)
		end)
	end
end

function SkiPrompt:hide()
	self.token += 1
	local token = self.token
	local root = self.root
	if not root.Visible then return end
	local outInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(self.scale, outInfo, {Scale = 0.85}):Play()
	TweenService:Create(root, outInfo, {Position = self.basePosition + UDim2.new(0, 0, 0, -math.floor(self.H * 0.25)), Rotation = 0}):Play()
	self:_fadeTo(outInfo, true)
	task.delay(0.27, function()
		if self.token == token then
			root.Visible = false
		end
	end)
end

return SkiPrompt
