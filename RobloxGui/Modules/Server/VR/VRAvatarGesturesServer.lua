--!nonstrict
local RobloxGui = game:GetService("CoreGui"):WaitForChild("RobloxGui")
local Players = game:GetService("Players")
local VRService = game:GetService("VRService")
local RobloxReplicatedStorage = game:GetService("RobloxReplicatedStorage")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local AvatarUtil = require(RobloxGui.Modules.Common.AvatarUtil)
local ConnectionUtil = require(RobloxGui.Modules.Common.ConnectionUtil)

local VRPLAYERS_REMOTE_EVENT_NAME = "AvatarGesturesVRPlayer"
local VR_AVATAR_GESTURES_ANALYTICS_EVENT_NAME = "VRAvatarGestures"

-- flag to enable immersion mode for all player including non VR for testing purposes
local FFlagDebugImmersionModeNonVR = game:DefineFastFlag("DebugImmersionModeNonVR", false) -- remove with FFlagUpdateAvatarGestures
local FFlagUpdateAvatarGestures = game:DefineFastFlag("UpdateAvatarGestures", false)
local FFlagAvatarGesturesTelemetry = game:DefineFastFlag("AvatarGesturesTelemetry", false)

-- Analytics
local FIntVRAvatarGesturesAnalyticsThrottleHundrethsPercent = game:DefineFastInt("VRAvatarGesturesAnalyticsThrottleHundrethsPercent", 0)

local VRAvatarGesturesServer = {}
VRAvatarGesturesServer.__index = VRAvatarGesturesServer

function VRAvatarGesturesServer.new()
	local self: any = setmetatable({}, VRAvatarGesturesServer)

	self.connections = ConnectionUtil.new()
	-- set of players who want to use VR gestures, populated by remote event requests from the client
	self.VRPlayers = {}

	-- track changes to the API
	self.connections:connect("AvatarGestures", VRService:GetPropertyChangedSignal("AvatarGestures"), function() self:onAvatarGesturesChanged() end)
	if VRService.AvatarGestures then self:onAvatarGesturesChanged() end

	return self
end

-- deletes created parts and IK controls
function cleanCharacter(player)
	-- avatarUtil currently doesn't support disconnecting, but the connection should be cleaned up as well when it is supported

	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			local ikControlNames = { "TrackedIKLeftHand", "TrackedIKRightHand", "TrackedIKHead" }
			for _, ikName in pairs(ikControlNames) do
				local ikControl = humanoid:FindFirstChild(ikName)

				if ikControl then
					ikControl:Destroy()
				end
			end
		end

		local partNames = { "TrackedLeftHand", "TrackedRightHand", "TrackedHead" }
		for _, partName in pairs(partNames) do
			local part = player.Character:FindFirstChild(partName)

			if part then
				part:Destroy()
			end
		end
	end
end

function VRAvatarGesturesServer:onPlayerChanged(player, isVRPlayer)
	self.VRPlayers[player] = isVRPlayer or nil

	if isVRPlayer then
		-- if we're not connected to the avatar utility, connect to track avatar changes
		if not self.avatarUtil then
			self.avatarUtil = AvatarUtil.new()
		end

		self.avatarUtil:connectPlayerCharacterChanges(player, function(character)
			self:onCharacterChanged(character)
		end)
	else
		cleanCharacter(player)
	end
end

function VRAvatarGesturesServer:onPlayerAdded(player)
	-- report when a player joins and can see an animated VR Player
	if FFlagAvatarGesturesTelemetry and next(self.VRPlayers) ~= nil then
		RbxAnalyticsService:ReportInfluxSeries(VR_AVATAR_GESTURES_ANALYTICS_EVENT_NAME, {
			placeId = game.PlaceId,
			calledFrom = "ServerPlayerAddedWithVRPlayer",
			playerUserID = player.UserId,
		}, FIntVRAvatarGesturesAnalyticsThrottleHundrethsPercent)
	end
end

