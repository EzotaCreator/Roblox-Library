return function()
	local CorePackages = game:GetService("CorePackages")
	local Roact = require(CorePackages.Roact)

	local SearchBar = require(script.Parent.SearchBar)

	it("should create and destroy without errors", function()

		local element = Roact.createElement(SearchBar, {
			frameHeight = 0,
			textSize = 10,
			font = Enum.Font.Code,
		})
		local instance = Roact.mount(element)
		Roact.unmount(instance)
	end)
end