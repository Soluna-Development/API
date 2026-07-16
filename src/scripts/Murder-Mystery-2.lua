local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local _typeof = typeof

local Players, LocalPlayer, RunService, UserInputService, HttpService, TweenService, CoreGui =
    game:GetService("Players"),
    game:GetService("Players").LocalPlayer,
    game:GetService("RunService"),
    game:GetService("UserInputService"),
    game:GetService("HttpService"),
    game:GetService("TweenService"),
    game:GetService("CoreGui")

local Options = Fluent.Options
local State = { fly = { active = false, gyro = nil, velocity = nil, speed = 1 } }
local killAuraConnection = nil
local coinMagnetThread = nil
local coinCache = { list = {}, container = nil, addedConn = nil, removedConn = nil }
local cachedCharacterParts = { character = nil, parts = {} }
local playerData = {}
local espContainer = nil
local noclipConnection = nil
local infiniteJumpConnection = nil
local soluna_troll_target_selectedPlayer = nil
local safeZonePart = nil

local Utility = {}

local function clearCoinCache()
	if coinCache.addedConn then
		coinCache.addedConn:Disconnect()
		coinCache.addedConn = nil
	end
	if coinCache.removedConn then
		coinCache.removedConn:Disconnect()
		coinCache.removedConn = nil
	end
	coinCache.list = {}
	coinCache.container = nil
end

local function removeCoinFromCache(coin)
	if not coin then
		return
	end
	for index = #coinCache.list, 1, -1 do
		if coinCache.list[index] == coin then
			table.remove(coinCache.list, index)
			break
		end
	end
	pcall(function()
		coin:SetAttribute("SolunaSkip", true)
	end)
	task.delay(2, function()
		pcall(function()
			if coin and coin.Parent then
				coin:SetAttribute("SolunaSkip", nil)
			end
		end)
	end)
end

local function bindCoinCache(container)
	if not container then
		clearCoinCache()
		return
	end
	if coinCache.container == container then
		return
	end
	clearCoinCache()
	coinCache.container = container
	for _, child in ipairs(container:GetChildren()) do
		pcall(function()
			child:SetAttribute("SolunaSkip", nil)
		end)
		table.insert(coinCache.list, child)
	end
	coinCache.addedConn = container.ChildAdded:Connect(function(child)
		pcall(function()
			child:SetAttribute("SolunaSkip", nil)
		end)
		table.insert(coinCache.list, child)
	end)
	coinCache.removedConn = container.ChildRemoved:Connect(function(child)
		for index = #coinCache.list, 1, -1 do
			if coinCache.list[index] == child then
				table.remove(coinCache.list, index)
				break
			end
		end
	end)
end

local function getCharacterBaseParts(character)
	if cachedCharacterParts.character == character and character then
		return cachedCharacterParts.parts
	end
	local parts = {}
	if character then
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end
	cachedCharacterParts = { character = character, parts = parts }
	return parts
end

local function touchCoinTargets(coinPart, targets, fireTouch)
	if not coinPart or not coinPart.Parent or not fireTouch then
		return
	end
	for _, targetPart in ipairs(targets) do
		if targetPart and targetPart.Parent then
			pcall(fireTouch, coinPart, targetPart, 0)
			pcall(fireTouch, coinPart, targetPart, 1)
		end
	end
end

function Utility.Notify(description, title, lifetime, style, callback)
	if Options.enableNotifications and Options.enableNotifications.Value == false then
		return
	end
	Fluent:Notify({
		Title = title or "Soluna",
		Content = tostring(description),
		Duration = lifetime or 3,
		Callback = callback,
	})
end

function Utility.SplitString(str, delim)
	local b = {}
	delim = delim or ","
	for w in str:gmatch("[^" .. delim .. "]+") do
		table.insert(b, w)
	end
	return b
end

function Utility.ToTokens(str)
	local t = {}
	for o, n in str:gmatch("([+-])([^+-]+)") do
		table.insert(t, {
			Operator = o,
			Name = n,
		})
	end
	return t
end

function Utility.OnlyIncludeInTable(tab, matches)
	local mT, rT = {}, {}
	if not matches then
		return tab
	end
	for _, v in pairs(matches) do
		if v and v.Name then
			mT[v.Name] = true
		end
	end
	for _, v in pairs(tab) do
		if v and v.Name and mT[v.Name] then
			table.insert(rT, v)
		end
	end
	return rT
end

function Utility.RemoveTableMatches(tab, matches)
	local mT, rT = {}, {}
	if not matches then
		return tab
	end
	for _, v in pairs(matches) do
		if v and v.Name then
			mT[v.Name] = true
		end
	end
	for _, v in pairs(tab) do
		if v and v.Name and not mT[v.Name] then
			table.insert(rT, v)
		end
	end
	return rT
end

function Utility.GetPlayersByName(Name)
	local P = game:GetService("Players")
	local N, L, F = Name:lower(), #Name, {}
	for _, v in pairs(P:GetPlayers()) do
		if N:sub(1, 1) == "@" then
			if v.Name:lower():sub(1, L - 1) == N:sub(2) then
				table.insert(F, v)
			end
		else
			if v.Name:lower():sub(1, L) == N or v.DisplayName:lower():sub(1, L) == N then
				table.insert(F, v)
			end
		end
	end
	return F
end

function Utility.GetPlayer(list, speaker)
	local P = game:GetService("Players")
	speaker = speaker or P.LocalPlayer
	if list == nil then
		return speaker
	end
	local nL = Utility.SplitString(list, ",")
	local fL = {}
	for _, n in pairs(nL) do
		if n:sub(1, 1) ~= "+" and n:sub(1, 1) ~= "-" then
			n = "+" .. n
		end
		local tk = Utility.ToTokens(n)
		local iP = P:GetPlayers()
		for _, v in pairs(tk) do
			if v.Operator == "+" then
				iP = Utility.OnlyIncludeInTable(iP, Utility.GetPlayersByName(v.Name))
			else
				iP = Utility.RemoveTableMatches(iP, Utility.GetPlayersByName(v.Name))
			end
		end
		for _, v in pairs(iP) do
			table.insert(fL, v)
		end
	end
	return fL[1]
end

function Utility.getClosestModelToPlayer(player, instances)
	local closestInstance, closestDistance = nil, math.huge
	if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return nil, math.huge
	end
	local playerPosition = player.Character.HumanoidRootPart.Position
	for _, instance in ipairs(instances) do
		if not instance or not instance.Parent then
			continue
		end
		local instancePosition
		if _typeof(instance.IsA) == "function" then
			if instance:IsA("Model") then
				if instance.PrimaryPart then
					instancePosition = instance.PrimaryPart.Position
				elseif _typeof(instance.GetPivot) == "function" then
					local pivot = instance:GetPivot()
					if pivot and _typeof(pivot) == "CFrame" then
						instancePosition = pivot.Position
					end
				end
			elseif instance:IsA("BasePart") then
				instancePosition = instance.Position
			end
		else
			if instance.ClassName == "Model" then
				if instance.PrimaryPart then
					instancePosition = instance.PrimaryPart.Position
				end
			elseif rawget(instance, "Position") then
				instancePosition = instance.Position
			end
		end
		if instancePosition then
			local distance = (instancePosition - playerPosition).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestInstance = instance
			end
		end
	end
	return closestInstance, closestDistance
end

