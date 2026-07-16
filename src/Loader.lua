local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local BASE_URL = "https://raw.githubusercontent.com/Soluna-Development/API/main/src/scripts/"

local DefaultSettings = {
	AutoLoadEnabled = false,
	TeleportLoadEnabled = false,
	DisableScriptLoader = false,
	SelectedVersion = nil,
	SelectedTab = "Rivals",
	ThemeColor = "Darker",
	ScriptToggles = {
		Rivals_Classic = false,
		Rivals_Modern = false,
		Rivals_Rewrite = false,
		Rivals_SkinChanger = false,
		Arsenal = false,
		Bladeball = false,
		MurderMystery2 = false,
        NightsInTheForest = false,
        TheWildWest = false,
        Doors = false,
		FlingThingsAndPeople = false,
	}
}

local Settings = table.clone(DefaultSettings)

local function loadSettings()
	local success, savedSettings = pcall(function()
		return HttpService:JSONDecode(readfile("SolunaLoaderSettings.json"))
	end)
	if success and savedSettings then
		for key, value in pairs(DefaultSettings) do
			if savedSettings[key] == nil then
				savedSettings[key] = value
			end
		end
		if not savedSettings.ScriptToggles then
			savedSettings.ScriptToggles = DefaultSettings.ScriptToggles
		else
			for key, value in pairs(DefaultSettings.ScriptToggles) do
				if savedSettings.ScriptToggles[key] == nil then
					savedSettings.ScriptToggles[key] = value
				end
			end
			if savedSettings.ScriptToggles.Soluna_Classic ~= nil then
				savedSettings.ScriptToggles.Soluna_Classic = nil
			end
			if savedSettings.ScriptToggles.Soluna_Modern ~= nil then
				savedSettings.ScriptToggles.Soluna_Modern = nil
			end
		end
		Settings = savedSettings
	end
end

local function saveSettings()
	writefile("SolunaLoaderSettings.json", HttpService:JSONEncode(Settings))
end

pcall(loadSettings)

if Settings.DisableScriptLoader then
	return
end

if Settings.AutoLoadEnabled then
	local function autoLoadSelectedScripts()
		if Settings.ScriptToggles.Rivals_Classic then
			loadstring(game:HttpGet(BASE_URL .. "Rivals/Classic.lua"))()
		end
		if Settings.ScriptToggles.Rivals_Modern then
			loadstring(game:HttpGet(BASE_URL .. "Rivals/Modern.lua"))()
		end
		if Settings.ScriptToggles.Rivals_Rewrite then
			loadstring(game:HttpGet(BASE_URL .. "Rivals/Rewrite.lua"))()
		end
		if Settings.ScriptToggles.Rivals_SkinChanger then
			loadstring(game:HttpGet(BASE_URL .. "Rivals/Skin-Changer.lua"))()
		end
		if Settings.ScriptToggles.Arsenal then
			loadstring(game:HttpGet(BASE_URL .. "Arsenal.lua"))()
		end
		if Settings.ScriptToggles.Bladeball then
			loadstring(game:HttpGet(BASE_URL .. "Bladeball.lua"))()
		end
		if Settings.ScriptToggles.MurderMystery2 then
			loadstring(game:HttpGet(BASE_URL .. "Murder-Mystery-2.lua"))()
		end
        if Settings.ScriptToggles.NightsInTheForest then
            loadstring(game:HttpGet(BASE_URL .. "99-Nights-in-the-Forest.lua"))()
        end
        if Settings.ScriptToggles.TheWildWest then
            loadstring(game:HttpGet(BASE_URL .. "The-Wild-West.lua"))()
        end
        if Settings.ScriptToggles.Doors then
            loadstring(game:HttpGet(BASE_URL .. "Doors.lua"))()
        end
		if Settings.ScriptToggles.FlingThingsAndPeople then
			loadstring(game:HttpGet(BASE_URL .. "Fling-Things-and-People.lua"))()
		end
	end
	autoLoadSelectedScripts()
	local anyScriptEnabled = false
	for _, enabled in pairs(Settings.ScriptToggles) do
		if enabled then
			anyScriptEnabled = true
			break
		end
	end
	if anyScriptEnabled then
		return
	end
end

if Settings.TeleportLoadEnabled then
	queue_on_teleport([[
        spawn(function()
            local Players = game:GetService("Players")
            local LocalPlayer = Players.LocalPlayer

            local function isGameLoaded()
                return game:IsLoaded() and LocalPlayer and LocalPlayer.Character and
                       LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and
                       workspace.CurrentCamera
            end

            if not LocalPlayer then
                LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
                LocalPlayer = Players.LocalPlayer
            end

            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.CharacterAdded:Wait()

                while not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") do
                    task.wait(0.1)
                end
            end

            if not isGameLoaded() then
                repeat task.wait(0.1) until isGameLoaded()
            end

            task.wait(1)

            pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/Soluna-Development/API/main/src/Loader.lua"))()
            end)
        end)
    ]])
