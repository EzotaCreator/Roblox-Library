local GetFFlagShareInviteLinkContextMenuV1ABTestEnabled = require(script.Parent.GetFFlagShareInviteLinkContextMenuV1ABTestEnabled)
local GetFFlagShareInviteLinkContextMenuV3ABTestEnabled = require(script.Parent.GetFFlagShareInviteLinkContextMenuV3ABTestEnabled)

return function ()
    return GetFFlagShareInviteLinkContextMenuV1ABTestEnabled() or GetFFlagShareInviteLinkContextMenuV3ABTestEnabled()
end