function Utility.miniFling(playerToFling)
	local LocalPlayer = game:GetService("Players").LocalPlayer
	if not playerToFling then
		Utility.Notify("Fling target is nil.", "Fling Error", 3, "Cancel")
		return
	end
	local targetPlayer = playerToFling
	local localPlayerChar = LocalPlayer.Character
	local localPlayerHumanoid = localPlayerChar and localPlayerChar:FindFirstChildOfClass("Humanoid")
	local localPlayerHRP = localPlayerHumanoid and localPlayerHumanoid.RootPart
	if not (localPlayerChar and localPlayerHumanoid and localPlayerHRP) then
		Utility.Notify("Your character is not set up to perform this action.", "Fling Error", 3, "Cancel")
		return
	end
	local targetPlayerChar = targetPlayer.Character
	if not targetPlayerChar then
		Utility.Notify(targetPlayer.Name .. " has no character to fling.", "Fling Error", 3, "Cancel")
		return
	end
	local targetPlayerHumanoid = targetPlayerChar:FindFirstChildOfClass("Humanoid")
	local targetPlayerHRP = targetPlayerHumanoid and targetPlayerHumanoid.RootPart
	local targetPlayerHead = targetPlayerChar:FindFirstChild("Head")
	local targetPlayerAccessory = targetPlayerChar:FindFirstChildOfClass("Accessory")
	local targetPlayerAccessoryHandle = targetPlayerAccessory and targetPlayerAccessory:FindFirstChild("Handle")
	local localPlayerOldCFrame
	if localPlayerHRP.Velocity.Magnitude < 50 then
		localPlayerOldCFrame = localPlayerHRP.CFrame
	else
		Utility.Notify("You are moving quickly; fling reset position might be less accurate.", "Fling Info", 2)
	end
	if targetPlayerHumanoid and targetPlayerHumanoid.Sit then
	end
	if targetPlayerHead then
		if targetPlayerHead.Velocity.Magnitude > 500 then
			Utility.Notify(targetPlayer.Name .. " is already moving very fast. Not flinging again.", "Fling Info", 3)
			return
		end
	elseif not targetPlayerHead and targetPlayerAccessoryHandle then
		if targetPlayerAccessoryHandle.Velocity.Magnitude > 500 then
			Utility.Notify(
                targetPlayer.Name .. " (via accessory) is already moving very fast. Not flinging again.",
                "Fling Info",
                3
            )
			return
		end
	end
	if targetPlayerHead then
		workspace.CurrentCamera.CameraSubject = targetPlayerHead
	elseif not targetPlayerHead and targetPlayerAccessoryHandle then
		workspace.CurrentCamera.CameraSubject = targetPlayerAccessoryHandle
	elseif targetPlayerHumanoid and targetPlayerHRP then
		workspace.CurrentCamera.CameraSubject = targetPlayerHumanoid
	end
	if not targetPlayerChar:FindFirstChildWhichIsA("BasePart") then
		Utility.Notify(targetPlayer.Name .. " has no base parts to target for fling.", "Fling Error", 3, "Cancel")
		return
	end
	local function setLocalPlayerPositionAndVelocity(targetPartForOffset, cframeOffset, cframeAngles)
		if not localPlayerHRP or not localPlayerHRP.Parent then
			return
		end
		localPlayerHRP.CFrame = CFrame.new(targetPartForOffset.Position) * cframeOffset * cframeAngles
		if localPlayerChar and localPlayerChar.PrimaryPart then
			localPlayerChar:SetPrimaryPartCFrame(CFrame.new(targetPartForOffset.Position) * cframeOffset * cframeAngles)
		end
		localPlayerHRP.Velocity = Vector3.new(4782969, 4782969 * 10, 4782969)
		localPlayerHRP.RotVelocity = Vector3.new(43046721, 43046721, 43046721)
	end
	local function flingLoop(partToTrackVelocity)
		local duration = 2
		local startTime = tick()
		local angleIncrement = 0
		repeat
			if localPlayerHRP and targetPlayerHumanoid and partToTrackVelocity and partToTrackVelocity.Parent then
				angleIncrement = angleIncrement + 100
				local moveDir = targetPlayerHumanoid.MoveDirection
				local targetVelMag = partToTrackVelocity.Velocity.Magnitude
				local targetWalkSpeed = targetPlayerHumanoid.WalkSpeed
				if targetVelMag < 50 then
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, 1.5, 0) + moveDir * targetVelMag / 1.25,
                        CFrame.Angles(math.rad(angleIncrement), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, -1.5, 0) + moveDir * targetVelMag / 1.25,
                        CFrame.Angles(math.rad(angleIncrement), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(2.25, 1.5, -2.25) + moveDir * targetVelMag / 1.25,
                        CFrame.Angles(math.rad(angleIncrement), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(-2.25, -1.5, 2.25) + moveDir * targetVelMag / 1.25,
                        CFrame.Angles(math.rad(angleIncrement), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, 1.5, 0) + moveDir,
                        CFrame.Angles(math.rad(angleIncrement), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, -1.5, 0) + moveDir,
                        CFrame.Angles(math.rad(angleIncrement), 0, 0)
                    )
					task.wait()
				else
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, 1.5, targetWalkSpeed),
                        CFrame.Angles(math.rad(90), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, -1.5, -targetWalkSpeed),
                        CFrame.Angles(0, 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, 1.5, targetWalkSpeed),
                        CFrame.Angles(math.rad(90), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, 1.5, targetVelMag / 1.25),
                        CFrame.Angles(math.rad(90), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, -1.5, -targetVelMag / 1.25),
                        CFrame.Angles(0, 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, 1.5, targetVelMag / 1.25),
                        CFrame.Angles(math.rad(90), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, -1.5, 0),
                        CFrame.Angles(math.rad(90), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, -1.5, 0),
                        CFrame.Angles(0, 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, -1.5, 0),
                        CFrame.Angles(math.rad(-90), 0, 0)
                    )
					task.wait()
					setLocalPlayerPositionAndVelocity(
                        partToTrackVelocity,
                        CFrame.new(0, -1.5, 0),
                        CFrame.Angles(0, 0, 0)
                    )
					task.wait()
				end
			else
				break
			end
		until not partToTrackVelocity.Parent
            or partToTrackVelocity.Velocity.Magnitude > 500
            or targetPlayer.Parent ~= game:GetService("Players")
            or targetPlayer.Character ~= targetPlayerChar
            or (targetPlayerHumanoid and targetPlayerHumanoid.Sit)
            or (localPlayerHumanoid and localPlayerHumanoid.Health <= 0)
            or tick() > startTime + duration
	end
	local originalFallenPartsDestroyHeight = workspace.FallenPartsDestroyHeight
	workspace.FallenPartsDestroyHeight = 0 / 0
	local tempVelocity = Instance.new("BodyVelocity")
	tempVelocity.Name = "SolunaFlingVel"
	tempVelocity.Parent = localPlayerHRP
	tempVelocity.Velocity = Vector3.new(43046721, 43046721, 43046721)
	tempVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	if localPlayerHumanoid and localPlayerHumanoid.Parent then
		localPlayerHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	end
	if targetPlayerHRP and targetPlayerHead then
		if (targetPlayerHRP.CFrame.Position - targetPlayerHead.CFrame.Position).Magnitude > 5 then
			flingLoop(targetPlayerHead)
		else
			flingLoop(targetPlayerHRP)
		end
	elseif targetPlayerHRP and not targetPlayerHead then
		flingLoop(targetPlayerHRP)
	elseif not targetPlayerHRP and targetPlayerHead then
		flingLoop(targetPlayerHead)
	elseif not targetPlayerHRP and not targetPlayerHead and targetPlayerAccessory and targetPlayerAccessoryHandle then
		flingLoop(targetPlayerAccessoryHandle)
	else
		Utility.Notify("Can't find a proper part of " .. targetPlayer.Name .. " to fling.", "Fling Error", 3, "Cancel")
	end
	if tempVelocity and tempVelocity.Parent then
		tempVelocity:Destroy()
	end
	if localPlayerHumanoid and localPlayerHumanoid.Parent then
		localPlayerHumanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
	end
	if workspace.CurrentCamera and localPlayerHumanoid and localPlayerHumanoid.Parent then
		workspace.CurrentCamera.CameraSubject = localPlayerHumanoid
	end
	if localPlayerOldCFrame and localPlayerHRP and localPlayerHRP.Parent then
		local attempts = 0
		repeat
			localPlayerHRP.CFrame = localPlayerOldCFrame * CFrame.new(0, 0.5, 0)
			if localPlayerChar and localPlayerChar.PrimaryPart then
				localPlayerChar:SetPrimaryPartCFrame(localPlayerOldCFrame * CFrame.new(0, 0.5, 0))
			end
			if localPlayerHumanoid and localPlayerHumanoid.Parent then
				localPlayerHumanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
			if localPlayerChar then
				for _, part in ipairs(localPlayerChar:GetChildren()) do
					if part:IsA("BasePart") then
						part.Velocity = Vector3.new()
						part.RotVelocity = Vector3.new()
					end
				end
			end
			task.wait()
			attempts = attempts + 1
		until not localPlayerHRP.Parent
            or (localPlayerHRP.Position - localPlayerOldCFrame.Position).Magnitude < 25
            or attempts > 50
	else
		Utility.Notify("Could not restore original position after fling.", "Fling Info", 2)
	end
	workspace.FallenPartsDestroyHeight = originalFallenPartsDestroyHeight
	Utility.Notify("Fling attempt on " .. targetPlayer.Name .. " finished.", "Fling Action", 2)
end

function getMap()
	for _, o in ipairs(workspace:GetChildren()) do
		if o:FindFirstChild("CoinContainer") and o:FindFirstChild("Spawns") then
			return o
		end
	end
	return nil
end

function Utility.pickupGun()
    local fireFunc = _G.firetouchinterest or firetouchinterest
    if not fireFunc then
        Utility.Notify("`firetouchinterest` is not available in your executor.", "Error", 4, "Cancel")
        return false
    end

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then
        Utility.Notify("Cannot pick up gun: Your character is not available.", "Error", 2)
        return false
    end

    local gunPart = workspace:FindFirstChild("GunDrop", true)
    if not (gunPart and gunPart:IsA("BasePart")) then
        Utility.Notify("No dropped gun found anywhere in the game.", "Info", 2)
        return false
    end

    Utility.Notify("Gun detected! Initiating cheat pickup...", "Gun Pickup")

    local originalCFrame = myHRP.CFrame
    local originalCollisionStates = {}

    for _, part in ipairs(myChar:GetDescendants()) do
        if part:IsA("BasePart") then
            originalCollisionStates[part] = part.CanCollide
            part.CanCollide = false
        end
    end

    myHRP.CFrame = gunPart.CFrame * CFrame.new(0, 2, 0)
    task.wait(0.1)

    pcall(fireFunc, gunPart, myHRP, 0)
    task.wait(0.1)
    pcall(fireFunc, gunPart, myHRP, 1)
    task.wait(0.2)

    myHRP.CFrame = originalCFrame

    for part, canCollide in pairs(originalCollisionStates) do
        if part and part.Parent then
            part.CanCollide = canCollide
        end
    end

    if not gunPart.Parent then
        Utility.Notify("Successfully picked up the gun!", "Success")
        if _typeof(ReloadPlayerESP) == "function" then
            ReloadPlayerESP()
        end
        return true
    else
        Utility.Notify("Failed to pick up the gun.", "Error", 2, "Cancel")
        return false
    end
end

local function createSafeZone()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        Utility.Notify("Waiting for character to spawn to create Safe Zone...", "Info")
        LocalPlayer.CharacterAdded:Wait()
    end

    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then 
        Utility.Notify("Could not get character position for Safe Zone.", "Error")
        return 
    end

    if safeZonePart and safeZonePart.Parent then
        safeZonePart:Destroy()
    end

    safeZonePart = Instance.new("Part")
    safeZonePart.Name = "SolunaSafeZone"
    safeZonePart.Size = Vector3.new(500, 2, 500)
    safeZonePart.CFrame = myHRP.CFrame * CFrame.new(0, 5000, 0)
    safeZonePart.Anchored = true
    safeZonePart.Transparency = 0.5
    safeZonePart.Color = Color3.fromRGB(0, 255, 255)
    safeZonePart.Material = Enum.Material.ForceField
    safeZonePart.CanCollide = true
    safeZonePart.Parent = workspace

    Utility.Notify("Safe Zone platform created 5000 studs above you.", "Success")
end

