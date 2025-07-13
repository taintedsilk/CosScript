-- This must be a LocalScript in a client-side container (e.g., StarterPlayerScripts).
-- It uses a debug-only function and should not be used in a production game.

print("HOOKER: Preparing to hook UserInputService.InputBegan")

local UserInputService = game:GetService("UserInputService")
local inputBeganEvent = UserInputService.InputBegan

-- We need to store the original :Connect function to call it later.
-- hookmetamethod will return it to us.
local originalConnect

-- This is the function that will replace the event's original :Connect method.
local function hookedConnect(self, listenerFunction)
	-- 'self' is the event object itself (inputBeganEvent).
	-- 'listenerFunction' is the function that another script is trying to connect.
	
	print("HOOKER: Intercepted a :Connect call to InputBegan!")

	-- This is the core of our hook. We create a NEW function that wraps the old one.
	local wrappedListener = function(inputObject, gameProcessedEvent)
		-- Our spy logic goes here. We run it BEFORE the original function.
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			print("HOOKER: Mouse 1 Click was TRIGGERED! Firing original listener now.")
			-- We could even choose to *not* call the original listener here
			-- if we wanted to "swallow" or block the input from other scripts.
		end
		
		-- IMPORTANT: Call the original function that the other script provided.
		-- This ensures we don't break the game's functionality.
		-- We use a pcall for safety in case the original listener function errors.
		pcall(listenerFunction, inputObject, gameProcessedEvent)
	end

	-- Now, we call the *original* :Connect method, but we pass our
	-- new "wrapped" function instead of the one we received.
	return originalConnect(self, wrappedListener)
end

-- Here is where we actually apply the hook.
-- We will hook __namecall because it's the metamethod that fires for colon-syntax calls like "Event:Connect()".
local success, hooker = pcall(function()
	return hookmetamethod(inputBeganEvent, "__namecall")
end)

if not success then
	warn("HOOKER: Failed to get hookmetamethod. The script may not have the required permission level.")
	return
end

-- The hooker function applies our new function and returns the original one.
local originalNamecall = hooker(function(self, ...)
	local args = {...}
	local methodName = args[1]
	
	-- We only care about hijacking the "Connect" method.
	if methodName == "Connect" then
		-- When we called originalConnect for the first time, it didn't exist yet.
		-- Let's create a temporary version of it by calling the original namecall.
		if not originalConnect then
			originalConnect = function(...) return originalNamecall(...) end
		end
		
		-- Redirect the call to our custom hookedConnect function.
		return hookedConnect(self, args[2])
	end
	
	-- For any other method calls (like :Wait()), let them pass through normally.
	return originalNamecall(self, ...)
end)

print("HOOKER: Hook on InputBegan is active. Waiting for clicks...")

-- ===================================================================
-- DEMONSTRATION: This part simulates another script in your game.
-- Our hook will intercept this connection below.
-- ===================================================================
wait(1)
print("\nDEMO: A separate script is now connecting to InputBegan...")

UserInputService.InputBegan:Connect(function(input, isTyping)
	if isTyping then return end
	
	if input.UserInputType == Enum.UserInputType.Keyboard then
		print("DEMO SCRIPT: A key was pressed: " .. input.KeyCode.Name)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		print("DEMO SCRIPT: I detected a mouse click!")
	end
end)

print("DEMO: Connection complete. Try clicking or typing!")
