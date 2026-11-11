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
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		menus.Garage.toggle()
	elseif input.KeyCode == Enum.KeyCode.N then
		menus.Dealership.toggle()
	elseif input.KeyCode == Enum.KeyCode.C then
		menus.Craft.toggle()
	end
end)

-- plot prompts open menus; hide "Steal" on your own cars
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local plot = prompt:FindFirstAncestorWhichIsA("Model")
	while plot and not plot.Name:match("^Plot%d") do
		plot = plot:FindFirstAncestorWhichIsA("Model")
	end
	local mine = plot and plot:GetAttribute("OwnerUserId") == player.UserId
	if prompt.Name == "CatalogPrompt" and mine then
		menus.Dealership.open()
	elseif prompt.Name == "CraftPrompt" and mine then
		menus.Craft.open()
	end
end)
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Name == "StealPrompt" and prompt:GetAttribute("OwnerUserId") == player.UserId then
		prompt.Enabled = false
	end
end)