local ESPIndicatorModule = {}
do
	local e = {}
	e.__index = e
	local function get_esp_parent()
		if get_hidden_gui then
			return get_hidden_gui()
		end
		if gethui then
			return gethui()
		end
		if syn and syn.protect_gui then
			local g = Instance.new("ScreenGui", CoreGui)
			g.Name = HttpService:GenerateGUID(false)
			syn.protect_gui(g)
			return g
		end
		return CoreGui
	end
	e.Defaults = {
		AccentColor = Color3.new(1, 1, 0),
		HighlightFillTransparency = 0.7,
		HighlightOutlineTransparency = 0,
		HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		ArrowShow = false,
		ArrowEdgePadding = 50,
		ArrowMinDistance = 0,
		ArrowSize = UDim2.new(0, 30, 0, 30),
		ArrowImage = "rbxassetid://97136202386756",
		ArrowShowDistanceText = true,
		ArrowDistanceFont = Enum.Font.Gotham,
		ArrowDistanceTextSize = 14,
		ShowLabel = false,
		LabelText = "Target",
		LabelMaxDistance = 200,
		LabelOffset = Vector3.new(0, 2.5, 0),
		Parent = get_esp_parent(),
	}
	function e:_allArrows()
		local t = {}
		for _, i in pairs(self.Indicators) do
			if i.Arrow then
				table.insert(t, i.Arrow)
			end
		end
		return t
	end
	function e.new(s)
		local S = setmetatable({}, e)
		S.Settings = {}
		for k, v in pairs(e.Defaults) do
			S.Settings[k] = (s and s[k] ~= nil) and s[k] or v
		end
		S.ScreenGui = Instance.new("ScreenGui")
		S.ScreenGui.Name = "SolunaESPContainer_" .. HttpService:GenerateGUID(false)
		S.ScreenGui.IgnoreGuiInset = true
		S.ScreenGui.ResetOnSpawn = false
		S.ScreenGui.Parent = S.Settings.Parent
		S.ArrowTemplate = Instance.new("ImageLabel")
		S.ArrowTemplate.Name = "ArrowTemplate"
		S.ArrowTemplate.Size = S.Settings.ArrowSize
		S.ArrowTemplate.AnchorPoint = Vector2.new(0.5, 0.5)
		S.ArrowTemplate.BackgroundTransparency = 1
		S.ArrowTemplate.Image = S.Settings.ArrowImage
		S.ArrowTemplate.ImageColor3 = S.Settings.AccentColor
		S.ArrowTemplate.Visible = false
		S.ArrowTemplate.Parent = S.ScreenGui
		S.Scaler = Instance.new("UIScale", S.ArrowTemplate)
		S.Scaler.Name = "Scaler"
		S.Scaler.Scale = 0
		S.Indicators = {}
		S.Groups = {}
		S.TargetIndex = {}
		S._updateConn = RunService.RenderStepped:Connect(function()
			if S.ScreenGui and S.ScreenGui.Parent then
				S:_update()
			end
		end)
		S._cleanupConn = RunService.Heartbeat:Connect(function()
			if S.ScreenGui and S.ScreenGui.Parent then
				S:_cleanupOrphaned("Highlight", "_allHighlights")
				S:_cleanupOrphaned("ImageLabel", "_allArrows", "^Arrow_")
				S:_cleanupOrphaned("BillboardGui", "_allLabels", "^Label_")
			end
		end)
		return S
	end
	function e:AddGroup(gN)
		local g = self.Groups[gN]
		if not g then
			g = {
				enabled = true,
				properties = {},
				targets = {},
			}
			self.Groups[gN] = g
		end
		return g
	end
	function e:GetGroup(gN)
		return self.Groups[gN]
	end
	function e:GetGroupTargets(gN)
		local g = self.Groups[gN]
		return (g and g.targets) or {}
	end
	function e:RemoveGroup(gN)
		local g = self.Groups[gN]
		if not g then
			return false
		end
		for _, t in ipairs(g.targets) do
			local tG = self.TargetIndex[t]
			if tG then
				for i, n in ipairs(tG) do
					if n == gN then
						table.remove(tG, i)
						break
					end
				end
				if #tG == 0 then
					self.TargetIndex[t] = nil
				end
			end
			if not self.TargetIndex[t] then
				self:Remove(t)
			end
		end
		self.Groups[gN] = nil
		return true
	end
	function e:ClearAllGroups()
		for gN, _ in pairs(self.Groups) do
			self:RemoveGroup(gN)
		end
	end
	function e:ToggleGroup(gN, en)
		local g = self.Groups[gN]
		if not g then
			return
		end
		g.enabled = (en ~= nil) and en or not g.enabled
		for _, t in ipairs(g.targets) do
			local ind = self.Indicators[t]
			if ind then
				if ind.Highlight then
					ind.Highlight.Enabled = g.enabled
				end
				if ind.Arrow then
					ind.Arrow.Visible = g.enabled and (ind.Options.ArrowShow or self.Settings.ArrowShow)
				end
				if ind.Label then
					ind.Label.Enabled = g.enabled
				end
			end
		end
		return g.enabled
	end
	function e:SetGroupProperty(gN, pN, v)
		local g = self:AddGroup(gN)
		g.properties[pN] = v
		for _, t in ipairs(g.targets) do
			local ind = self.Indicators[t]
			if ind then
				if pN == "AccentColor" then
					if ind.Highlight then
						ind.Highlight.FillColor = v
						ind.Highlight.OutlineColor = v
					end
					if ind.Arrow then
						ind.Arrow.ImageColor3 = v
					end
					if ind.DistanceLabel then
						ind.DistanceLabel.TextColor3 = v
					end
					if ind.Label and ind.Label:FindFirstChild("TextLabel") then
						ind.Label.TextLabel.TextColor3 = v
					end
				end
			end
		end
	end
	function e:Add(t, o)
		assert(t, "ESPIndicator:Add requires a non-nil target")
		if not t:IsA("Instance") or not t.Parent then
			Utility.Notify("ESP target is invalid or has no parent: " .. tostring(t), "ESP Error")
			return
		end
		o = o or {}
		local gu = HttpService:GenerateGUID(false)
		local hL
		if t:IsA("Model") or t:IsA("BasePart") or t:IsA("Accoutrement") then
			hL = Instance.new("Highlight")
			hL.Name = "Highlight_" .. gu
			hL.Adornee = t
			hL.FillTransparency = o.HighlightFillTransparency or self.Settings.HighlightFillTransparency
			hL.FillColor = o.AccentColor or self.Settings.AccentColor
			hL.OutlineColor = o.AccentColor or self.Settings.AccentColor
			hL.OutlineTransparency = o.HighlightOutlineTransparency or self.Settings.HighlightOutlineTransparency
			hL.DepthMode = o.HighlightDepthMode or self.Settings.HighlightDepthMode
			hL.Parent = self.ScreenGui
		end
		local aR, sC, dL
		if o.ArrowShow or self.Settings.ArrowShow then
			aR = self.ArrowTemplate:Clone()
			aR.Name = "Arrow_" .. gu
			aR.ImageColor3 = o.AccentColor or self.Settings.AccentColor
			aR.Size = o.ArrowSize or self.Settings.ArrowSize
			aR.Visible = true
			aR.Parent = self.ScreenGui
			sC = aR:FindFirstChild("Scaler") or Instance.new("UIScale", aR)
			if o.ArrowShowDistanceText or self.Settings.ArrowShowDistanceText then
				dL = Instance.new("TextLabel")
				dL.Name = "DistanceLabel"
				dL.AnchorPoint = Vector2.new(0.5, 0)
				dL.BackgroundTransparency = 1
				dL.Font = o.ArrowDistanceFont or self.Settings.ArrowDistanceFont
				dL.TextSize = o.ArrowDistanceTextSize or self.Settings.ArrowDistanceTextSize
				dL.TextColor3 = o.AccentColor or self.Settings.AccentColor
				dL.Parent = aR
			end
		end
		local lG
		if (o.ShowLabel or self.Settings.ShowLabel) and (t:IsA("Model") or t:IsA("BasePart")) then
			lG = Instance.new("BillboardGui")
			lG.Name = "Label_" .. gu
			lG.AlwaysOnTop = true
			lG.MaxDistance = o.LabelMaxDistance or self.Settings.LabelMaxDistance
			lG.Size = UDim2.new(0, 100, 0, 20)
			lG.StudsOffset = o.LabelOffset or self.Settings.LabelOffset
			lG.Adornee = t
			lG.Parent = self.ScreenGui
			local tL = Instance.new("TextLabel")
			tL.Name = "TextLabel"
			tL.Size = UDim2.new(1, 0, 1, 0)
			tL.BackgroundTransparency = 1
			tL.Font = Enum.Font.Gotham
			tL.TextScaled = true
			tL.TextWrapped = true
			tL.TextColor3 = o.AccentColor or self.Settings.AccentColor
			tL.Text = o.LabelText or self.Settings.LabelText
			tL.Parent = lG
			Instance.new("UIStroke", tL)
		end
		self.Indicators[t] = {
			Highlight = hL,
			Arrow = aR,
			Scaler = sC,
			DistanceLabel = dL,
			Label = lG,
			Options = o,
		}
		local gN = o.GroupName
		if gN then
			self:AddToGroup(t, gN)
		end
	end
	function e:Remove(t)
		local ind = self.Indicators[t]
		if not ind then
			return
		end
		if ind.Highlight then
			ind.Highlight:Destroy()
		end
		if ind.Arrow then
			ind.Arrow:Destroy()
		end
		if ind.Label then
			ind.Label:Destroy()
		end
		local tGs = self.TargetIndex[t]
		if tGs then
			for _, gN in ipairs(tGs) do
				local g = self.Groups[gN]
				if g then
					for i, tg in ipairs(g.targets) do
						if tg == t then
							table.remove(g.targets, i)
							break
						end
					end
				end
			end
			self.TargetIndex[t] = nil
		end
		self.Indicators[t] = nil
	end
	function e:AddToGroup(t, gN)
		local g = self:AddGroup(gN)
		if not table.find(g.targets, t) then
			table.insert(g.targets, t)
		end
		local tGs = self.TargetIndex[t]
		if not tGs then
			tGs = {}
			self.TargetIndex[t] = tGs
		end
		if not table.find(tGs, gN) then
			table.insert(tGs, gN)
		end
		for pN, pV in pairs(g.properties) do
			self:SetGroupProperty(gN, pN, pV)
		end
		if not g.enabled then
			local ind = self.Indicators[t]
			if ind then
				if ind.Highlight then
					ind.Highlight.Enabled = false
				end
				if ind.Arrow then
					ind.Arrow.Visible = false
				end
				if ind.Label then
					ind.Label.Enabled = false
				end
			end
		end
		return true
	end
	function e:_cleanupOrphaned(cN, aMN, nP)
		if not self.ScreenGui or not self.ScreenGui.Parent then
			return
		end
		for _, ch in ipairs(self.ScreenGui:GetChildren()) do
			if ch:IsA(cN) and (not nP or ch.Name:match(nP)) then
				local fo = false
				for _, iC in ipairs(self[aMN](self)) do
					if iC == ch then
						fo = true
						break
					end
				end
				if not fo then
					if ch:IsA("Highlight") or ch:IsA("BillboardGui") then
						ch.Adornee = nil
					end
					ch:Destroy()
				end
			end
		end
	end
	function e:_allHighlights()
		local t = {}
		for _, i in pairs(self.Indicators) do
			if i.Highlight then
				table.insert(t, i.Highlight)
			end
		end
		return t
	end
	function e:_allLabels()
		local t = {}
		for _, i in pairs(self.Indicators) do
			if i.Label then
				table.insert(t, i.Label)
			end
		end
		return t
	end
	function e:_update()
		if not self.ScreenGui or not self.ScreenGui.Parent then
			return
		end
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local vS = cam.ViewportSize
		local vX, vY = vS.X, vS.Y
		for t, ind in pairs(self.Indicators) do
			if not t or not t.Parent then
				self:Remove(t)
				continue
			end
			local o = ind.Options
			local aR = ind.Arrow
			local sC = ind.Scaler
			if not aR or not sC or not aR.Parent or not sC.Parent then
				continue
			end
			if not aR.Visible and not (o.ArrowShow or self.Settings.ArrowShow) then
				continue
			end
			local tP
			if t:IsA("Model") and t.PrimaryPart then
				tP = t.PrimaryPart.Position
			elseif t:IsA("BasePart") then
				tP = t.Position
			else
				continue
			end
			local sP, oS = cam:WorldToViewportPoint(tP)
			local d = (cam.CFrame.Position - tP).Magnitude
			local mD = o.ArrowMinDistance or self.Settings.ArrowMinDistance
			local eP = o.ArrowEdgePadding or self.Settings.ArrowEdgePadding
			if oS and d > mD then
				if sC.Scale ~= 0 then
					TweenService:Create(sC, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Scale = 0,
					}):Play()
				end
			else
				if sC.Scale ~= 1 then
					TweenService:Create(sC, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Scale = 1,
					}):Play()
				end
				local efEP = eP
				local pW, pH = vX - efEP * 2, vY - efEP * 2
				local cCF = cam.CFrame
				local rP = cCF:PointToObjectSpace(tP)
				local aX = math.atan2(rP.X, -rP.Z)
				local aY = math.atan2(rP.Y, math.sqrt(rP.X ^ 2 + rP.Z ^ 2))
				local fX, fY
				local rD
				if oS then
					fX = sP.X
					fY = sP.Y
					rD = math.deg(math.atan2(sP.X - vX / 2, -(sP.Y - vY / 2)))
				else
					local tAX = math.tan(aX)
					local tAY = math.tan(aY)
					local ePX = vX / 2
					local ePY = vY / 2
					local xOE = ePY / tAX
					local yOE = ePX * tAX
					if math.abs(rP.X / -rP.Z) > vX / vY then
						fX = (rP.X > 0 and vX - efEP or efEP)
						fY = vY / 2 - (rP.Y * (vX / 2 - efEP) / math.abs(rP.X))
					else
						fY = (rP.Y > 0 and efEP or vY - efEP)
						fX = vX / 2 + (rP.X * (vY / 2 - efEP) / math.abs(rP.Y))
					end
					fX = math.clamp(fX, efEP, vX - efEP)
					fY = math.clamp(fY, efEP, vY - efEP)
					rD = math.deg(aX)
				end
				TweenService:Create(aR, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.fromOffset(fX, fY),
					Rotation = rD,
				}):Play()
			end
			if ind.DistanceLabel then
				ind.DistanceLabel.Text = string.format("%dm", math.round(d))
				local aSY = (o.ArrowSize and o.ArrowSize.Y.Offset or self.Settings.ArrowSize.Y.Offset)
				ind.DistanceLabel.Position = UDim2.new(0.5, 0, 0, aSY / 2 + 5)
			end
		end
	end
	function e:Destroy()
		if self._updateConn then
			self._updateConn:Disconnect()
			self._updateConn = nil
		end
		if self._cleanupConn then
			self._cleanupConn:Disconnect()
			self._cleanupConn = nil
		end
		self:ClearAllGroups()
		for t, _ in pairs(self.Indicators) do
			self:Remove(t)
		end
		if self.ScreenGui then
			self.ScreenGui:Destroy()
			self.ScreenGui = nil
		end
		self.Indicators = {}
		self.Groups = {}
		self.TargetIndex = {}
	end
	ESPIndicatorModule = e
