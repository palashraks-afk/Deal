-- DrivinDealz client entry point.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local DriveController = require(script.DriveController)
local HUD = require(script.HUD)
local Minimap = require(script.Minimap)
local Menus = require(script.Menus)
local Combat = require(script.Combat)
require(script.State)

local menus = Menus.build()
DriveController.start()
HUD.start(menus)
Combat.start()
task.spawn(Minimap.start)

-- keyboard shortcuts
local KEYS = {
	[Enum.KeyCode.B] = menus.Garage,
	[Enum.KeyCode.N] = menus.Shop,
	[Enum.KeyCode.U] = menus.Upgrades,
	[Enum.KeyCode.J] = menus.Factory,
	[Enum.KeyCode.K] = menus.Guns,
}
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local menu = KEYS[input.KeyCode]
	if menu then
		menu.toggle()
	end
end)

-- prompts that open menus; hide Buy/Steal on your own cars
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "CatalogPrompt" then
		menus.Shop.open()
	elseif prompt.Name == "GunStorePrompt" then
		menus.Guns.open()
	end
end)
ProximityPromptService.PromptShown:Connect(function(prompt)
	if (prompt.Name == "StealPrompt" or prompt.Name == "BuyPrompt") and prompt:GetAttribute("OwnerUserId") == player.UserId then
		prompt.Enabled = false
	end
end)
