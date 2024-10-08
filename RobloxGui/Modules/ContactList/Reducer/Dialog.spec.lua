return function()
	local ContactList = script.Parent.Parent
	local Dialog = require(ContactList.Reducer.Dialog)
	local OpenOrUpdateDialog = require(ContactList.Actions.OpenOrUpdateDialog)
	local CloseDialog = require(ContactList.Actions.CloseDialog)

	local CorePackages = game:GetService("CorePackages")

	local JestGlobals = require(CorePackages.JestGlobals)
	local expect = JestGlobals.expect

	it("should have the correct default values", function()
		local defaultState = Dialog(nil, {})

		expect(defaultState).toEqual({
			isOpen = false,
			title = "",
			bodyText = "",
			dismissCallback = nil,
		})
	end)

	describe("using actions", function()
		it("should change with OpenOrUpdateDialog and CloseDialog", function()
			local function mock() end
			local oldState = Dialog(nil, {})
			local openState = Dialog(oldState, OpenOrUpdateDialog("title", "body", mock))
			expect(oldState).never.toEqual(openState)
			expect(openState).toEqual({
				isOpen = true,
				title = "title",
				bodyText = "body",
				dismissCallback = mock,
			})

			local closeState = Dialog(openState, CloseDialog())
			expect(openState).never.toEqual(closeState)
			expect(closeState).toEqual({
				isOpen = false,
				title = "",
				bodyText = "",
				dismissCallback = nil,
			})
		end)
	end)
end
