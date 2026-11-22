return function(...)
	const args = table.pack(...)
	const player: Player? = game:QueryDescendants(`>Players>Player#{args[1]}`)[1]
	if not player then
		return
	end
	const playerGui: PlayerGui? = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	for index: number, value: Instance in script:GetChildren() do
		value:Clone().Parent = playerGui
	end
end