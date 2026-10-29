-- SkiEffects LocalScript
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart  = character:WaitForChild("HumanoidRootPart")
local camera    = workspace.CurrentCamera

local FOV_DEFAULT      = 70;  local FOV_MAX         = 120
local FOV_SPEED_START  = 20;  local FOV_SPEED_FULL  = 100
local LINE_SPEED_START = 30;  local LINE_SPEED_FULL = 90
local SNOW_START       = 5;   local SNOW_FULL       = 50
local LINE_POOL        = 180

-- Scale speed-effect thresholds based on owned perks so high speeds still feel intense
local player = game:GetService("Players").LocalPlayer
local function getSpeedMult()
    local mult = 1
    if player:GetAttribute("Perk_SnowAura")     then mult = mult * 1.5 end
    if player:GetAttribute("Perk_RainbowTrail") then mult = mult * 10  end
    if player:GetAttribute("Perk_RocketAura")   then mult = mult * 15  end
    return mult
end

local function remap(v,a,b,c,d)
    return c + math.clamp((v-a)/(b-a),0,1)*(d-c)
end

local speedGui = Instance.new("ScreenGui")
speedGui.Name = "SpeedLineGui"; speedGui.ResetOnSpawn = false
speedGui.IgnoreGuiInset = true; speedGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
speedGui.Parent = player.PlayerGui

local linePool = {}
for i = 1, LINE_POOL do
    local f = Instance.new("Frame")
    f.BackgroundColor3       = Color3.fromRGB(255, 255, 255)
    f.BorderSizePixel        = 0
    f.BackgroundTransparency = 1
    f.AnchorPoint            = Vector2.new(0.5, 0)
    f.ZIndex                 = 5
    f.Parent                 = speedGui
    local grad = Instance.new("UIGradient")
    grad.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,   1.0),
        NumberSequenceKeypoint.new(0.3, 0.35),
        NumberSequenceKeypoint.new(0.7, 0.0),
        NumberSequenceKeypoint.new(1,   0.15),
    }
    grad.Rotation = 90
    grad.Parent   = f
    table.insert(linePool, {f=f, active=false, growTween=nil, fadeTween=nil})
end

local lineTimer    = 0
local lineInterval = 0.05

local function spawnLine(data, intensity)
    if data.active then return end
    data.active = true
    local f  = data.f
    local vp = camera.ViewportSize
    local cx, cy = vp.X*0.5, vp.Y*0.5
    local diag = math.sqrt(vp.X^2 + vp.Y^2) * 0.5

    local angle  = math.random() * 360
    local rad    = math.rad(angle)

    -- Line length (bigger than before)
    local lineLen  = remap(math.random(),0,1,0.14,0.30) * diag

    -- Spike: starts 2-3px wide (pointed tip), grows to baseWidth (thick base)
    local baseWidth = remap(intensity,0,1,18,42) * (0.6+math.random()*0.8)

    -- Position: start near edge, slide to corner
    local startR = remap(math.random(),0,1,0.70,0.84) * diag
    local endR   = startR + diag * remap(intensity,0,1,0.08,0.18)

    local sx = cx + math.cos(rad)*startR
    local sy = cy + math.sin(rad)*startR
    local ex = cx + math.cos(rad)*endR
    local ey = cy + math.sin(rad)*endR

    -- Correct rotation using atan2
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position    = UDim2.new(0, sx, 0, sy)
    f.Rotation    = math.deg(math.atan2(math.cos(rad), -math.sin(rad)))

    -- Start as a thin needle (pointed tip)
    f.Size               = UDim2.new(0, 1, 0, lineLen)
    f.BackgroundTransparency = 0.05

    if data.growTween then data.growTween:Cancel() end
    if data.fadeTween then data.fadeTween:Cancel() end

    -- Tween: slide outward AND widen into spike shape, then fade
    local slideTime = remap(intensity, 0, 1, 0.20, 0.07)
    data.fadeTween = TweenService:Create(f,
        TweenInfo.new(slideTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {
            Position             = UDim2.new(0, ex, 0, ey),
            Size                 = UDim2.new(0, baseWidth, 0, lineLen),
            BackgroundTransparency = 1,
        }
    )
    data.fadeTween:Play()
    data.fadeTween.Completed:Connect(function()
        -- Reset width for next use
        f.Size = UDim2.new(0, 1, 0, lineLen)
        data.active = false
    end)
end

local activeSnowEmitters = {}
local function makeEmitter(parent, heavy)
    local att = Instance.new("Attachment")
    att.Position = Vector3.new(0, heavy and 0 or 0.1, heavy and 0.2 or 0.1)
    att.Parent = parent
    local e = Instance.new("ParticleEmitter")
    e.Texture = "rbxassetid://933102662"
    e.LightEmission = heavy and 0.2 or 0.5; e.LightInfluence = heavy and 0.9 or 0.6
    e.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(240,248,255));
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,255));
    }
    e.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0); NumberSequenceKeypoint.new(0.4,0.3); NumberSequenceKeypoint.new(1,1);
    }
    e.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, heavy and 1.5 or 0.3);
        NumberSequenceKeypoint.new(0.5, heavy and 2.5 or 0.8);
        NumberSequenceKeypoint.new(1, 0.2);
    }
    e.Lifetime = NumberRange.new(heavy and 0.3 or 0.5, heavy and 0.7 or 1.0)
    e.Rate = 0; e.Speed = NumberRange.new(heavy and 20 or 8, heavy and 45 or 25)
    e.SpreadAngle = Vector2.new(heavy and 60 or 80, heavy and 35 or 50)
    e.RotSpeed = NumberRange.new(-200,200); e.Rotation = NumberRange.new(0,360)
    e.EmissionDirection = Enum.NormalId.Back; e.Parent = att
    return e
