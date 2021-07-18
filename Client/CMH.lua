local debug = false

local CMH = {}
local datacache = {}

local CSMHMsgPrefix = "♠"
local delim = {"♥", "♚", "♛", "♜"}
local pck = {REQ = 1, ACK = 2, DAT = 3, NAK = 4}

-- HELPERS START
local function debugOut(msg)
	if(debug == true) then
		print("CMH Debug: "..msg)
	end
end

local function GenerateReqId()
	local length = 6
	local reqId = ""

	for i = 1, length do
		reqId = reqId .. string.char(math.random(97, 122))
	end

	return reqId
end

local function ParseMessage(prefix, str)
	local output = {}
	local valTemp = {}
	local typeTemp = {}
	
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
		if(varType == 2) then -- Ints
			v = tonumber(v)
		elseif(varType == 3) then -- Tables
			v = Smallfolk.loads(v, #v)
		elseif(varType == 4) then -- Booleans
			if(v == "true") then v = true else v = false end
		end
		table.insert(output, v)
	end
	
	valTemp = nil
	typeTemp = nil
	
	return output
end

local function ProcessVariables(reqId, ...)
	local arg = {...}
	local splitLength = 200
	local msg = ""
	
	for _, v in pairs(arg) do
		if(type(v) == "string") then
			msg = msg .. delim[1]
		elseif(type(v) == "number") then
			msg = msg .. delim[2]
		elseif(type(v) == "table") then
			-- use Smallfolk to convert table structure to string
			v = Smallfolk.dumps(v)
			msg = msg .. delim[3]
		elseif(type(v) == "boolean") then
			v = tostring(v)
			msg = msg .. delim[4]
		end
		msg = msg .. v
	end
	
	if not datacache[reqId] then
		datacache[reqId] = { count = 1, data = {}}
	end
	
	for i=1, msg:len(), splitLength do
		datacache[reqId]["data"][#datacache[reqId]["data"]+1] = msg:sub(i,i+splitLength - 1)
		datacache[reqId].count = datacache[reqId].count + 1
	end
	
	return datacache[reqId]
end

-- HELPERS END

-- Rx START

function CMH.OnReceive(self, event, prefix, _, Type, sender)
	-- Ensure the sender and receiver is the same, the message is an addon message, and the message type is WHISPER
	if event == "CHAT_MSG_ADDON" and sender == UnitName("player") and Type == "WHISPER" then
		-- unpack and validate addon message structure
		local pfx, source, pckId, data = prefix:match("(...)(%u)(%d%d)(.+)")	
		if not pfx or not source or not pckId or not data then
			return
		end
		
		-- Make sure we're only processing addon messages using our framework prefix character as welll as server messages
		if(pfx == CSMHMsgPrefix and source == "S") then
			debugOut("Received CSMH packet, processing data.")
			
			-- convert ID to number so we can compare with our packet list
			pckId = tonumber(pckId)
			
			if(pckId == pck.REQ) then
				debugOut("REQ received, data: "..data)
				CMH.OnREQ(sender, data)
			elseif(pckId == pck.ACK) then
				debugOut("ACK received, data: "..data)
				CMH.OnACK(sender, data)
			elseif(pckId == pck.DAT) then
				debugOut("DAT received, data: "..data)
				CMH.OnDAT(sender, data)
			elseif(pckId == pck.NAK) then
				debugOut("NAK received, data: "..data)
				CMH.OnNAK(sender, data)
			else
				debugOut("Invalid packet ID, aborting")
				return
			end
		end
	end
end

local CMHFrame = CreateFrame("Frame")
CMHFrame:RegisterEvent("CHAT_MSG_ADDON")
CMHFrame:SetScript("OnEvent", CMH.OnReceive)

function CMH.OnREQ(sender, data)
	debugOut("Processing REQ data")
	-- split header string into proper variables and ensure the string is the expected format
	local functionId, linkCount, reqId, addon = data:match("(%d%d)(%d%d)(%w%w%w%w%w%w)(.+)");
	if not functionId or not linkCount or not reqId or not addon then
		debugOut("Malformed REQ data, aborting.")
		return
	end
	
	-- make sure the functionId and linkCount is converted to a number
	functionId, linkCount = tonumber(functionId), tonumber(linkCount);
	
	-- if the addon does not exist, abort
	if not CMH[addon] then
		CMH.SendNAK(reqId)
		debugOut("Invalid addon, aborting")
		return
	end
	
	-- if the functionId does not exist for said addon, abort
	if not CMH[addon][functionId] then
		CMH.SendNAK(reqId)
		debugOut("Invalid addon function, aborting")
		return
	end
	
	-- the request cache already exists, this should not happen. 
	-- abort and send error to the client, as well as purge id from cache.
	if(datacache[reqId]) then
		CMH.SendNAK(reqId)
		datacache[reqId] = nil
		debugOut("Request cache already exists, aborting.")
		return
	end
	
	-- Insert header info for request id and prepare temporary data storage
	datacache[reqId] = {addon = addon, funcId = functionId, count = linkCount, data = {}}
	
	-- send ACK to client notifying client that data is ready to be received
	debugOut("REQ OK, sending ACK..")
	CMH.SendACK(reqId)
end

function CMH.OnACK(sender, reqId)
	-- We received ACK but no data is available in cache. This should never happen
	if not datacache[reqId] then
		debugOut("ACK received but no data available to transmit. Aborting.")
		return
	end
	
	-- If data exists, we send it
	debugOut("ACK validated, data exists. Sending..")
	CMH.SendDAT(reqId)
end

function CMH.OnDAT(sender, data)
	-- Separate REQ ID from payload and verify
	local reqId, payload = data:match("(%w%w%w%w%w%w)(.*)");
	if not reqId and not payload then
		return
	end
	
	-- If no REQ header info has been cached, abort
	if not datacache[reqId] then
		debugOut("Data received, but not expected. Aborting.")
		return
	end
	
	local reqTable = datacache[reqId]
	local sizeOfDataCache = #reqTable.data
	
	-- Some functions are trigger functions and expect no payload
	-- Skip the rest of the functionality and call the expected function
	if reqTable.count == 0 then
		-- Retrieve the function from global namespace and pass variables if it exists 
		local func = SMH[reqTable.addon][reqTable.funcId]
		if func then
			debugOut(func)
			_G[func](sender, {})
			datacache[reqId] = nil
		end
		return
	end
	
	-- If the size of the cache is larger than expected, abort
	if sizeOfDataCache+1 > reqTable.count then
		debugOut("Received more data than expected. Aborting.")
		return
	end
	
	-- Add payload to cache and update size variable
	reqTable["data"][sizeOfDataCache+1] = payload
	sizeOfDataCache = #reqTable.data
	
	-- If the last expected message has been received, process it
	if(sizeOfDataCache == reqTable.count) then
		-- Concatenate the cache and parse the full payload for function variables to return
		local fullPayload = table.concat(reqTable.data);
		local VarTable = ParseMessage(reqTable.addon, fullPayload)
		
		-- Retrieve the function from global namespace and pass variables if it exists 
		local func = CMH[reqTable.addon][reqTable.funcId]
		if func then
			debugOut(func)
			_G[func](sender, VarTable)
		end
		
		-- Delete the request session cache
		datacache[reqId] = nil
	end
end

function CMH.OnNAK(sender, reqId)
	-- when we receive an error from the server, purge the local cache data
	debugOut("Purging cache data with REQ ID: "..reqId)
	datacache[reqId] = nil
end

-- Rx END

-- Tx START

function CMH.SendREQ(functionId, linkCount, reqId, addon)
	debugOut("Sending REQ with ID: "..reqId)
	local send = string.format("%01s%01s%02d%02d%02d%06s%0"..tostring(#addon).."s", CSMHMsgPrefix, "C", pck.REQ, functionId, linkCount, reqId, addon)
	SendAddonMessage(send, "", "WHISPER", UnitName("player"))
end

function CMH.SendACK(reqId)
	local send = string.format("%01s%01s%02d%06s", CSMHMsgPrefix, "C", pck.ACK, reqId)
	SendAddonMessage(send, "", "WHISPER", UnitName("player"))
end

function CMH.SendDAT(reqId)
	-- Build data message header
	local send = string.format("%01s%01s%02d%06s", CSMHMsgPrefix, "C", pck.DAT, reqId)
	
	-- iterate all items in the message data cache and send
	-- functions can also be trigger functions without any data, only send header and no payload
	if(#datacache[reqId]["data"] == 0) then
		SendAddonMessage(send, "", "WHISPER", UnitName("player"))
	else
		for _, v in pairs (datacache[reqId]["data"]) do
			local payload = send..v
			SendAddonMessage(payload, "", "WHISPER", UnitName("player"))
		end
	end
	
	-- all items have been sent, cache can be purged
	debugOut("All data sent, cleaning up cache.")
	datacache[reqId] = nil
end

function CMH.SendNAK(reqId)
	local send = string.format("%01s%01s%02d%06s", CSMHMsgPrefix, "C", pck.NAK, reqId)
	SendAddonMessage(send, "", "WHISPER", UnitName("player"))
end

-- Tx END

-- API START

function RegisterServerResponses(config)
	if(CMH[config.Prefix]) then
		return;
	end
	
	CMH[config.Prefix] = {}
	
	for functionId, functionName in pairs(config.Functions) do
		CMH[config.Prefix][functionId] = functionName
	end
end

function SendClientRequest(prefix, functionId, ...)
	local reqId = GenerateReqId()
	local varTable = ProcessVariables(reqId, ...)
	
	CMH.SendREQ(functionId, #varTable["data"], reqId, prefix)
end

--A API END