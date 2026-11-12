--!strict
local TableUtil = {}

function TableUtil.deepCopy<T>(t: T): T
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in t :: any do
		copy[TableUtil.deepCopy(k)] = TableUtil.deepCopy(v)
	end
	return (copy :: any) :: T
end

-- Ergänzt fehlende Schlüssel aus template (für Datenmigration).
-- skipKeys: Tabellen, deren Inhalt frei veränderlich ist (z. B. Inventar) und
-- daher NICHT mit Vorlagenwerten aufgefüllt werden dürfen.
function TableUtil.reconcile(target: any, template: any, skipKeys: { [string]: boolean }?)
	for k, v in template do
		if target[k] == nil then
			target[k] = TableUtil.deepCopy(v)
		elseif skipKeys and skipKeys[k] then
			continue
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			-- nur Tabellen mit festen Schlüsseln (kein Array/Map-Inhalt) rekursiv
			local isRecord = true
			for kk in v do
				if type(kk) ~= "string" then
					isRecord = false
					break
				end
			end
			if isRecord then
				TableUtil.reconcile(target[k], v)
			end
		end
	end
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function TableUtil.find<T>(arr: { T }, value: T): number?
	for i, v in arr do
		if v == value then
			return i
		end
	end
	return nil
end

return TableUtil