end

local SolunaWindow = Fluent:CreateWindow({
	Title = "Soluna",
	SubTitle = "Murder Mystery 2",
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 500),
	Acrylic = true,
	Theme = "Darker",
	MinimizeKey = Enum.KeyCode.RightShift,
})

local Tabs = {
	Player = SolunaWindow:AddTab({ Title = "Player", Icon = "user" }),
    Combat = SolunaWindow:AddTab({ Title = "Combat", Icon = "swords" }),
    Visuals = SolunaWindow:AddTab({ Title = "Visuals", Icon = "eye" }),
    Automation = SolunaWindow:AddTab({ Title = "Automation", Icon = "bot" }),
    Teleport = SolunaWindow:AddTab({ Title = "Teleport", Icon = "move" }),
    Misc = SolunaWindow:AddTab({ Title = "Misc", Icon = "box" }),
    Trolling = SolunaWindow:AddTab({ Title = "Trolling", Icon = "smile" }),
	Settings = SolunaWindow:AddTab({ Title = "Settings", Icon = "settings" }),
}

local function FindRole(roleName)
	for player, data in pairs(playerData) do
		if data.Role == roleName or (roleName == "Sheriff" and data.Role == "Hero") then
			local pI = Players:FindFirstChild(player)
			if pI then
				return pI
			end
		end
	end
	for _, pI in ipairs(Players:GetPlayers()) do
		if
            pI.Backpack:FindFirstChild(
                roleName == "Murderer" and "Knife"
                    or ((roleName == "Sheriff" or roleName == "Hero") and "Gun" or "None")
            )
        then
			return pI
		end
		if
            pI.Character
            and pI.Character:FindFirstChild(
                roleName == "Murderer" and "Knife"
                    or ((roleName == "Sheriff" or roleName == "Hero") and "Gun" or "None")
            )
        then
			return pI
		end
	end
	return nil
end

local function FindOtherSheriff()
	for player, data in pairs(playerData) do
		if data.Role == "Sheriff" or data.Role == "Hero" then
			local pI = Players:FindFirstChild(player)
			if pI and pI ~= LocalPlayer then
				return pI
			end
		end
	end
	for _, pI in ipairs(Players:GetPlayers()) do
		if pI == LocalPlayer then
			continue
		end
		if pI.Backpack:FindFirstChild("Gun") or (pI.Character and pI.Character:FindFirstChild("Gun")) then
			return pI
		end
	end
	return nil
end

local function GetPredictedPosition(targetPlayer, offset)
	if not targetPlayer or not targetPlayer.Character then
		return Vector3.new(), "Target has no character"
	end
	local hrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return Vector3.new(), "Target missing HRP or Humanoid"
	end
	local vel = hrp.AssemblyLinearVelocity
	local mD = hum.MoveDirection
	local png = LocalPlayer:GetNetworkPing()
        * (Options.offsetToPingMult and Options.offsetToPingMult.Value or 1)
	local pP = hrp.Position + (vel * png) + (mD * offset * (1 + png * 2))
	pP = pP + Vector3.new(0, hrp.Size.Y * 0.25, 0)
	return pP
end

local ReloadPlayerESP

function SetFlyState(enabled)
	State.fly.active = enabled
	Utility.Notify("Fly", (enabled and "Flight Systems Engaged." or "Flight Systems Disengaged."))
	local char = LocalPlayer.Character
	if not char then return end

	pcall(function()
		local humanoid, rootPart = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart then return end

		if enabled then
			humanoid.PlatformStand = true

			if not State.fly.gyro then
				State.fly.gyro = Instance.new("BodyGyro", rootPart)
				State.fly.gyro.P = 50000
				State.fly.gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			end
			if not State.fly.velocity then
				State.fly.velocity = Instance.new("BodyVelocity", rootPart)
				State.fly.velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				State.fly.velocity.Velocity = Vector3.new()
			end
		else
			humanoid.PlatformStand = false

			if State.fly.gyro then
				State.fly.gyro:Destroy()
				State.fly.gyro = nil
			end
			if State.fly.velocity then
				State.fly.velocity:Destroy()
				State.fly.velocity = nil
			end
		end
	end)
end

RunService:BindToRenderStep("SolunaFly", Enum.RenderPriority.Character.Value, function()
    if not State.fly.active or not State.fly.velocity or not State.fly.gyro then return end

    local controls = { W = 0, A = 0, S = 0, D = 0, Q = 0, E = 0 }
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then controls.W = 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then controls.S = -1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then controls.A = -1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then controls.D = 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then controls.E = 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then controls.Q = -1 end

    local cam = workspace.CurrentCamera
    local moveDirection = Vector3.new(controls.A + controls.D, controls.Q + controls.E, controls.S + controls.W)
    local speed = 50 * State.fly.speed
    
    State.fly.velocity.Velocity = (cam.CFrame.RightVector * moveDirection.X + cam.CFrame.UpVector * moveDirection.Y + cam.CFrame.LookVector * moveDirection.Z) * speed
    State.fly.gyro.CFrame = cam.CFrame
end)

do
	local PlayerTab = Tabs.Player
	local SectionCharacter = PlayerTab:AddSection("Character")
	SectionCharacter:AddSlider("universal_walkspeed_slider", {
		Title = "Walkspeed",
		Default = 16,
		Min = 1,
		Max = 100,
		Rounding = 0,
		Callback = function(value)
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				LocalPlayer.Character.Humanoid.WalkSpeed = value
			end
		end,
	})
	SectionCharacter:AddSlider("universal_fov_val", {
		Title = "Field of View (FOV)",
		Description = "Adjust the camera FOV",
		Default = 70,
		Min = 1,
		Max = 120,
		Rounding = 0,
		Callback = function(fovVal)
			if workspace.CurrentCamera then
				workspace.CurrentCamera.FieldOfView = fovVal
			end
		end,
	})
	SectionCharacter:AddToggle("universal_loopWsFov_toggle", {
		Title = "Loop Walkspeed & FOV",
		Default = false,
		Callback = function(state)
			Utility.Notify("Loop Walkspeed/FOV: " .. (state and "Enabled" or "Disabled"))
		end,
	})
	SectionCharacter:AddToggle("universal_infiniteJump_toggle", {
		Title = "Infinite Jump",
		Default = false,
		Callback = function(state)
			Utility.Notify("Infinite Jump: " .. (state and "Enabled" or "Disabled"))
			if state then
				if infiniteJumpConnection then infiniteJumpConnection:Disconnect() end
				infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
					if Options.universal_infiniteJump_toggle and Options.universal_infiniteJump_toggle.Value and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
						LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end)
			elseif infiniteJumpConnection then
				infiniteJumpConnection:Disconnect()
				infiniteJumpConnection = nil
			end
		end,
	})

	local SectionMovement = PlayerTab:AddSection("Movement")
	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		SectionMovement:AddToggle("universal_ctrlClickTp_toggle", {
			Title = "Ctrl+Click Teleport",
			Default = false,
			Callback = function(state)
				Utility.Notify("Ctrl+Click Teleport: " .. (state and "Enabled" or "Disabled"))
			end,
		})
	end
	
LocalPlayer.CharacterAdded:Connect(function(character)
	if Options.universal_fly_toggle and Options.universal_fly_toggle.Value then
		task.wait(1)
		SetFlyState(true)
	end
	cachedCharacterParts = { character = nil, parts = {} }
end)

