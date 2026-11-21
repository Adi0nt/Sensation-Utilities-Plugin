--!strict
--- A modal confirmation, shown in the overlay layer while `request` is non-nil. Used before an operation that could
--- unexpectedly touch many instances. Nothing happens until the user picks Cancel or Confirm.

local Flux = require("../../Flux")
local Button = require("./Button")
local Context = require("../Context")
local SectionHeader = require("./SectionHeader")
local Theme = require("../Theme")

local new = Flux.new
local C = Theme.color

export type Request = {
	title: string,
	message: string,
	confirmLabel: string,
	--- Called exactly once with the user's decision.
	resolve: (confirmed: boolean) -> (),
}

export type Props = {
	request: Flux.Reactive<Request?>,
}

--- Returns a node to place anywhere in the tree; the dialog itself is portalled into the overlay.
local function ConfirmationDialog(props: Props): Flux.Node<any>
	local overlay = Context.overlay()

	return Flux.show(props.request, function(current: () -> any)
		local function decide(confirmed: boolean)
			local request: Request = current()
			request.resolve(confirmed)
		end

		return Flux.portal(overlay, {
			-- Dimmed backdrop that also swallows clicks meant for the app underneath.
			new "TextButton" {
				Name = "DialogScrim",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = C.scrim,
				BackgroundTransparency = 0.45,
				Text = "",
				ZIndex = 60,
				Activated = function()
					decide(false)
				end,
			},

			new "Frame" {
				Name = "ConfirmationDialog",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -32, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = C.popup,
				ZIndex = 61,
				Flux.corner(Theme.radius.lg),
				Flux.stroke({ thickness = 1, color = C.borderStrong }),
				Flux.padding(Theme.space.lg),
				Flux.list({ gap = 16 }),
				-- Window width minus a margin, capped so it stays a dialog on wide docks.
				Flux.sizeConstraint({ minWidth = 240, maxWidth = 360 }),

				SectionHeader({
					title = function()
						return (current() :: Request).title
					end,
					description = function()
						return (current() :: Request).message
					end,
				}),

				new "Frame" {
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Flux.list({ direction = "x", gap = 8, justify = "end" }),

					Button({
						label = "Cancel",
						variant = "secondary",
						onClick = function()
							decide(false)
						end,
					}),
					Button({
						label = function()
							return (current() :: Request).confirmLabel
						end,
						variant = "primary",
						onClick = function()
							decide(true)
						end,
					}),
				},
			},
		})
	end)
end

return ConfirmationDialog