function VRAvatarGesturesServer:onAvatarGesturesChanged()
	if FFlagUpdateAvatarGestures then
		if VRService.AvatarGestures then
			-- create remote event if not existing
			local isVRPlayerRemoteEvent = RobloxReplicatedStorage:FindFirstChild(VRPLAYERS_REMOTE_EVENT_NAME)
			if not isVRPlayerRemoteEvent then
				isVRPlayerRemoteEvent = Instance.new("RemoteEvent")
				isVRPlayerRemoteEvent.Name = VRPLAYERS_REMOTE_EVENT_NAME
				isVRPlayerRemoteEvent.Parent = RobloxReplicatedStorage
			end

			-- add connection to populate VRPlayers
			self.connections:connect("VRPlayerOnServerEvent", isVRPlayerRemoteEvent.OnServerEvent, function(player, isVRPlayer) self:onPlayerChanged(player, isVRPlayer) end)

			-- analytics for number of players in an experience with an animated VR Player
			self.connections:connect("PlayerAdded", Players.PlayerAdded, function(player) self:onPlayerAdded(player) end)

			-- remove a player when they leave
			self.connections:connect("PlayerRemoving", Players.PlayerRemoving, function(player) self:onPlayerChanged(player, false) end)
		else
			-- delete IK and parts
			for player in pairs(self.VRPlayers) do
				self:onPlayerChanged(player, false)
			end

			self.connections:disconnectAll()
			self.connections:connect("AvatarGestures", VRService:GetPropertyChangedSignal("AvatarGestures"), function()
				self:onAvatarGesturesChanged()
			end)
		end
	else
		if VRService.AvatarGestures then
			-- if we're not connected to the avatar utility, connect to track avatar changes
			if not self.avatarUtil then
				self.avatarUtil = AvatarUtil.new()

				local function onPlayerAdded(player)
					self.avatarUtil:connectPlayerCharacterChanges(player, function(character)
						self:onCharacterChanged(character)
					end)
				end

				self.connections:connect("PlayerAdded", Players.PlayerAdded, onPlayerAdded)
				for i, player in pairs(Players:GetPlayers()) do
					onPlayerAdded(player)
				end
			else
				-- already connected to avatarUtil, manually trigger change callback to reenable IK on existing characters
				for _, player in pairs(Players:GetPlayers()) do
					if player.Character then
						self:onCharacterChanged(player.Character)
					end
				end
			end
		else
			-- delete IK and parts
			for _, player in pairs(Players:GetPlayers()) do
				if player.Character then
					local humanoid = player.Character:FindFirstChild("Humanoid")
					if humanoid then
						local ikControlNames = { "VRIKLeftHand", "VRIKRightHand", "VRIKHead" }
						for _, ikName in pairs(ikControlNames) do
							local ikControl = humanoid:FindFirstChild(ikName)

							if ikControl then
								ikControl:Destroy()
							end
						end
					end

					local partNames = { "VRGesturesLeftHand", "VRGesturesRightHand", "VRGesturesHead" }
					for _, partName in pairs(partNames) do
						local part = player.Character:FindFirstChild(partName)

						if part then
							part:Destroy()
						end
					end
				end
			end
		end
	end
end