LocalPlayer.CharacterRemoving:Connect(function()
	cachedCharacterParts = { character = nil, parts = {} }
end)

	SectionMovement:AddToggle("universal_fly_toggle", {
		Title = "Fly",
		Default = false,
		Callback = function(state)
			SetFlyState(state)
		end,
	})
	SectionMovement:AddSlider("universal_flySpeed_slider", {
		Title = "Fly Speed Multiplier",
		Default = 1,
		Min = 0.1,
		Max = 10,
		Rounding = 1,
		Callback = function(val)
			State.fly.speed = val
		end,
	})
	SectionMovement:AddToggle("universal_noclip_toggle", {
		Title = "Noclip",
		Default = false,
		Callback = function(state)
			if noclipConnection and noclipConnection.Connected then
				noclipConnection:Disconnect()
			end
			if state then
				noclipConnection = RunService.Stepped:Connect(function()
					local character = LocalPlayer.Character
					if character then
						for _, part in ipairs(character:GetDescendants()) do
							if part:IsA("BasePart") then
								part.CanCollide = false
							end
						end
					end
				end)
				Utility.Notify("Noclip: Enabled")
			else
				Utility.Notify("Noclip: Disabled")
				Utility.Notify("Noclip disabled. Character reset might be needed to restore collisions.", "Warning", 4)
			end
		end,
	})

	RunService.RenderStepped:Connect(function()
		if Options.universal_loopWsFov_toggle and Options.universal_loopWsFov_toggle.Value then
			if workspace.CurrentCamera and Options.universal_fov_val then
				local fov = tonumber(Options.universal_fov_val.Value) or 70
				workspace.CurrentCamera.FieldOfView = fov
			end
			if
                LocalPlayer.Character
                and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                and Options.universal_walkspeed_slider
            then
				local ws = Options.universal_walkspeed_slider.Value
				LocalPlayer.Character.Humanoid.WalkSpeed = ws
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end
		if Options.universal_ctrlClickTp_toggle
        and Options.universal_ctrlClickTp_toggle.Value
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        and input.UserInputType == Enum.UserInputType.MouseButton1
    then
			local mouse = LocalPlayer:GetMouse()
			local unitRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {
				LocalPlayer.Character
			}
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
			if result and result.Position and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
				LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(result.Position)
				Utility.Notify("Teleported to mouse position.")
			else
				Utility.Notify("Could not find a place to teleport.", "Error", nil, "Cancel")
			end
		end
	end)
end

do
	local CombatTab = Tabs.Combat
	local SectionSheriffHero = CombatTab:AddSection("Sheriff/Hero Actions")
	local SectionMurderer = CombatTab:AddSection("Murderer Actions")
	local SectionCombatSettings = CombatTab:AddSection("Aiming & Prediction")
	local function shootTarget()
		if FindRole("Sheriff") ~= LocalPlayer and FindRole("Hero") ~= LocalPlayer then
			Utility.Notify("You are not the Sheriff/Hero.", "Error", nil, "Cancel")
			return
		end
		if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Gun") then
			if LocalPlayer.Backpack:FindFirstChild("Gun") then
				LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):EquipTool(LocalPlayer.Backpack.Gun)
				task.wait(0.2)
				if not LocalPlayer.Character:FindFirstChild("Gun") then
					Utility.Notify("Failed to equip the gun.", "Error", nil, "Cancel")
					return
				end
			else
				Utility.Notify("You don't have the gun.", "Error", nil, "Cancel")
				return
			end
		end
		local target = FindRole("Murderer")
		if not target then
			local otherSheriffs = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if
				p ~= LocalPlayer
				and (
					playerData[p.Name]
						and (playerData[p.Name].Role == "Sheriff" or playerData[p.Name].Role == "Hero")
					or (p.Backpack:FindFirstChild("Gun") or (p.Character and p.Character:FindFirstChild("Gun")))
				)
			then
					table.insert(otherSheriffs, p)
				end
			end
			if #otherSheriffs > 0 then
				local closestDist = math.huge
				if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
					local myPos = LocalPlayer.Character.HumanoidRootPart.Position
					for _, p_sheriff in ipairs(otherSheriffs) do
						if p_sheriff.Character and p_sheriff.Character:FindFirstChild("HumanoidRootPart") then
							local dist = (p_sheriff.Character.HumanoidRootPart.Position - myPos).Magnitude
							if dist < closestDist then
								closestDist = dist
								target = p_sheriff
							end
						end
					end
				else
					target = otherSheriffs[1]
				end
				Utility.Notify("Murderer not found. Targeting other Sheriff/Hero: " .. target.Name, "Targeting", 2)
			end
		end
		if not target or not target.Character then
			Utility.Notify("No target found (Murderer or other Sheriff/Hero).", "Error", nil, "Cancel")
			return
		end
		local shootOffsetVal = Options.shootOffset and Options.shootOffset.Value or 2.8
		local predictedPos, err = GetPredictedPosition(target, shootOffsetVal)
		if err then
			Utility.Notify(err, "Prediction Error", nil, "Cancel")
			return
		end
		if not LocalPlayer.Character:FindFirstChild("Gun") then
			if LocalPlayer.Backpack:FindFirstChild("Gun") then
				LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):EquipTool(LocalPlayer.Backpack.Gun)
				task.wait(0.1)
				if not LocalPlayer.Character:FindFirstChild("Gun") then
					Utility.Notify("Gun became unequipped before firing.", "Error", nil, "Cancel")
					return
				end
			else
				Utility.Notify("Gun lost before firing.", "Error", nil, "Cancel")
				return
			end
		end
		local gun = LocalPlayer.Character:FindFirstChild("Gun")
		local shootRemote = gun and gun:FindFirstChild("Shoot")
		if not shootRemote then
			Utility.Notify("Shoot remote not found in Gun.", "Error", nil, "Cancel")
			return
		end
		local gunCFrame = gun:GetPivot()
		local targetCFrame = CFrame.new(predictedPos)
		local success, remoteError = pcall(function()
			shootRemote:FireServer(gunCFrame, targetCFrame)
		end)
		if success then
			Utility.Notify("Shot at " .. target.Name)
		else
			Utility.Notify("Failed to shoot: " .. tostring(remoteError), "Error", nil, "Cancel")
		end
	end
	SectionSheriffHero:AddButton({
		Title = "Shoot Target (Murderer/Other)",
		Callback = shootTarget,
	})
	SectionSheriffHero:AddKeybind("shootMurderer_keybind", {
		Title = "Shoot Murderer",
		Mode = "Toggle",
		Default = "F",
		Callback = function(Value)
			if not Value then
				return
			end
			shootTarget()
		end,
	})
	SectionMurderer:AddButton({
		Title = "Kill Nearest Player",
		Callback = function()
			if FindRole("Murderer") ~= LocalPlayer then
				Utility.Notify("You are not the Murderer.", "Error", nil, "Cancel")
				return
			end
			if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Knife") then
				if LocalPlayer.Backpack:FindFirstChild("Knife") then
					LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):EquipTool(LocalPlayer.Backpack.Knife)
					task.wait(0.2)
				else
					Utility.Notify("You don't have the knife.", "Error", nil, "Cancel")
					return
				end
			end
			local nearestPlayer, minDist = nil, math.huge
			for _, p in ipairs(Players:GetPlayers()) do
				if
				p ~= LocalPlayer
				and p.Character
				and p.Character:FindFirstChild("HumanoidRootPart")
				and (FindRole("Murderer") ~= p and FindRole("Sheriff") ~= p and FindRole("Hero") ~= p)
			then
					local dist = (
					LocalPlayer.Character.HumanoidRootPart.Position - p.Character.HumanoidRootPart.Position
				).Magnitude
					if dist < minDist then
						minDist = dist
						nearestPlayer = p
					end
				end
			end
			if not nearestPlayer then
				Utility.Notify("No nearby players (non-role).", "Error", nil, "Cancel")
				return
			end
			if Options.simulateKnifeThrow and Options.simulateKnifeThrow.Value then
				local shootOffsetVal = Options.shootOffset and Options.shootOffset.Value or 2.8
				local predictedPos, err = GetPredictedPosition(nearestPlayer, shootOffsetVal)
				if err then
					Utility.Notify(err, "Prediction Error", nil, "Cancel")
					return
				end
				pcall(function()
					LocalPlayer.Character.Knife.Throw:FireServer(LocalPlayer.Character.Knife:GetPivot(), predictedPos)
					Utility.Notify("Threw knife at " .. nearestPlayer.Name)
				end)
			else
				local targetHRP = nearestPlayer.Character.HumanoidRootPart
				local myHRP = LocalPlayer.Character.HumanoidRootPart
				local originalCFrame = targetHRP.CFrame
				local originalAnchored = targetHRP.Anchored
				targetHRP.Anchored = true
				targetHRP.CFrame = myHRP.CFrame * CFrame.new(0, 0, -2)
				task.wait(0.05)
				local knife = LocalPlayer.Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
if knife and knife:FindFirstChild("Events") and knife.Events:FindFirstChild("KnifeStabbed") then
    knife.Events.KnifeStabbed:FireServer()
end				task.wait(0.05)
				if targetHRP and targetHRP.Parent then
					targetHRP.CFrame = originalCFrame
					targetHRP.Anchored = originalAnchored
				end
				Utility.Notify("Stabbed " .. nearestPlayer.Name)
			end
		end,
	})
	SectionMurderer:AddToggle("killAura_toggle", {
		Title = "Kill Aura",
		Default = false,
		Callback = function(state)
			Utility.Notify("Kill Aura: " .. (state and "Enabled" or "Disabled"))
			if state then
				if killAuraConnection and killAuraConnection.Connected then
					killAuraConnection:Disconnect()
				end
				killAuraConnection = RunService.Heartbeat:Connect(function()
					if
					not (Options.killAura_toggle and Options.killAura_toggle.Value)
					or FindRole("Murderer") ~= LocalPlayer
					or not LocalPlayer.Character
					or not LocalPlayer.Character:FindFirstChild("Knife")
				then
						return
					end
					local distance = Options.killAuraDistance_slider and Options.killAuraDistance_slider.Value
					or 7
					for _, player in ipairs(Players:GetPlayers()) do
						if
						player ~= LocalPlayer
						and player.Character
						and player.Character:FindFirstChild("HumanoidRootPart")
						and (
							FindRole("Murderer") ~= player
							and FindRole("Sheriff") ~= player
							and FindRole("Hero") ~= player
						)
					then
							local myHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
							if not myHRP then
								return
							end
							local targetHRP = player.Character.HumanoidRootPart
							if (targetHRP.Position - myHRP.Position).Magnitude < distance then
								local originalCFrame = targetHRP.CFrame
								local originalAnchored = targetHRP.Anchored
								targetHRP.Anchored = true
								targetHRP.CFrame = myHRP.CFrame * CFrame.new(0, 0, -2)
								task.wait(0.05)
								local knife = LocalPlayer.Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
if knife and knife:FindFirstChild("Events") and knife.Events:FindFirstChild("KnifeStabbed") then
    knife.Events.KnifeStabbed:FireServer()
end								task.wait(0.05)
								if targetHRP and targetHRP.Parent then
									targetHRP.CFrame = originalCFrame
									targetHRP.Anchored = originalAnchored
								end
								return
							end
						end
					end
				end)
			elseif killAuraConnection and killAuraConnection.Connected then
				killAuraConnection:Disconnect()
			end
		end,
	})
	SectionMurderer:AddSlider("killAuraDistance_slider", {
		Title = "Kill Aura Distance",
		Default = 7,
		Min = 1,
		Max = 20,
		Rounding = 0,
		Callback = function(value)
		end,
	})
	SectionMurderer:AddButton({
		Title = "Kill Everyone",
		Callback = function()
			if FindRole("Murderer") ~= LocalPlayer then
				Utility.Notify("You are not the Murderer.", "Error", nil, "Cancel")
				return
			end
			if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("Knife") then
				if LocalPlayer.Backpack:FindFirstChild("Knife") then
					LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):EquipTool(LocalPlayer.Backpack.Knife)
					task.wait(0.2)
				else
					Utility.Notify("You don't have the knife.", "Error", nil, "Cancel")
					return
				end
			end
			local originalStates = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if
				player ~= LocalPlayer
				and player.Character
				and player.Character:FindFirstChild("HumanoidRootPart")
			then
					local hrp = player.Character.HumanoidRootPart
					originalStates[player] = {
						CFrame = hrp.CFrame,
						Anchored = hrp.Anchored,
					}
					hrp.Anchored = true
					hrp.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -1)
					task.wait(0.01)
				end
			end
			local knife = LocalPlayer.Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
