if _G.ws then return end

local everywebsocket = WebSocket or websocket or (Krnl and Krnl.WebSocket) or (syn and syn.websocket)
local url = "ws://api.iyr.lol:0/"
local function generateRandomString(length)
	local charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
	local result = ''
	for i = 1, length do
		local rand = math.random(1, #charset)
		result = result .. string.sub(charset, rand, rand)
	end
	return result
end
local everyClipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
local username = game.Players.LocalPlayer.Name
local userId = game.Players.LocalPlayer.UserId
local randomString = generateRandomString(9)
local randomNumber = Random.new():NextInteger(100000000, 999999999)
local token = string.format("%s-%d-%s-%d", username, userId, randomString, randomNumber)
local queueteleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)

if everyClipboard and everywebsocket then else warn("Unsupported executor"); return end

everyClipboard(token)

print("Generated token: " .. token)

pcall(function()
	_G.ws = everywebsocket.connect(url)
end)

local ws = _G.ws
if ws then
	print("Connected to WebSocket server")
	
	-- added this cuz funny
	loadstring(game:HttpGet("https://storage.iyr.lol/other-stuff/changeexecutoridentiyfr.lua"))

	ws:Send(token)

	ws.OnMessage:Connect(function(message)
		local success, err = pcall(function()
			loadstring(message)()
			return
		end)
		if not success then
			print("Error executing script:", err)
		end
		return
	end)

	ws.OnClose:Connect(function()
		print("WebSocket connection closed")
	end)
	
	game:GetService("Players").PlayerRemoving:Connect(function(plr)
		if plr == game:GetService("Players").LocalPlayer then
			ws:Close()
		end
	end)
	game:GetService("Players").LocalPlayer.OnTeleport:Connect(function()
		queueteleport([[
			loadstring(game:HttpGet("https://storage.iyr.lol/other-stuff/iyr-execution.lua"))
		]])
		ws:Close()
	end)
else
	print("Failed to connect to WebSocket server")
end