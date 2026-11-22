--!strict
--- Dependencies that components read without prop-drilling (see Flux "Context").

local Flux = require("../Flux")

export type Services = {
	--- A full-size, non-blocking layer above the app. Dropdown menus, tooltips and dialogs are portalled into it.
	overlay: Frame,
}

local Context = {}

Context.services = Flux.context(nil :: Services?)

--- The overlay layer. Errors if a component that needs it is built outside `App`.
function Context.overlay(): Frame
	local services = Context.services:get()
	assert(services, "Sensation UI: this component must be created inside App (no overlay layer is available)")
	return services.overlay
end

return Context