if knife and knife:FindFirstChild("Events") and knife.Events:FindFirstChild("KnifeStabbed") then
    knife.Events.KnifeStabbed:FireServer()
end			task.wait(0.1)
			for player, s in pairs(originalStates) do
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					player.Character.HumanoidRootPart.CFrame = s.CFrame
					player.Character.HumanoidRootPart.Anchored = s.Anchored
				end
			end
			Utility.Notify("Attempted to kill everyone.")
		end,
	})
	SectionCombatSettings:AddParagraph({
		Title = "Combat Settings & Prediction",
		Content = "These settings refine how the script aims at moving targets.\n'Aim Prediction Offset' dictates how far ahead to aim.\n'Ping Multiplier' dynamically adjusts this offset based on your current network latency (ping) for better accuracy.",
	})
	SectionCombatSettings:AddToggle("simulateKnifeThrow", {
		Title = "Simulate Knife Throw for Kill Nearest",
		Default = false,
		Callback = function(state)
			Utility.Notify("Simulate Knife Throw: " .. (state and "Enabled" or "Disabled"))
		end,
	})
	SectionCombatSettings:AddSlider("shootOffset", {
		Title = "Aim Prediction Offset",
		Default = 2.8,
		Min = 0,
		Max = 10,
		Rounding = 1,
		Callback = function(val)
		end,
	})
	SectionCombatSettings:AddSlider("offsetToPingMult", {
		Title = "Ping Multiplier for Prediction",
		Default = 1,
		Min = 0,
		Max = 5,
		Rounding = 1,
		Callback = function(val)
		end,
	})
end

do
	local VisualsTab = Tabs.Visuals
	local SectionPlayerESP = VisualsTab:AddSection("Player ESP")
	local SectionObjectESP = VisualsTab:AddSection("Object ESP")
	if not espContainer then
		espContainer = ESPIndicatorModule.new({
			ArrowEdgePadding = 70,
			ArrowShowDistanceText = false,
		})
	end
	ReloadPlayerESP = function()
		if not espContainer then
			return
		end
		espContainer:RemoveGroup("players")
		if not (Options.playerESP and Options.playerESP.Value) then
			return
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				local role = "Innocent"
				local color = Color3.new(0, 1, 0.03)
				local showArrow = false
				local labelText = player.DisplayName
				local arrowMinDist = 0
				if player == FindRole("Murderer") then
					role = "Murderer"
					color = Color3.new(1, 0, 0.015)
					showArrow = true
					labelText = "Murderer"
					arrowMinDist = 99999
				elseif player == FindRole("Sheriff") or player == FindRole("Hero") then
					role = "Sheriff/Hero"
					color = Color3.new(0, 0.6, 1)
					labelText = "Sheriff/Hero"
					showArrow = true
					arrowMinDist = 0
				end
				espContainer:Add(player.Character, {
					AccentColor = color,
					ArrowShow = showArrow,
					ArrowMinDistance = arrowMinDist,
					ArrowSize = UDim2.new(0, 35, 0, 35),
					LabelText = labelText,
					ShowLabel = (role ~= "Innocent" or Options.showInnocentNamesESP.Value),
					GroupName = "players",
				})
			end
		end
	end
	if
	game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Gameplay")
	and game:GetService("ReplicatedStorage").Remotes.Gameplay:FindFirstChild("PlayerDataChanged")
then
		game:GetService("ReplicatedStorage").Remotes.Gameplay.PlayerDataChanged.OnClientEvent:Connect(function(data)
			playerData = data
			if Options.playerESP and Options.playerESP.Value then
				ReloadPlayerESP()
			end
		end)
	end
	SectionPlayerESP:AddToggle("playerESP", {
		Title = "Enable Player ESP",
		Default = false,
		Callback = function(state)
			ReloadPlayerESP()
			Utility.Notify("Player ESP: " .. (state and "Enabled" or "Disabled"))
		end,
	})
	SectionPlayerESP:AddToggle("showInnocentNamesESP", {
		Title = "Show Innocent Names (ESP)",
		Default = false,
		Description = "If Player ESP is on, this will show names for Innocents too.",
		Callback = function(state)
			ReloadPlayerESP()
			Utility.Notify("Show Innocent Names ESP: " .. (state and "Enabled" or "Disabled"))
		end,
	})
	SectionObjectESP:AddToggle("gunDropESP", {
		Title = "Dropped Gun ESP",
		Default = false,
		Callback = function(state)
			if not espContainer then
				return
			end
			if state then
				local map = getMap()
				if map then
					for _, item in ipairs(map:GetChildren()) do
						if item.Name == "GunDrop" then
							espContainer:Add(item, {
								AccentColor = Color3.new(0.95, 1, 0.07),
								ArrowShow = true,
								ArrowMinDistance = 99999,
								ArrowSize = UDim2.new(0, 30, 0, 30),
								LabelText = "Dropped Gun!",
								ShowLabel = true,
								GroupName = "gun",
							})
						end
					end
				end
			else
				espContainer:RemoveGroup("gun")
			end
			Utility.Notify("Dropped Gun ESP: " .. (state and "Enabled" or "Disabled"))
		end,
	})
	SectionObjectESP:AddToggle("trapDetection", {
		Title = "Trap ESP",
		Default = false,
		Callback = function(state)
			if not espContainer then
				return
			end
			if state then
				for _, v in ipairs(workspace:GetDescendants()) do
					if v.Name == "Trap" and v.Parent and v.Parent:IsDescendantOf(workspace) then
						v.Transparency = 0
						espContainer:Add(v, {
							AccentColor = Color3.fromRGB(255, 100, 0),
							ShowLabel = true,
							LabelText = "Trap",
							GroupName = "traps",
						})
					end
				end
			else
				espContainer:RemoveGroup("traps")
			end
			Utility.Notify("Trap ESP: " .. (state and "Enabled" or "Disabled"))
		end,
	})
end

do
	local AutomationTab = Tabs.Automation
	local SectionCoin = AutomationTab:AddSection("Coin Collection")
	SectionCoin:AddParagraph({
		Title = "Coin Collection",
		Content = "When enabled, this feature will automatically navigate your character to the nearest coin on the map to collect it. Your character will move.",
	})
	SectionCoin:AddSlider("coinFarmSpeed_slider", {
		Title = "Coin Farm Speed (studs/sec)",
		Description = "Adjusts how fast your character moves to collect coins.",
		Default = 10,
		Min = 5,
		Max = 25,
		Rounding = 0,
		Callback = function(value)
		end,
	})
	SectionCoin:AddToggle("coinMagnet_loop_toggle", {
		Title = "Coin Magnet (Auto Collect)",
		Default = false,
		Callback = function(state)
			Utility.Notify("Coin Magnet: " .. (state and "Enabled" or "Disabled"))
			local coinAutoCollect = state
			if state then
				if coinMagnetThread then
					task.cancel(coinMagnetThread)
				end
				coinMagnetThread = task.spawn(function()
					local lastCharacter = nil
					local characterParts = {}
					local fireTouch = rawget(_G, "firetouchinterest") or firetouchinterest
					local activeTween = nil
					local activeTarget = nil
					while coinAutoCollect and LocalPlayer and LocalPlayer.Character do
						task.wait(0.02)
						local character = LocalPlayer.Character
						if character ~= lastCharacter then
							characterParts = getCharacterBaseParts(character)
							lastCharacter = character
						end
						local hrp = character and character:FindFirstChild("HumanoidRootPart")
						if not hrp then
							continue
						end
						local map = getMap()
						if not map then
							continue
						end
						local coinContainer = map:FindFirstChild("CoinContainer")
						if coinContainer ~= coinCache.container then
							bindCoinCache(coinContainer)
						elseif coinContainer == nil then
							clearCoinCache()
						end
						if #coinCache.list == 0 then
							continue
						end
					local closestCoin
					local closestPivot
					local shortestDistance = math.huge
						for _, coin in ipairs(coinCache.list) do
							if coin and coin.Parent and coin:GetAttribute("SolunaSkip") ~= true then
								local coinPivot = (coin.IsA and coin:IsA("BasePart") and coin.CFrame or coin:GetPivot())
								local coinPos = coinPivot.Position
								local dist = (hrp.Position - coinPos).Magnitude
								if dist < shortestDistance then
									shortestDistance = dist
									closestCoin = coin
									closestPivot = CFrame.new(coinPos)
								end
							end
						end
						if closestCoin and closestCoin.Parent then
							local pivot = closestPivot or closestCoin:GetPivot()
							local heightOffset = math.clamp((hrp.Size and hrp.Size.Y or 0) * 0.5, 0.75, 2)
							local targetYOffset = math.max(heightOffset - 0.4, 0)
							local targetCFrame = pivot * CFrame.new(0, targetYOffset, 0)
							local coinPart = closestCoin:IsA("BasePart") and closestCoin or closestCoin:FindFirstChildWhichIsA("BasePart", true)
							local distance = (hrp.Position - targetCFrame.Position).Magnitude
							local retarget = activeTarget ~= closestCoin
								or not activeTween
								or activeTween.PlaybackState ~= Enum.PlaybackState.Playing

							if retarget then
								if activeTween then
									activeTween:Cancel()
								end
								activeTarget = closestCoin
								local speedOption = Options.coinFarmSpeed_slider
								local speed = speedOption and speedOption.Value or 15
								local duration = math.clamp(distance / math.max(speed, 1), 0.05, 2.5)
								activeTween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
									CFrame = targetCFrame
								})
								activeTween:Play()
							end
							if distance <= 4 and coinPart then
								touchCoinTargets(coinPart, characterParts, fireTouch)
							end
							if distance <= 1.5 then
								if coinPart then
									touchCoinTargets(coinPart, characterParts, fireTouch)
								end
								removeCoinFromCache(closestCoin)
								activeTarget = nil
								if activeTween then
									activeTween:Cancel()
									activeTween = nil
								end
							end
						else
							if activeTween then
								activeTween:Cancel()
								activeTween = nil
							end
							activeTarget = nil
						end
					end
					if activeTween then
						activeTween:Cancel()
						activeTween = nil
					end
				end)
			else
				if coinMagnetThread then
					task.cancel(coinMagnetThread)
					coinMagnetThread = nil
				end
				clearCoinCache()
			end
		end,
	})
	local SectionGun = AutomationTab:AddSection("Gun Pickup")
	SectionGun:AddParagraph({
		Title = "Gun Pickup",
		Content = "If the Sheriff drops the gun, enabling this will automatically attempt to pick it up.",
	})
		SectionGun:AddToggle("autoGetGun_toggle_farm", {
		Title = "Auto-Get Dropped Gun",
		Default = false,
		Callback = function(state)
			Utility.Notify("Auto-Get Dropped Gun: " .. (state and "Enabled" or "Disabled"))
			if state then
				local map = getMap()
				if map and map:FindFirstChild("GunDrop") then
					Utility.Notify("Gun already on ground, attempting auto-pickup...", "Auto", 3)
					task.spawn(function()
						Utility.pickupGun()
					end)
				end
			end
		end,
	})
	SectionGun:AddKeybind("manualGetGun_keybind", {
		Title = "Manually Get Dropped Gun",
		Mode = "Hold",
		Default = "G",
		Callback = function(isHeld)
			if isHeld then
				Utility.pickupGun()
			end
		end,
	})
