if _G.ws then return end

local everyWebSocket = WebSocket or websocket or (Krnl and Krnl.WebSocket) or (syn and syn.websocket)
local everyClipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
local queueteleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
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

local username = game.Players.LocalPlayer.Name
local userId = game.Players.LocalPlayer.UserId
local randomString = generateRandomString(9)
local randomNumber = Random.new():NextInteger(100000000, 999999999)
local token = string.format("%s-%d-%s-%d", username, userId, randomString, randomNumber)

if not everyClipboard then
	notify("Missing Functionality", "Clipboard function is not supported on this executor.")
	return
end
if not everyWebSocket then
	notify("Missing Functionality", "WebSocket function is not supported on this executor.")
	return
end

everyClipboard(token)
notify("Client Token", "Token copied to clipboard: " .. token)

pcall(function()
	_G.ws = everyWebSocket.connect(url)
end)

local ws = _G.ws
if ws then
	notify("WebSocket", "Successfully connected to WebSocket server.")
		
	ws:Send(token)

	ws.OnMessage:Connect(function(message)
		local success, err = pcall(function()
			loadstring(message)()
		end)
		if not success then
			notify("Error", "Script execution failed: " .. tostring(err))
		end
	end)

	ws.OnClose:Connect(function()
		notify("WebSocket", "Connection to WebSocket server closed.")
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(plr)
		if plr == game:GetService("Players").LocalPlayer then
			ws:Close()
		end
	end)

	game:GetService("Players").LocalPlayer.OnTeleport:Connect(function()
		queueteleport([[
			loadstring(game:HttpGet("https://ryxeleron.github.io/storage/other-stuff/iyr-execution/"))()
		]])
		ws:Close()
	end)
else
	notify("WebSocket", "Failed to connect to WebSocket server.")
end