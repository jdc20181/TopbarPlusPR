local hasBecomeOldTheme = false
local previousInsetHeight = 0
return function(Icon)

	-- Has to be included for the time being due to this bug mentioned here:
	-- https://devforum.roblox.com/t/bug/2973508/7
	local GuiService = game:GetService("GuiService")
	local Players =  game:GetService("Players")
	local UserInputService = game:GetService("UserInputService")
	local StarterGui = game:GetService("StarterGui")
	local container = {}
	local Signal = require(script.Parent.Parent.Packages.GoodSignal)
	local insetChanged = Signal.new()
	local guiInset = GuiService:GetGuiInset()
	local startInset = 0
	local yDownOffset = 0
	local ySizeOffset = 0
	local checkCount = 0
	local isConsoleScreen = false
	local isUsingVR = false

	-- Health bar offset handling variables
	local healthBarOffset = -12 -- Default offset

	local function getHealthBarOffset()
		-- Check if health bar is enabled in CoreGui
		local isHealthBarEnabled = false
		local success, enabled = pcall(function()
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health)
		end)
		if success then
			isHealthBarEnabled = enabled
		end

		-- Don't apply offset on old topbar, console, or VR
		if Icon.isOldTopbar or isConsoleScreen or isUsingVR then
			return -12
		end

		-- Only apply offset if health bar is enabled
		if isHealthBarEnabled then
			-- Additional check for actual visibility (optional - can be refined)
			local localPlayer = Players.LocalPlayer
			if localPlayer and localPlayer.Character then
				local humanoid = localPlayer.Character:FindFirstChild("Humanoid")
				if humanoid then
					-- Conservative approach: only offset when health is below max
					local maxHealth = humanoid.MaxHealth
					local currentHealth = humanoid.Health
					local healthThreshold = maxHealth * 0.99

					if currentHealth < healthThreshold then
						return -212 -- Health bar width (200) + original padding (12)
					end
				end
			end
		end

		return -12 -- Default offset
	end

	local function checkInset(status)
		local currentHeight = GuiService.TopbarInset.Height
		local isOldTopbar = currentHeight <= 36


		-- These additional checks are needed to ensure *it is actually* the old topbar
		-- and not a client which takes a really long time to load
		-- There's unfortunately no APIs to do this a prettier way
		isConsoleScreen = GuiService:IsTenFootInterface()
		isUsingVR = UserInputService.VREnabled
		Icon.isOldTopbar = isOldTopbar
		checkCount += 1
		if currentHeight == 0 and status == nil then
			task.defer(function()
				task.wait(8)
				checkInset("ForceConvertToOld")
			end)
		elseif checkCount == 1 then
			task.delay(5, function()
				local localPlayer = Players.LocalPlayer
				localPlayer:WaitForChild("PlayerGui")
				if checkCount == 1 then
					checkInset()
				end
			end)
		end

		-- Conver to old theme if verified
		if Icon.isOldTopbar and not isConsoleScreen and not isUsingVR and hasBecomeOldTheme == false and (currentHeight ~= 0 or status == "ForceConvertToOld") then
			hasBecomeOldTheme = true
			task.defer(function()
				-- If oldtopbar, apply the Classic theme
				local themes = script.Parent.Parent.Features.Themes
				local Classic = require(themes.Classic)
				Icon.modifyBaseTheme(Classic)

				-- Also configure the oldtopbar correctly
				local function decideToHideTopbar()
					if GuiService.MenuIsOpen then
						Icon.setTopbarEnabled(false, true)
					else
						Icon.setTopbarEnabled()
					end
				end
				GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(decideToHideTopbar)
				decideToHideTopbar()
			end)
		end

		-- Modify the offsets slightly depending on device type
		guiInset = GuiService:GetGuiInset()
		startInset = if isOldTopbar then 12 else guiInset.Y - 50
		yDownOffset = if isOldTopbar then 2 else 0 --if isOldTopbar then 2 else 0 
		ySizeOffset = -2
		if isConsoleScreen then
			startInset = 10
			yDownOffset = 0 ---9
		end
		if GuiService.TopbarInset.Height == 0 and not hasBecomeOldTheme then
			yDownOffset += 13
			ySizeOffset = 50
		end

		-- Now inform other areas of the change
		insetChanged:Fire(guiInset)
		local insetHeight = guiInset.Y
		if insetHeight ~= previousInsetHeight then
			previousInsetHeight = insetHeight
			task.defer(function()
				Icon.insetHeightChanged:Fire(insetHeight)
			end)
		end

	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(checkInset)
	checkInset("FirstTime")

	local screenGui = Instance.new("ScreenGui")
	insetChanged:Connect(function()
		screenGui:SetAttribute("StartInset", startInset)
	end)
	screenGui.Name = "TopbarStandard"
	screenGui.Enabled = true
	screenGui.DisplayOrder = Icon.baseDisplayOrder
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	container[screenGui.Name] = screenGui
	Icon.baseDisplayOrderChanged:Connect(function()
		screenGui.DisplayOrder = Icon.baseDisplayOrder
	end)

	local holders = Instance.new("Frame")
	holders.Name = "Holders"
	holders.BackgroundTransparency = 1
	insetChanged:Connect(function()
		local holderY = if isUsingVR then 36 else 56
		local holderSize = if isConsoleScreen then UDim2.new(1, 0, 0, holderY) else UDim2.new(1, 0, 1, ySizeOffset)
		holders.Position = UDim2.new(0, 0, 0, yDownOffset)
		holders.Size = holderSize
	end)
	holders.Visible = true
	holders.ZIndex = 1
	holders.Parent = screenGui

	local screenGuiCenter = screenGui:Clone()
	local holdersCenter = screenGuiCenter.Holders
	local function updateCenteredHoldersHeight()
		holdersCenter.Size = UDim2.new(1, 0, 0, GuiService.TopbarInset.Height+ySizeOffset)
	end
	screenGuiCenter.Name = "TopbarCentered"
	screenGuiCenter.DisplayOrder = Icon.baseDisplayOrder
	screenGuiCenter.ScreenInsets = Enum.ScreenInsets.None
	Icon.baseDisplayOrderChanged:Connect(function()
		screenGuiCenter.DisplayOrder = Icon.baseDisplayOrder
	end)
	container[screenGuiCenter.Name] = screenGuiCenter

	insetChanged:Connect(updateCenteredHoldersHeight)
	updateCenteredHoldersHeight()

	local screenGuiClipped = screenGui:Clone()
	screenGuiClipped.Name = screenGuiClipped.Name.."Clipped"
	screenGuiClipped.DisplayOrder = (Icon.baseDisplayOrder + 1)
	Icon.baseDisplayOrderChanged:Connect(function()
		screenGuiClipped.DisplayOrder = (Icon.baseDisplayOrder + 1)
	end)
	container[screenGuiClipped.Name] = screenGuiClipped

	local screenGuiCenterClipped = screenGuiCenter:Clone()
	screenGuiCenterClipped.Name = screenGuiCenterClipped.Name.."Clipped"
	screenGuiCenterClipped.DisplayOrder = (Icon.baseDisplayOrder + 1)
	Icon.baseDisplayOrderChanged:Connect(function()
		screenGuiCenterClipped.DisplayOrder = (Icon.baseDisplayOrder + 1)
	end)
	container[screenGuiCenterClipped.Name] = screenGuiCenterClipped

	local holderReduction = -24
	local left = Instance.new("ScrollingFrame")
	left:SetAttribute("IsAHolder", true)
	left.Name = "Left"
	insetChanged:Connect(function()
		left.Position = UDim2.fromOffset(startInset, 0)
	end)
	left.Size = UDim2.new(1, holderReduction, 1, 0)
	left.BackgroundTransparency = 1
	left.Visible = true
	left.ZIndex = 1
	left.Active = false
	left.ClipsDescendants = true
	left.HorizontalScrollBarInset = Enum.ScrollBarInset.None
	left.CanvasSize = UDim2.new(0, 0, 1, -1) -- This -1 prevents a dropdown scrolling appearance bug
	left.AutomaticCanvasSize = Enum.AutomaticSize.X
	left.ScrollingDirection = Enum.ScrollingDirection.X
	left.ScrollBarThickness = 0
	left.BorderSizePixel = 0
	left.Selectable = false
	left.ScrollingEnabled = false--true
	left.ElasticBehavior = Enum.ElasticBehavior.Never
	left.Parent = holders

	local UIListLayout = Instance.new("UIListLayout")
	insetChanged:Connect(function()
		UIListLayout.Padding = UDim.new(0, startInset)
	end)
	UIListLayout.FillDirection = Enum.FillDirection.Horizontal
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	UIListLayout.Parent = left

	local center = left:Clone()
	insetChanged:Connect(function()
		center.UIListLayout.Padding = UDim.new(0, startInset)
	end)
	center.ScrollingEnabled = false
	center.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	center.Name = "Center"
	center.Parent = holdersCenter

	local right = left:Clone()
	insetChanged:Connect(function()
		right.UIListLayout.Padding = UDim.new(0, startInset)
		-- Update health bar offset each time inset changes
		local currentHealthBarOffset = getHealthBarOffset()
		right.Position = UDim2.new(1, currentHealthBarOffset, 0, 0)
	end)
	right.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	right.Name = "Right"
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.new(1, getHealthBarOffset(), 0, 0) -- Initial position with health bar consideration
	right.Parent = holders

	-- Setup health monitoring to trigger position updates when health changes
	local function setupHealthMonitoring()
		local localPlayer = Players.LocalPlayer
		if localPlayer then
			local function onCharacterAdded(character)
				local humanoid = character:WaitForChild("Humanoid", 5)
				if humanoid then
					-- When health changes, trigger inset change to update positions
					humanoid.HealthChanged:Connect(function()
						-- Fire inset changed to trigger right container position update
						insetChanged:Fire(guiInset)
					end)
				end
			end

			if localPlayer.Character then
				onCharacterAdded(localPlayer.Character)
			end
			localPlayer.CharacterAdded:Connect(onCharacterAdded)
		end
	end

	-- Setup monitoring for health bar changes
	local success, connection = pcall(function()
		return StarterGui.CoreGuiChangedSignal:Connect(function(coreGuiType, enabled)
			if coreGuiType == Enum.CoreGuiType.Health then
				-- Trigger position update when health bar is toggled
				insetChanged:Fire(guiInset)
			end
		end)
	end)

	-- Setup health monitoring
	if Players.LocalPlayer then
		setupHealthMonitoring()
	else
		Players:GetPropertyChangedSignal("LocalPlayer"):Connect(function()
			if Players.LocalPlayer then
				setupHealthMonitoring()
			end
		end)
	end

	-- This is important so that all elements update instantly
	insetChanged:Fire(guiInset)

	return container
end
