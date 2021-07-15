local CMH = {}

local links = {}

function CMH.OnReceive(self, event, prefix, _, Type, sender)
	if event == "CHAT_MSG_ADDON" and sender == UnitName("player") and Type == "WHISPER" then
		local source, functionId, link, linkCount, MSG = prefix:match("(%D)(%d%d)(%d%d%d)(%d%d%d)(.+)");
		if not source or not functionId or not link or not linkCount or not MSG then
			return
		end
		
		if(source == "S") then
			functionId, link, linkCount = tonumber(functionId), tonumber(link), tonumber(linkCount);
			links[functionId] = links[functionId] or {count = 0};
			links[functionId][link] = MSG;
			links[functionId].count = links[functionId].count + 1;
			if (links[functionId].count ~= linkCount) then
				return
			end
			
			local fullMessage = table.concat(links[functionId]);
			links[functionId] = {count = 0};
			
			local VarTable = ParseMessage(fullMessage)
			if not VarTable then
				return
			end

			if not(CMH[VarTable[1]]) then
				return
			end

			local func = CMH[VarTable[1]][functionId]
			if func then
				_G[func](sender, VarTable)
			end
			return
		end
	end
end

local CMHFrame = CreateFrame("Frame")
CMHFrame:RegisterEvent("CHAT_MSG_ADDON")
CMHFrame:SetScript("OnEvent", CMH.OnReceive)

function RegisterServerResponses(config)
	if(CMH[config.Prefix]) then
		return;
	end
	
	CMH[config.Prefix] = {}
	
	for functionId, functionName in pairs(config.Functions) do
		CMH[config.Prefix][functionId] = functionName
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
			v = Smallfolk.loads(v, #v)
		elseif(varType == 5) then -- Booleans
			if(v == "true") then v = true else v = false end
		end
		table.insert(output, v)
	end
	
	valTemp = nil
	typeTemp = nil
	
	return output
end

function SendClientRequest(prefix, functionId, ...)
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
			v = Smallfolk.dumps(v)
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
		send = string.format("%01s%03d%02d%02d", "C", functionId, counter, splits)
		if ((i + splitLength) > msg:len()) then
			send = send .. msg:sub(i, msg:len())
		else
			send = send .. msg:sub(i, i + splitLength - 1)
		end
		counter = counter + 1

		SendAddonMessage(send, "", "WHISPER", UnitName("player"))
	end
end