function VRAvatarGesturesServer:findOrCreateColliders(partName, character)
	local player = Players:GetPlayerFromCharacter(character)
	-- Create collider part
	local colliderName
	if FFlagUpdateAvatarGestures then
		colliderName = "Tracked" .. partName
	else
		colliderName = "VRGestures" .. partName
	end
	local vrCollider = character:FindFirstChild(colliderName)
	if not vrCollider then
		vrCollider = Instance.new("Part")
		vrCollider.Name = colliderName
		vrCollider.Transparency = 1
		vrCollider.CanCollide = false
		vrCollider.Parent = character
		vrCollider:SetNetworkOwner(player)
	end

	-- Add collider attachment
	local colliderAttachment = vrCollider:FindFirstChild(colliderName .. "Attachment")
	if not colliderAttachment then
		colliderAttachment = Instance.new("Attachment")
		colliderAttachment.Name = colliderName .. "Attachment"

		colliderAttachment.Parent = vrCollider
	end

	local alignPosition = vrCollider:FindFirstChild(colliderName .. "AlignPosition")
	if not alignPosition then
		alignPosition = Instance.new("AlignPosition")
		alignPosition.Name = colliderName .. "AlignPosition"
		alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPosition.Attachment0 = colliderAttachment
		alignPosition.RigidityEnabled = true
		alignPosition.Parent = vrCollider
	end

	local alignOrientation = vrCollider:FindFirstChild(colliderName .. "AlignOrientation")
	if not alignOrientation then
		alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Name = colliderName .. "AlignOrientation"
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Attachment0 = colliderAttachment
		alignOrientation.RigidityEnabled = true
		alignOrientation.Parent = vrCollider
	end

	-- Size and place collider based on the character
	local part = character:FindFirstChild(partName)
	if part then
		vrCollider.Size = part.Size
		vrCollider.CFrame = part.CFrame
		alignPosition.Position = part.Position
		alignOrientation.CFrame = part.CFrame
	else
		vrCollider.Size = Vector3.new(1, 1, 1)
		vrCollider.CFrame = character.WorldPivot
		alignPosition.Position = character.WorldPivot.Position
		alignOrientation.CFrame = character.WorldPivot
	end
	
	-- IK control so that the hands follow the collider
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		local ikControlName
		if FFlagUpdateAvatarGestures then
			ikControlName = "TrackedIK" .. partName
		else
			ikControlName = "VRIK" .. partName
		end
		local ikControl = humanoid:FindFirstChild(ikControlName)

		if not ikControl then
			ikControl = Instance.new("IKControl")
			ikControl.Name = ikControlName
		end

		ikControl.SmoothTime = 0.1
		ikControl.Parent = humanoid
		ikControl.Target = vrCollider
	end
end


function VRAvatarGesturesServer:createHandCollider(side, character)
	self:findOrCreateColliders(side .. "Hand", character)
    local part = character:FindFirstChild(side .. "Hand")
	
	-- IK control
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		local ikControlName = "VRIK" .. side .. "Hand"
		if FFlagUpdateAvatarGestures then
			ikControlName = "TrackedIK" .. side .. "Hand"
		else
			ikControlName = "VRIK" .. side .. "Hand"
		end
		local ikControl = humanoid:FindFirstChild(ikControlName)
		
		if ikControl then
			ikControl.Type = Enum.IKControlType.Transform

			local ikRoot = character:FindFirstChild(side .. "UpperArm")
			if ikRoot then
				-- IKControl needs a reset if the character's proportions may have changed
				ikControl.ChainRoot = part
				coroutine.wrap(function()
					task.wait(0.1)
					ikControl.ChainRoot = ikRoot
				end)()
			end

			if part then
				ikControl.EndEffector = part
			end
			ikControl.Priority = 1
		end
	end

	if part then
		local constraint = part:FindFirstChild("RagdollBallSocket")
		if constraint then
			constraint.LimitsEnabled = false
		end
	end
end

function VRAvatarGesturesServer:createHeadCollider(character)
	self:findOrCreateColliders("Head", character)
    local part = character:FindFirstChild("Head")
	
	-- IK control
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		local ikControlName
		if FFlagUpdateAvatarGestures then
			ikControlName = "TrackedIKHead"
		else
			ikControlName = "VRIKHead"
		end
		local ikControl = humanoid:FindFirstChild(ikControlName)

		if ikControl then
			ikControl.Type = Enum.IKControlType.Rotation

			local ikRoot = character:FindFirstChild("UpperTorso")
			if ikRoot then
				ikControl.ChainRoot = ikRoot
			end

			if part then
				ikControl.EndEffector = part
			end
		end
	end
end

-- Makes all of the parts necessary for displaying avatar gestures
function VRAvatarGesturesServer:onCharacterChanged(character)
	-- create instances if they don't exist yet
	local player = Players:GetPlayerFromCharacter(character)
	if FFlagUpdateAvatarGestures then
		if self.VRPlayers[player] and VRService.AvatarGestures then
			self:createHandCollider("Left", character)
			self:createHandCollider("Right", character)
			self:createHeadCollider(character)
		end
	else
		if (player.VREnabled or FFlagDebugImmersionModeNonVR) and VRService.AvatarGestures then
			self:createHandCollider("Left", character)
			self:createHandCollider("Right", character)
			self:createHeadCollider(character)
		end
	end
end

return VRAvatarGesturesServer