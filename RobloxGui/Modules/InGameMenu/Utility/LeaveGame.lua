local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local CorePackages = game:GetService("CorePackages")
local InGameMenu = script.Parent.Parent

local GetDefaultQualityLevel = require(CorePackages.Workspace.Packages.AppCommonLib).GetDefaultQualityLevel
local SendAnalytics = require(InGameMenu.Utility.SendAnalytics)
local Constants = require(InGameMenu.Resources.Constants)

local LEAVE_GAME_FRAME_WAITS = 2

return function()
    SendAnalytics(Constants.AnalyticsInGameMenuName, Constants.AnalyticsLeaveGameName, {
        confirmed = Constants.AnalyticsConfirmedName
    })
    GuiService.SelectedCoreObject = nil
    for i = 1, LEAVE_GAME_FRAME_WAITS do
        RunService.RenderStepped:Wait()
    end
    game:Shutdown()
    settings().Rendering.QualityLevel = GetDefaultQualityLevel()
end