end

do
	local TeleportTab = Tabs.Teleport
	local SectionTeleports = TeleportTab:AddSection("Game Teleportation")
	local SectionSafeZone = TeleportTab:AddSection("Safe Zone")

SectionTeleports:AddButton({
	Title = "Teleport to Lobby",
	Callback = function()
		if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			local nikilis = workspace.Lobby.Lobby.Nikilis
local targetCFrame = nikilis.PrimaryPart and nikilis.PrimaryPart.CFrame or nikilis:GetPivot()
LocalPlayer.Character.HumanoidRootPart.CFrame = targetCFrame
		else
			Utility.Notify("Your character is not available.", "Error", nil, "Cancel")
		end
	end,
})
	SectionTeleports:AddButton({
		Title = "Teleport to Map Spawn",
		Callback = function()
			local m = getMap()
			if m and m:FindFirstChild("Spawns") then
				local s = m.Spawns:GetChildren()
				if #s > 0 then
					local rS = s[math.random(1, #s)]
					if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
						LocalPlayer.Character.HumanoidRootPart.CFrame = rS.CFrame
					else
						Utility.Notify("Your character is not available.", "Error", nil, "Cancel")
					end
				else
					Utility.Notify("No spawns found on map.", "Error", nil, "Cancel")
				end
			else
				Utility.Notify("Map not loaded or no spawns folder.", "Error", nil, "Cancel")
			end
		end,
	})

	SectionSafeZone:AddButton({
		Title = "Teleport to Safe Zone",
		Callback = function()
			if not safeZonePart or not safeZonePart.Parent then
				Utility.Notify("Safe Zone does not exist. Try re-creating it.", "Error", nil, "Cancel")
				return
			end
			if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local myHRP = LocalPlayer.Character.HumanoidRootPart
				local targetPosition = safeZonePart.Position + Vector3.new(0, 5, 0)
				myHRP.CFrame = CFrame.new(targetPosition)
				Utility.Notify("Teleported to Safe Zone.", "Success")
			else
				Utility.Notify("Your character is not available to teleport.", "Error", nil, "Cancel")
			end
		end,
	})
	SectionSafeZone:AddButton({
		Title = "Re-create Safe Zone",
		Callback = function()
			createSafeZone()
		end,
	})
end

do
    local MiscTab = Tabs.Misc
    local SectionInformation = MiscTab:AddSection("Game Information")
    local SectionSpectateSystem = MiscTab:AddSection("Spectate System")
    local SectionClient = MiscTab:AddSection("Client")

	SectionInformation:AddButton({
		Title = "Copy Murderer Username",
		Callback = function()
			local m = FindRole("Murderer")
			if m and typeof(setclipboard) == "function" then
				setclipboard(m.Name)
				Utility.Notify("Murderer username copied: " .. m.Name)
			else
				Utility.Notify("Murderer not found or setclipboard is not available.", "Error", nil, "Cancel")
			end
		end,
	})
	SectionInformation:AddButton({
		Title = "Copy Sheriff/Hero Username",
		Callback = function()
			local s = FindRole("Sheriff") or FindRole("Hero")
			if s and typeof(setclipboard) == "function" then
				setclipboard(s.Name)
				Utility.Notify("Sheriff/Hero username copied: " .. s.Name)
			else
				Utility.Notify("Sheriff/Hero not found or setclipboard is not available.", "Error", nil, "Cancel")
			end
		end,
	})
	SectionInformation:AddButton({
		Title = "Send Roles to Chat",
		Callback = function()
			local textchannels = game:GetService("TextChatService"):WaitForChild("TextChannels"):GetChildren()
			for _, tc in ipairs(textchannels) do
				if tc.Name ~= "RBXSystem" then
					local murd = FindRole("Murderer")
					local sher = FindRole("Sheriff") or FindRole("Hero")
					local murdN = murd and murd.Name or "-"
					local sherN = sher and sher.Name or "-"
					tc:SendAsync(string.format("Murderer: %s | Sheriff/Hero: %s | [ Soluna ]", murdN, sherN))
					Utility.Notify("Roles sent to chat.")
					return
				end
			end
		end,
	})

	SectionInformation:AddToggle("ignoreKnifeThrows_toggle", {
		Title = "Ignore Knife Throws (- Experimental)",
		Default = false,
		Callback = function(state)
			Utility.Notify("Ignore Knife Throws: " .. (state and "Enabled" or "Disabled"))
		end,
	})

    local spectate_data = {
        player_list = {},
        current_index = 0,
        is_active = false,
    }
    local function update_spectate_target()
        if not spectate_data.is_active or #spectate_data.player_list == 0 then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                workspace.CurrentCamera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            end
            return
        end
        local target_player = spectate_data.player_list[spectate_data.current_index]
        if target_player and target_player.Character and target_player.Character:FindFirstChildOfClass("Humanoid") then
            workspace.CurrentCamera.CameraSubject = target_player.Character:FindFirstChildOfClass("Humanoid")
            Utility.Notify("Now spectating: " .. target_player.Name, "Spectate")
        else
            Utility.Notify(
            (target_player and target_player.Name or "Player") .. " has no character. Skipping.",
            "Spectate",
            2
        )
            table.remove(spectate_data.player_list, spectate_data.current_index)
            if #spectate_data.player_list == 0 then
                spectate_data.is_active = false
                spectate_data.current_index = 0
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                    workspace.CurrentCamera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                end
                Utility.Notify("No more players to spectate. Stopping.", "Spectate")
                return
            end
            if spectate_data.current_index > #spectate_data.player_list then
                spectate_data.current_index = 1
            end
            update_spectate_target()
        end
    end
    SectionSpectateSystem:AddButton({
        Title = "Start/Refresh Spectate List",
        Description = "Prepares or updates the list of players to spectate.",
        Callback = function()
            spectate_data.player_list = Players:GetPlayers()
            if #spectate_data.player_list == 0 then
                Utility.Notify("No players in server.", "Spectate Error", 3, "Cancel")
                spectate_data.is_active = false
                spectate_data.current_index = 0
                return
            end
            spectate_data.current_index = 1
            spectate_data.is_active = true
            Utility.Notify(
            "Spectate list refreshed. Found " .. #spectate_data.player_list .. " players. Spectating first player.",
            "Spectate"
        )
            update_spectate_target()
        end,
    })
    SectionSpectateSystem:AddButton({
        Title = "Spectate Next Player",
        Callback = function()
            if not spectate_data.is_active or #spectate_data.player_list == 0 then
                Utility.Notify("Start spectating or refresh list first.", "Spectate Info", 3)
                return
            end
            spectate_data.current_index = spectate_data.current_index + 1
            if spectate_data.current_index > #spectate_data.player_list then
                spectate_data.current_index = 1
            end
            update_spectate_target()
        end,
    })
    SectionSpectateSystem:AddButton({
        Title = "Spectate Previous Player",
        Callback = function()
            if not spectate_data.is_active or #spectate_data.player_list == 0 then
                Utility.Notify("Start spectating or refresh list first.", "Spectate Info", 3)
                return
            end
            spectate_data.current_index = spectate_data.current_index - 1
            if spectate_data.current_index < 1 then
                spectate_data.current_index = #spectate_data.player_list
            end
            update_spectate_target()
        end,
    })
    SectionSpectateSystem:AddButton({
        Title = "Stop Spectating",
        Callback = function()
            if spectate_data.is_active then
                spectate_data.is_active = false
                spectate_data.current_index = 0
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                    workspace.CurrentCamera.CameraSubject = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                end
                Utility.Notify("Spectating stopped.", "Spectate")
            else
                Utility.Notify("Not currently spectating.", "Spectate Info", 3)
            end
        end,
    })

    SectionClient:AddButton({
        Title = "Get Ping",
        Callback = function()
            Utility.Notify("Your ping: " .. math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5) .. "ms")
        end,
    })
end

do
	local TrollTab = Tabs.Trolling
	local SectionFling = TrollTab:AddSection("General Player Fling")
	SectionFling:AddParagraph({
		Title = "Player Fling",
		Content = "This feature attempts to fling the selected player using a common method. Results can vary. Use responsibly.",
	})
	local trollPlayerNames = {}
	local function refreshTrollPlayerList()
		table.clear(trollPlayerNames)
		local foundPlayers = false
		for _, p in ipairs(Players:GetPlayers()) do
			table.insert(trollPlayerNames, p.Name)
			foundPlayers = true
		end
		if not foundPlayers then
			table.insert(trollPlayerNames, "No players found")
		end
		if Options.troll_target_player_dropdown then
			local currentSelection = Options.troll_target_player_dropdown.Value
			local newSelection = trollPlayerNames[1]
			if table.find(trollPlayerNames, currentSelection) then
				newSelection = currentSelection
			end
            Options.troll_target_player_dropdown:SetValues(trollPlayerNames)
			Options.troll_target_player_dropdown:SetValue(newSelection)
		end
		return trollPlayerNames
	end
	refreshTrollPlayerList()
	SectionFling:AddDropdown("troll_target_player_dropdown", {
		Title = "Select Player to Troll",
		Values = trollPlayerNames,
		Multi = false,
		Default = trollPlayerNames[1] or "No players found",
		Callback = function(selectedName)
			local p = Players:FindFirstChild(selectedName)
			if p then
				soluna_troll_target_selectedPlayer = p
			else
				soluna_troll_target_selectedPlayer = nil
				if selectedName ~= "No players found" then
					Utility.Notify("Could not find player: " .. selectedName, "Error")
				end
			end
		end,
	})
	SectionFling:AddButton({
		Title = "Refresh Troll Player List",
		Callback = function()
			refreshTrollPlayerList()
			Utility.Notify("Troll player list refreshed.")
		end,
	})
	if #trollPlayerNames > 0 and trollPlayerNames[1] ~= "No players found" then
		soluna_troll_target_selectedPlayer = Players:FindFirstChild(trollPlayerNames[1])
	end
	SectionFling:AddButton({
		Title = "Fling Selected Player",
		Callback = function()
			local target = soluna_troll_target_selectedPlayer
			if not target then
				Utility.Notify("No target selected.", "Error", nil, "Cancel")
				return
			end
			Utility.miniFling(target)
		end,
	})
	SectionFling:AddButton({
		Title = "Fling Murderer (MM2)",
		Callback = function()
			local murderer = FindRole("Murderer")
			if not murderer then
				Utility.Notify("No Murderer found to fling.", "Error")
				return
			end
			Utility.miniFling(murderer)
		end,
	})
	SectionFling:AddButton({
		Title = "Fling Sheriff/Hero (MM2)",
		Callback = function()
			local sheriff = FindRole("Sheriff") or FindRole("Hero")
			if not sheriff then
				Utility.Notify("No Sheriff/Hero found to fling.", "Error")
				return
			end
			Utility.miniFling(sheriff)
		end,
	})
	
	local SectionRiskyFeatures = TrollTab:AddSection("High-Risk Features")
	SectionRiskyFeatures:AddParagraph({
		Title = "God Mode (- Highly Risky)",
		Content = "EXPERIMENTAL: Attempts to make you invincible. This is very unstable, likely to cause crashes, kicks, or may not work at all. Use at your own extreme risk. A character reset is usually needed to undo this.",
	})
	SectionRiskyFeatures:AddButton({
		Title = "Activate God Mode",
		Callback = function()
			Utility.Notify("God Mode is highly unstable and may crash/kick.", "Warning", 5)
			task.wait(1)
			local Cam = workspace.CurrentCamera
			local Char = LocalPlayer.Character
			local Human = Char and Char:FindFirstChildWhichIsA("Humanoid")
			if not Human then
				Utility.Notify("Humanoid not found.", "Error", nil, "Cancel")
				return
			end
			local Pos = Cam.CFrame
			local nHuman = Human:Clone()
			nHuman.Parent, LocalPlayer.Character = Char, nil
			nHuman:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			nHuman:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			nHuman:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			Human:Destroy()
			LocalPlayer.Character = Char
			task.wait()
			Cam.CameraSubject = nHuman
			Cam.CFrame = Pos
			nHuman.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			local Script = Char:FindFirstChild("Animate")
			if Script then
				Script.Disabled = true
				task.wait()
				Script.Disabled = false
			end
			nHuman.Health = nHuman.MaxHealth
			Utility.Notify("God Mode activated (experimental).")
		end,
	})
	SectionRiskyFeatures:AddParagraph({
		Title = "Hold Everyone Hostage (- Murderer)",
		Content = "As Murderer, this teleports all other players near you and anchors them. Useful for 'Kill Everyone' or 'Kill Nearest'. They remain anchored until death or round end.",
	})
	SectionRiskyFeatures:AddButton({
		Title = "Hold Everyone Hostage",
		Callback = function()
			if FindRole("Murderer") ~= LocalPlayer then
				Utility.Notify("You are not the Murderer.", "Error", nil, "Cancel")
				return
			end
			if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
				Utility.Notify("Your character is not available.", "Error", nil, "Cancel")
				return
			end
			local myPos = LocalPlayer.Character.HumanoidRootPart.Position
			for _, player in ipairs(Players:GetPlayers()) do
				if
				player ~= LocalPlayer
				and player.Character
				and player.Character:FindFirstChild("HumanoidRootPart")
			then
					player.Character.HumanoidRootPart.Anchored = true
					player.Character.HumanoidRootPart.CFrame =
					CFrame.new(myPos + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2)))
				end
			end
			Utility.Notify("Everyone gathered. Use Kill Everyone or Kill Nearest.")
		end,
	})