end

local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow({
	Title = "Soluna",
	SubTitle = "Script Loader",
	TabWidth = 160,
	Size = UDim2.fromOffset(580, 460),
	Acrylic = true,
	Theme = Settings.ThemeColor or "Darker",
	MinSize = Vector2.new(470, 380),
	MinimizeKey = Enum.KeyCode.RightControl
})

Window:Dialog({
	Title = "Script Updated",
	Content = "Added Aimbot FFA and Fling Things and People! Updated all script URLs to new API repository.",
	Buttons = {
		{
			Title = "Okay",
			Callback = function()
				print("Pressed 'Okay'")
			end
		}
	}
})

local Tabs = {
	Info = Window:CreateTab({
		Title = "Info",
		Icon = "info"
	}),
	Rivals = Window:CreateTab({
		Title = "Rivals",
		Icon = "swords"
	}),
	FPS = Window:CreateTab({
		Title = "FPS Games",
		Icon = "target"
	}),
	Fighting = Window:CreateTab({
		Title = "Fighting",
		Icon = "swords"
	}),
	Misc = Window:CreateTab({
		Title = "Misc Games",
		Icon = "layout-grid"
	}),
	Theme = Window:CreateTab({
		Title = "Theme",
		Icon = "palette"
	}),
	Settings = Window:CreateTab({
		Title = "Settings",
		Icon = "settings"
	})
}

local selectedTabName = Settings.SelectedTab or "Rivals"
local selectedTabIndex = 1
local tabOrder = {
	"Rivals",
	"FPS",
	"Fighting",
	"Misc",
	"Theme",
	"Settings",
	"Info"
}
for i, tabName in pairs(tabOrder) do
	if tabName == selectedTabName then
		selectedTabIndex = i
		break
	end
end
Window:SelectTab(selectedTabIndex)

Tabs.Rivals:CreateParagraph("Rivals Scripts", {
	Title = "Rivals",
	Content = "Select from different Rivals scripts including Classic, Modern, Rewrite, and Skin Changer."
})

local rivalsClassicToggle = Tabs.Rivals:CreateToggle("RivalsClassicToggle", {
	Title = "Rivals Classic",
	Default = Settings.ScriptToggles.Rivals_Classic,
	Callback = function(Value)
		Settings.ScriptToggles.Rivals_Classic = Value
		saveSettings()
	end
})

local rivalsModernToggle = Tabs.Rivals:CreateToggle("RivalsModernToggle", {
	Title = "Rivals Modern",
	Default = Settings.ScriptToggles.Rivals_Modern,
	Callback = function(Value)
		Settings.ScriptToggles.Rivals_Modern = Value
		saveSettings()
	end
})

local rivalsRewriteToggle = Tabs.Rivals:CreateToggle("RivalsRewriteToggle", {
	Title = "Rivals Rewrite",
	Default = Settings.ScriptToggles.Rivals_Rewrite,
	Callback = function(Value)
		Settings.ScriptToggles.Rivals_Rewrite = Value
		saveSettings()
	end
})

local rivalsSkinChangerToggle = Tabs.Rivals:CreateToggle("RivalsSkinChangerToggle", {
	Title = "Rivals Skin Changer",
	Default = Settings.ScriptToggles.Rivals_SkinChanger,
	Callback = function(Value)
		Settings.ScriptToggles.Rivals_SkinChanger = Value
		saveSettings()
	end
})

Tabs.Rivals:CreateButton({
	Title = "Load Selected Rivals Scripts",
	Description = "Load all toggled Rivals scripts",
	Callback = function()
		local scriptsLoaded = false
		if Settings.ScriptToggles.Rivals_Classic then
			Library:Notify({ Title = "Rivals", Content = "Loading Rivals Classic...", Duration = 3 })
			loadstring(game:HttpGet(BASE_URL .. "Rivals/Classic.lua"))()
			scriptsLoaded = true
		end
		if Settings.ScriptToggles.Rivals_Modern then
			Library:Notify({ Title = "Rivals", Content = "Loading Rivals Modern...", Duration = 3 })
			loadstring(game:HttpGet(BASE_URL .. "Rivals/Modern.lua"))()
			scriptsLoaded = true
		end
		if Settings.ScriptToggles.Rivals_Rewrite then
			Library:Notify({ Title = "Rivals", Content = "Loading Rivals Rewrite...", Duration = 3 })
			loadstring(game:HttpGet(BASE_URL .. "Rivals/Rewrite.lua"))()
			scriptsLoaded = true
		end
		if Settings.ScriptToggles.Rivals_SkinChanger then
			Library:Notify({ Title = "Rivals", Content = "Loading Skin Changer...", Duration = 3 })
			loadstring(game:HttpGet(BASE_URL .. "Rivals/Skin-Changer.lua"))()
			scriptsLoaded = true
		end
		if not scriptsLoaded then
			Library:Notify({ Title = "Rivals", Content = "No scripts selected to load", Duration = 3 })
		end
	end
})

