return function()
	local CoreGui = game:GetService("CoreGui")
	local CorePackages = game:GetService("CorePackages")

	local Roact = require(CorePackages.Roact)
	local Rodux = require(CorePackages.Rodux)
	local RoactRodux = require(CorePackages.RoactRodux)
	local UIBlox = require(CorePackages.UIBlox)
	local JestGlobals = require(CorePackages.JestGlobals)
	local jestExpect = JestGlobals.expect

	local LocalizationProvider = require(CorePackages.Workspace.Packages.Localization).LocalizationProvider
	local Localization = require(CorePackages.Workspace.Packages.InExperienceLocales).Localization

	local Reducer = require(script.Parent.Parent.Reducer)
	local PlayerMenuContainer = require(script.Parent.PlayerMenuContainer)

	it("should mount and unmount without errors", function()
		local store = Rodux.Store.new(Reducer, {
			PlayerMenu = {
				isOpen = true,
				friend = {
					userName = "testName",
					combinedName = "testDisplayName",
					userId = 1234567891,
				},
			},
		}, {
			Rodux.thunkMiddleware,
		})

		local element = Roact.createElement(RoactRodux.StoreProvider, {
			store = store,
		}, {
			StyleProvider = Roact.createElement(UIBlox.Core.Style.Provider, {}, {
				LocalizationProvider = Roact.createElement(LocalizationProvider, {
					localization = Localization.new("en-us"),
				}, {
					PlayerMenuContainer = Roact.createElement(PlayerMenuContainer),
				}),
			}),
		})

		local instance = Roact.mount(element)
		jestExpect(CoreGui:FindFirstChild("PlayerMenuScreen")).never.toBeNull()
		Roact.unmount(instance)
	end)
end