end

local function attachSnow(skiModel)
    local L = skiModel:FindFirstChild("LeftBlueSki")
    local R = skiModel:FindFirstChild("RightBlueSki")
    if L and R then
        for _, ski in ipairs({L,R}) do
            table.insert(activeSnowEmitters, makeEmitter(ski,true))
            table.insert(activeSnowEmitters, makeEmitter(ski,false))
        end
    end
end
local function clearSnow()
    for _,e in pairs(activeSnowEmitters) do
        if e and e.Parent then e.Parent:Destroy() end
    end
    activeSnowEmitters = {}
end

character.ChildAdded:Connect(function(c)
    if c:FindFirstChild("LeftBlueSki") then task.defer(function() attachSnow(c) end) end
end)
character.ChildRemoved:Connect(function(c)
    if c:FindFirstChild("LeftBlueSki") then clearSnow() end
end)

local currentFov = FOV_DEFAULT
RunService.Heartbeat:Connect(function(dt)
    local vel        = rootPart.AssemblyLinearVelocity
    local rawSpeed   = Vector3.new(vel.X,0,vel.Z).Magnitude
    local horizSpeed = rawSpeed / math.sqrt(getSpeedMult())  -- partial normalize: effects still intensify with perks, but don't fully max out instantly
    local onGround   = math.abs(vel.Y) < 8
    local steer      = UserInputService:IsKeyDown(Enum.KeyCode.A)
                    or UserInputService:IsKeyDown(Enum.KeyCode.Left)
                    or UserInputService:IsKeyDown(Enum.KeyCode.D)
                    or UserInputService:IsKeyDown(Enum.KeyCode.Right)

    local targetFov = remap(horizSpeed, FOV_SPEED_START, FOV_SPEED_FULL, FOV_DEFAULT, FOV_MAX)
    currentFov = currentFov + (targetFov - currentFov) * math.min(1, dt*4)
    camera.FieldOfView = currentFov

    local intensity = remap(horizSpeed, LINE_SPEED_START, LINE_SPEED_FULL, 0, 1)
    if intensity > 0 then
        lineTimer    = lineTimer + dt
        lineInterval = remap(intensity, 0, 1, 0.005, 0.0013)
        while lineTimer >= lineInterval do
            lineTimer = lineTimer - lineInterval
            local inactive = {}
            for _,l in ipairs(linePool) do
                if not l.active then table.insert(inactive, l) end
            end
            if #inactive > 0 then
                spawnLine(inactive[math.random(#inactive)], intensity)
            end
        end
    end

    local heavy  = onGround and remap(horizSpeed,SNOW_START,SNOW_FULL,0,60) or 0
    local powder = onGround and remap(horizSpeed,SNOW_START,SNOW_FULL,0,80) or 0
    local tb     = (onGround and steer) and 60 or 0
    for i,e in pairs(activeSnowEmitters) do
        if e and e.Parent then
            e.Rate = (((i-1)%4)<2) and (heavy+tb) or (powder+tb)
        end
    end
end)