Tabs.FPS:CreateParagraph("FPS Game Scripts", {
	Title = "FPS Games",
	Content = "Select from various FPS game scripts below including Arsenal and Aimbot FFA."
})

local arsenalToggle = Tabs.FPS:CreateToggle("ArsenalToggle", {
	Title = "Arsenal",
	Default = Settings.ScriptToggles.Arsenal,
	Callback = function(Value)
		Settings.ScriptToggles.Arsenal = Value
		saveSettings()
	end
})

Tabs.FPS:CreateButton({
	Title = "Load Selected FPS Scripts",
	Description = "Load all toggled FPS game scripts",
	Callback = function()
		local scriptsLoaded = false
		if Settings.ScriptToggles.Arsenal then
			Library:Notify({ Title = "Arsenal", Content = "Loading Arsenal script...", Duration = 3 })
			loadstring(game:HttpGet(BASE_URL .. "Arsenal.lua"))()
			scriptsLoaded = true
		end
		if not scriptsLoaded then
			Library:Notify({ Title = "FPS Scripts", Content = "No scripts selected to load", Duration = 3 })
		end
	end
})

Tabs.Fighting:CreateParagraph("Fighting Game Scripts", {
	Title = "Fighting Games",
	Content = "Select from various fighting game scripts below including Bladeball and Fling Things and People."
})

local bladeballToggle = Tabs.Fighting:CreateToggle("BladeballToggle", {
	Title = "Bladeball",
	Default = Settings.ScriptToggles.Bladeball,
	Callback = function(Value)
		Settings.ScriptToggles.Bladeball = Value
		saveSettings()
	end
})

local flingThingsToggle = Tabs.Fighting:CreateToggle("FlingThingsToggle", {
	Title = "Fling Things and People",
	Default = Settings.ScriptToggles.FlingThingsAndPeople,
	Callback = function(Value)
		Settings.ScriptToggles.FlingThingsAndPeople = Value
		saveSettings()
	end
})

Tabs.Fighting:CreateButton({
	Title = "Load Selected Fighting Scripts",
	Description = "Load all toggled fighting game scripts",
	Callback = function()
		local scriptsLoaded = false
		if Settings.ScriptToggles.Bladeball then
			Library:Notify({ Title = "Bladeball", Content = "Loading script...", Duration = 3 })
			loadstring(game:HttpGet(BASE_URL .. "Bladeball.lua"))()
			scriptsLoaded = true
		end
		if Settings.ScriptToggles.FlingThingsAndPeople then
			Library:Notify({ Title = "Fling Things", Content = "Loading script...", Duration = 3 })
			loadstring(game:HttpGet(BASE_URL .. "Fling-Things-and-People.lua"))()
			scriptsLoaded = true
		end
		if not scriptsLoaded then
			Library:Notify({ Title = "Fighting Scripts", Content = "No scripts selected to load", Duration = 3 })
		end
	end
})

Tabs.Misc:CreateParagraph("Miscellaneous Game Scripts", {
	Title = "Misc Games",
	Content = "Other game scripts that don't fit into the main categories."
})

local murderMystery2Toggle = Tabs.Misc:CreateToggle("MurderMystery2Toggle", {
	Title = "Murder Mystery 2",
	Default = Settings.ScriptToggles.MurderMystery2,
	Callback = function(Value)
		Settings.ScriptToggles.MurderMystery2 = Value
		saveSettings()
	end
})

local nightsInTheForestToggle = Tabs.Misc:CreateToggle("NightsInTheForestToggle", {
	Title = "99 Nights in the Forest",
	Default = Settings.ScriptToggles.NightsInTheForest,
	Callback = function(Value)
		Settings.ScriptToggles.NightsInTheForest = Value
		saveSettings()
	end
})

local theWildWestToggle = Tabs.Misc:CreateToggle("TheWildWestToggle", {
	Title = "The Wild West",
	Default = Settings.ScriptToggles.TheWildWest,
	Callback = function(Value)
		Settings.ScriptToggles.TheWildWest = Value
		saveSettings()
	end
})

local doorsToggle = Tabs.Misc:CreateToggle("DoorsToggle", {
	Title = "Doors",
	Default = Settings.ScriptToggles.Doors,
	Callback = function(Value)
		Settings.ScriptToggles.Doors = Value
		saveSettings()
	end
})

