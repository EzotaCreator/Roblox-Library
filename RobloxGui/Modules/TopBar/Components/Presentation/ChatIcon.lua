local CorePackages = game:GetService("CorePackages")
local CoreGui = game:GetService("CoreGui")
local VRService = game:GetService("VRService")

local Roact = require(CorePackages.Roact)
local RoactRodux = require(CorePackages.RoactRodux)
local t = require(CorePackages.Packages.t)
local UIBlox = require(CorePackages.UIBlox)

local withStyle = UIBlox.Core.Style.withStyle
local Badge = UIBlox.App.Indicator.Badge
local BadgeStates = UIBlox.App.Indicator.Enum.BadgeStates

local RobloxGui = CoreGui:WaitForChild("RobloxGui")
local ChatSelector = require(RobloxGui.Modules.ChatSelector)
local TenFootInterface = require(RobloxGui.Modules.TenFootInterface)

local IconButton = require(script.Parent.IconButton)

local TopBar = script.Parent.Parent.Parent
local TopBarAnalytics = require(TopBar.Analytics)
local FFlagEnableChromeBackwardsSignalAPI = require(TopBar.Flags.GetFFlagEnableChromeBackwardsSignalAPI)()
local FFlagEnableTopBarAnalytics = require(TopBar.Flags.GetFFlagEnableTopBarAnalytics)()
local SetKeepOutArea = require(TopBar.Actions.SetKeepOutArea)
local RemoveKeepOutArea = require(TopBar.Actions.RemoveKeepOutArea)
local Constants = require(TopBar.Constants)

local GameSettings = UserSettings().GameSettings

local function shouldShowEmptyBadge()
	return game:GetService("TextChatService").ChatVersion == Enum.ChatVersion.TextChatService
end

local ChatIcon = Roact.PureComponent:extend("ChatIcon")

local CHAT_ICON_AREA_WIDTH = 44

local ICON_SIZE = 20
local BADGE_OFFSET_X = 18
local BADGE_OFFSET_Y = 2
local EMPTY_BADGE_OFFSET_Y = 6

ChatIcon.validateProps = t.strictInterface({
	layoutOrder = t.integer,

	chatVisible = t.boolean,
	unreadMessages = t.integer,

	topBarEnabled = t.boolean,
	chatEnabled = t.boolean,

	setKeepOutArea = t.callback,
	removeKeepOutArea = t.callback,
})

function ChatIcon:init()
	self.buttonRef = Roact.createRef()
	
	self.chatIconActivated = function()
		ChatSelector:ToggleVisibility()
		GameSettings.ChatVisible = ChatSelector:GetVisibility()
		if FFlagEnableTopBarAnalytics then
			TopBarAnalytics.default:onChatButtonActivated(GameSettings.ChatVisible)
		end
	end
end

function ChatIcon:render()
	return withStyle(function(style)
		local chatEnabled = self.props.topBarEnabled and self.props.chatEnabled and not TenFootInterface:IsEnabled() and not VRService.VREnabled

		local chatIcon = "rbxasset://textures/ui/TopBar/chatOn.png"
		if not self.props.chatVisible then
			chatIcon = "rbxasset://textures/ui/TopBar/chatOff.png"
		end

		local onAreaChanged = function(rbx)
			if chatEnabled and rbx then
				self.props.setKeepOutArea(Constants.ChatIconKeepOutAreaId, rbx.AbsolutePosition, rbx.AbsoluteSize)
			else
				self.props.removeKeepOutArea(Constants.ChatIconKeepOutAreaId)
			end
		end

		local setButtonRef = function(rbx)
			if rbx then
				self.buttonRef.current = rbx
				onAreaChanged(self.buttonRef.current)
			end
		end

		if FFlagEnableChromeBackwardsSignalAPI then
			if self.buttonRef.current then
				onAreaChanged(self.buttonRef.current)
			end
		end

		return Roact.createElement("TextButton", {
			Text = "",
			Visible = chatEnabled,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, CHAT_ICON_AREA_WIDTH, 1, 0),
			LayoutOrder = self.props.layoutOrder,
			Selectable = false,
		}, {
			Background = Roact.createElement(IconButton, {
				icon = chatIcon,
				iconSize = ICON_SIZE,
				onActivated = self.chatIconActivated,
				[Roact.Change.AbsoluteSize] = if FFlagEnableChromeBackwardsSignalAPI then onAreaChanged else nil,
				[Roact.Change.AbsolutePosition] = if FFlagEnableChromeBackwardsSignalAPI then onAreaChanged else nil,
				[Roact.Ref] = setButtonRef,
			}),

			BadgeContainer = Roact.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, {
				Badge = self.props.unreadMessages > 0 and Roact.createElement(Badge, {
					position = UDim2.fromOffset(BADGE_OFFSET_X, shouldShowEmptyBadge() and EMPTY_BADGE_OFFSET_Y or BADGE_OFFSET_Y),
					anchorPoint = Vector2.new(0, 0),

					hasShadow = false,
					value = shouldShowEmptyBadge() and BadgeStates.isEmpty or self.props.unreadMessages,
				})
			})
		})
	end)
end

local function mapStateToProps(state)
	return {
		chatVisible = state.chat.visible,
		unreadMessages = state.chat.unreadMessages,

		topBarEnabled = state.displayOptions.topbarEnabled,
		chatEnabled = state.coreGuiEnabled[Enum.CoreGuiType.Chat],
	}
end

local function mapDispatchToProps(dispatch)
	return {
		setKeepOutArea = function(id, position, size)
			return dispatch(SetKeepOutArea(id, position, size))
		end,
		removeKeepOutArea = function(id)
			return dispatch(RemoveKeepOutArea(id))
		end,
	}
end

return RoactRodux.UNSTABLE_connect2(mapStateToProps, mapDispatchToProps)(ChatIcon)
