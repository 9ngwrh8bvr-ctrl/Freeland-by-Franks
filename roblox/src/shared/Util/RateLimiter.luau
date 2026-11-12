--!strict
-- Einfache Ratenbegrenzung pro Spieler und Schlüssel (Schutz vor Spam/Exploits).

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable({} :: { interval: number, last: { [any]: number } }, RateLimiter))

function RateLimiter.new(interval: number): RateLimiter
	return setmetatable({ interval = interval, last = {} }, RateLimiter)
end

function RateLimiter.check(self: RateLimiter, key: any): boolean
	local now = os.clock()
	local last = self.last[key]
	if last and now - last < self.interval then
		return false
	end
	self.last[key] = now
	return true
end

function RateLimiter.clear(self: RateLimiter, key: any)
	self.last[key] = nil
end

return RateLimiter