end

do
	local SettingsTab = Tabs.Settings
	local SectionScriptSettings = SettingsTab:AddSection("UI & Script Settings")
	local SectionAbout = SettingsTab:AddSection("About & Credits")
	SectionScriptSettings:AddToggle("acrylicBlurToggle", {
		Title = "UI Blur (Acrylic)",
		Default = SolunaWindow.Acrylic,
		Callback = function(bool)
			Fluent:ToggleAcrylic(bool)
			Utility.Notify((bool and "Enabled" or "Disabled") .. " UI Blur")
		end,
	})
	SectionScriptSettings:AddToggle("enableNotifications", {
		Title = "Enable Notifications",
		Default = true,
		Callback = function(bool)
			Utility.Notify((bool and "Enabled" or "Disabled") .. " Notifications")
		end,
	})
	SectionAbout:AddButton({
		Title = "Join our Discord",
		Callback = function()
			if typeof(setclipboard) == "function" then
				setclipboard("https://discord.gg/e52GujVvbN")
				Utility.Notify("Discord link copied to clipboard!")
			else
				Utility.Notify("Could not copy link. Your executor may not support 'setclipboard'.", "Error")
			end
		end,
	})
	SectionAbout:AddParagraph({
		Title = "Soluna",
		Content = "Soluna Script Hub for Murder Mystery 2.",
	})
	SectionAbout:AddParagraph({
		Title = "discord.gg/e52GujVvbN",
		Content = "Script by Soluna Development Team.",
	})
end

Players.PlayerAdded:Connect(function(player)
	if Options.playerESP
	and Options.playerESP.Value
	and espContainer
	and typeof(ReloadPlayerESP) == "function"
then
		task.wait(0.1)
		ReloadPlayerESP()
	end
	player.CharacterAdded:Connect(function(character)
		if Options.playerESP
		and Options.playerESP.Value
		and espContainer
		and typeof(ReloadPlayerESP) == "function"
	then
			task.wait(0.1)
			ReloadPlayerESP()
		end
	end)
	player.CharacterRemoving:Connect(function(character)
		if espContainer and character then
			espContainer:Remove(character)
		end
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	if espContainer and player.Character then
		espContainer:Remove(player.Character)
	end
	if Options.playerESP
	and Options.playerESP.Value
	and espContainer
	and typeof(ReloadPlayerESP) == "function"
then
		ReloadPlayerESP()
	end
end)
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function(character)
		if Options.playerESP
		and Options.playerESP.Value
		and espContainer
		and typeof(ReloadPlayerESP) == "function"
	then
			task.wait(0.1)
			ReloadPlayerESP()
		end
	end)
	player.CharacterRemoving:Connect(function(character)
		if espContainer and character then
			espContainer:Remove(character)
		end
	end)
end

workspace.DescendantAdded:Connect(function(child)
	if not espContainer then
		return
	end
	if
		Options.trapDetection
		and Options.trapDetection.Value
		and child.Name == "Trap"
		and child.Parent
		and child.Parent:IsDescendantOf(workspace)
	then
		child.Transparency = 0
		espContainer:Add(child, {
			AccentColor = Color3.fromRGB(255, 100, 0),
			ShowLabel = true,
			LabelText = "Trap",
			GroupName = "traps",
		})
		Utility.Notify("Murderer placed a trap!", "Alert", 3)
	end
	if child.Name == "GunDrop" and child:IsA("BasePart") then
		if Options.gunDropESP and Options.gunDropESP.Value then
			espContainer:Add(child, {
				AccentColor = Color3.new(0.95, 1, 0.07),
				ArrowShow = true,
				ArrowMinDistance = 99999,
				ArrowSize = UDim2.new(0, 30, 0, 30),
				LabelText = "Dropped Gun!",
				ShowLabel = true,
				GroupName = "gun",
			})
			Utility.Notify("Gun has been dropped!", "Alert")
		end

		if Options.autoGetGun_toggle_farm and Options.autoGetGun_toggle_farm.Value then
			Utility.Notify("Dropped gun detected, attempting auto-pickup...", "Auto", 2)
			task.spawn(function()
				Utility.pickupGun()
			end)
		end
	end
	if
		Options.ignoreKnifeThrows_toggle
		and Options.ignoreKnifeThrows_toggle.Value
		and child.Name == "ThrowingKnife"
	then
		child:Destroy()
		Utility.Notify("Blocked a knife throw!", "Protection", 2)
	end
end)
workspace.DescendantRemoving:Connect(function(child)
	if not espContainer then
		return
	end
	local trapTargets = espContainer:GetGroupTargets("traps")
	if child.Name == "Trap" and table.find(trapTargets, child) then
		espContainer:Remove(child)
	end
	local gunTargets = espContainer:GetGroupTargets("gun")
	if child.Name == "GunDrop" and table.find(gunTargets, child) then
		espContainer:Remove(child)
		Utility.Notify("Dropped gun picked up.", "Alert")
		task.wait(0.5)
		local newSheriff = FindRole("Sheriff") or FindRole("Hero")
		if newSheriff then
			Utility.Notify("New Sheriff/Hero: " .. newSheriff.Name, "Alert")
		end
		if _typeof(ReloadPlayerESP) == "function" then
			ReloadPlayerESP()
		end
	end
end)
workspace.ChildAdded:Connect(function(child)
	if
		Options.ignoreKnifeThrows_toggle
		and Options.ignoreKnifeThrows_toggle.Value
		and child.Name == "ThrowingKnife"
	then
		child:Destroy()
		Utility.Notify("Blocked a knife throw!", "Protection", 2)
	end
end)

SolunaWindow:SelectTab(1)
task.spawn(createSafeZone)

Fluent:Notify({
	Title = "Soluna",
	Content = "Soluna Script Loaded! Safe Zone feature added.",
	Duration = 5,
})

if Options.playerESP and Options.playerESP.Value then
	task.wait(0.5)
	ReloadPlayerESP()
end
if Options.gunDropESP and Options.gunDropESP.Value then
	if espContainer then
		local map = getMap()
		if map then
			for _, item in ipairs(map:GetChildren()) do
				if item.Name == "GunDrop" then
					espContainer:Add(item, {
						AccentColor = Color3.new(0.95, 1, 0.07),
						ArrowShow = true,
						ArrowMinDistance = 99999,
						ArrowSize = UDim2.new(0, 30, 0, 30),
						LabelText = "Dropped Gun!",
						ShowLabel = true,
						GroupName = "gun",
					})
				end
			end
		end
	end
end
if Options.trapDetection and Options.trapDetection.Value then
	if espContainer then
		for _, v in ipairs(workspace:GetDescendants()) do
			if v.Name == "Trap" and v.Parent and v.Parent:IsDescendantOf(workspace) then
				v.Transparency = 0
				espContainer:Add(v, {
					AccentColor = Color3.fromRGB(255, 100, 0),
					ShowLabel = true,
					LabelText = "Trap",
					GroupName = "traps",
				})
			end
		end
	end
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("Soluna")
SaveManager:SetFolder("Soluna/Murder Mystery 2")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()