Tabs.Misc:CreateButton({
	Title = "Load Selected Misc Scripts",
	Description = "Load all toggled miscellaneous game scripts",
	Callback = function()
		local scriptsLoaded = false
		if Settings.ScriptToggles.MurderMystery2 then
			Library:Notify({ Title = "Murder Mystery 2", Content = "Loading script...", Duration = 3 })
			loadstring(game:HttpGet(BASE_URL .. "Murder-Mystery-2.lua"))()
			scriptsLoaded = true
		end
        if Settings.ScriptToggles.NightsInTheForest then
            Library:Notify({ Title = "99 Nights in the Forest", Content = "Loading script...", Duration = 3 })
            loadstring(game:HttpGet(BASE_URL .. "99-Nights-in-the-Forest.lua"))()
            scriptsLoaded = true
        end
        if Settings.ScriptToggles.TheWildWest then
            Library:Notify({ Title = "The Wild West", Content = "Loading script...", Duration = 3 })
            loadstring(game:HttpGet(BASE_URL .. "The-Wild-West.lua"))()
            scriptsLoaded = true
        end
        if Settings.ScriptToggles.Doors then
            Library:Notify({ Title = "Doors", Content = "Loading script...", Duration = 3 })
            loadstring(game:HttpGet(BASE_URL .. "Doors.lua"))()
            scriptsLoaded = true
        end
		if not scriptsLoaded then
			Library:Notify({ Title = "Misc Scripts", Content = "No scripts selected to load", Duration = 3 })
		end
	end
})

Tabs.Theme:CreateParagraph("UI Customization", {
	Title = "Theme Settings",
	Content = "Customize the look and feel of the Soluna Script Loader."
})

local ThemeDropdown = Tabs.Theme:CreateDropdown("ThemeDropdown", {
	Title = "UI Theme",
	Values = {
		"Darker",
		"Dark",
		"Light",
		"Ocean",
		"Aqua",
		"Rose",
		"Violet",
		"Cyan"
	},
	Multi = false,
	Default = Settings.ThemeColor or "Darker",
	Callback = function(Value)
		Settings.ThemeColor = Value
		Library:SetTheme(Value)
		saveSettings()
	end
})

Tabs.Info:CreateParagraph("Development Team", {
	Title = "Script Information",
	Content = "This script was made by the Soluna Development Team.\n\nOwner: @endoverdosing\n\nContributing Team Members:\n@aidanqm\n@rvd1\n\nSpecial thanks to @nervigemuecke for helping with the Rivals script.\n\nThank you for your contributions!"
})

Tabs.Info:CreateButton({
	Title = "Copy Discord Link",
	Description = "Click to copy the Soluna Discord server link to your clipboard.",
	Callback = function()
		local discordLink = "https://discord.gg/e52GujVvbN"
		pcall(function()
			setclipboard(discordLink)
			Library:Notify({ Title = "Discord Link", Content = "Discord link copied to clipboard!", Duration = 3 })
		end)
	end
})

local autoLoadToggle = Tabs.Settings:CreateToggle("AutoLoadToggle", {
	Title = "Auto-Load Selected Scripts",
	Default = Settings.AutoLoadEnabled,
	Callback = function(Value)
		Settings.AutoLoadEnabled = Value
		saveSettings()
	end
})

local teleportLoadToggle = Tabs.Settings:CreateToggle("TeleportLoadToggle", {
	Title = "Load on Teleport",
	Default = Settings.TeleportLoadEnabled,
	Callback = function(Value)
		Settings.TeleportLoadEnabled = Value
		saveSettings()
	end
})

local disableScriptLoaderToggle = Tabs.Settings:CreateToggle("DisableScriptLoaderToggle", {
	Title = "Disable Script Loader",
	Description = "Completely disables the script loader on next execution",
	Default = Settings.DisableScriptLoader,
	Callback = function(Value)
		Settings.DisableScriptLoader = Value
		saveSettings()
		if Value then
			Library:Notify({ Title = "Script Loader", Content = "Script Loader will be disabled on next execution", Duration = 5 })
		else
			Library:Notify({ Title = "Script Loader", Content = "Script Loader will be enabled on next execution", Duration = 5 })
		end
	end
})

Tabs.Settings:CreateButton({
	Title = "Reload Script Loader",
	Description = "Reloads the script loader with the latest settings",
	Callback = function()
		Library:Notify({ Title = "Script Loader", Content = "Reloading Script Loader...", Duration = 3 })
		task.wait(1)
		loadstring(game:HttpGet("https://raw.githubusercontent.com/Soluna-Development/API/main/src/Loader.lua"))()
	end
})

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Library:Notify({
	Title = "Soluna",
	Content = "Script Loaded Successfully!",
	Duration = 5
})