--!strict
--- Retrying `HttpService:GetAsync`, ported unchanged from the previous plugin.lua (same retry count and 1 s back-off).

local Types = require("./Types")

local httpService = game:GetService("HttpService")

local Http = {}

--- Yields. Returns the response body, or `nil` after `maxRetries` (default 5) failed retries.
function Http.get(url: string, log: Types.Log, maxRetries: number?): string?
	local retries = maxRetries or 5
	local attempts = 0
	local success, body: any = false, nil

	repeat
		success, body = pcall(httpService.GetAsync, httpService, url)
		if success then
			return body :: string
		end

		attempts += 1
		if attempts <= retries then
			log.info(`Buffering... (Attempt {attempts}/{retries})`)
			task.wait(1)
		end
	until success or attempts > retries

	log.warn(`Failed to fetch URL after {retries} attempts.`)
	return nil
end

return Http
