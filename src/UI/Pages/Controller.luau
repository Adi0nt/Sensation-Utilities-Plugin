--!strict
--- What every page receives: the UI state and the actions that act on it.

local Actions = require("../Actions")
local State = require("../State")

export type Controller = {
	state: State.State,
	actions: Actions.Actions,
}

return {}
