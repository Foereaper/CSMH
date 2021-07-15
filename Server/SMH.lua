local smallfolk = smallfolk or require("smallfolk")
local SMH = {}
local links = {}

function SMH.OnReceive(event, sender, _type, prefix, _, target)
	if not sender or not target or not sender.GetName or not target.GetName or type(sender) ~= "userdata" or type(target) ~= "userdata" then
		return
	end
	if sender:GetName() == target:GetName() and _type == 7 then
		local source, functionId, link, linkCount, MSG = prefix:match("(%D)(%d%d%d)(%d%d)(%d%d)(.+)");
		if not source or not functionId or not link or not linkCount or not MSG then
			return
		end
		if(source == "C") then
			functionId, link, linkCount = tonumber(functionId), tonumber(link), tonumber(linkCount);
			
			links[sender:GetGUIDLow()] = links[sender:GetGUIDLow()] or {}
			links[sender:GetGUIDLow()][functionId] = links[sender:GetGUIDLow()][functionId] or {count = 0};
			links[sender:GetGUIDLow()][functionId][link] = MSG;
			links[sender:GetGUIDLow()][functionId].count = links[sender:GetGUIDLow()][functionId].count + 1;
			if (links[sender:GetGUIDLow()][functionId].count ~= linkCount) then
				return
			end
			
			local fullMessage = table.concat(links[sender:GetGUIDLow()][functionId]);
			links[sender:GetGUIDLow()][functionId] = {count = 0};
			
			local VarTable = ParseMessage(fullMessage)
			if not VarTable then
				return
			end
			
			if not(SMH[VarTable[1]]) then
				return
			end

			local func = SMH[VarTable[1]][functionId]
			if func then
				_G[func](sender, VarTable)
			end
			return
		end
	end
end

RegisterServerEvent(30, SMH.OnReceive)

function RegisterClientRequests(config)
	-- If a config table with the Prefix already exists, abort loading it into the register.
	if(SMH[config.Prefix]) then
		return;
	end
	
	-- Create subtable for PrefixName
	SMH[config.Prefix] = {}
	
	-- Insert function ID and function name into the register table.
	for functionId, functionName in pairs(config.Functions) do
		SMH[config.Prefix][functionId] = functionName
	end
end

function ParseMessage(str)
	local output = {}
	local valTemp = {}
	local typeTemp = {}
	local delim = {"♠", "♥", "♚", "♛", "♜"}
	
	local valMatch = "[^"..table.concat(delim).."]+"
	local typeMatch = "["..table.concat(delim).."]+"
	
	-- Get values
	for value in str:gmatch(valMatch) do
		table.insert(valTemp, value)
	end
	
	-- Get type from delimiter
	for varType in str:gmatch(typeMatch) do
		for k, v in pairs(delim) do
			if(v == varType) then
				table.insert(typeTemp, k)
			end
		end
	end
	
	-- Convert value to correct type
	for k, v in pairs(valTemp) do
		local varType = typeTemp[k]
		if(varType == 3) then -- Ints
			v = tonumber(v)
		elseif(varType == 4) then -- Tables
			v = smallfolk.loads(v)
		elseif(varType == 5) then -- Booleans
			if(v == "true") then v = true else v = false end
		end
		table.insert(output, v)
	end
	
	valTemp = nil
	typeTemp = nil
	
	return output
end

function Player:SendServerResponse(prefix, functionId, ...)
	-- ♠ = Prefix prefix
	-- ♥ = ArgumentPrefix for Strings 
	-- ♚ = ArgumentPrefix for Ints
	-- ♛ = ArgumentPrefix for Tables
	-- ♜ = ArgumentPrefix for Boolean
	
	local arg = {...}
	local splitLength = 230
	local msg = "♠" .. prefix
	
	for _, v in pairs(arg) do
		if(type(v) == "string") then
			msg = msg .. "♥"
		elseif(type(v) == "number") then
			msg = msg .. "♚"
		elseif(type(v) == "table") then
			-- use Smallfolk to convert table structure to string
			v = smallfolk.dumps(v)
			msg = msg .. "♛"
		elseif(type(v) == "boolean") then
			v = tostring(v)
			msg = msg .. "♜"
		end
		msg = msg .. v
	end
	
	local splits = math.ceil(msg:len() / splitLength)
	local send
	local counter = 1
	for i=1, msg:len(), splitLength do
		send = string.format("%01s%02d%03d%03d", "S", functionId, counter, splits)
		if ((i + splitLength) > msg:len()) then
			send = send .. msg:sub(i, msg:len())
		else
			send = send .. msg:sub(i, i + splitLength - 1)
		end
		counter = counter + 1
		self:SendAddonMessage(send, "", 7, self)
	end
end