--======================================================================
-- Services and Remotes
--======================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Wait for the necessary remote events and functions to exist
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local foodChunkRemote = remotesFolder:WaitForChild("FoodChunk")
local dropRemote = remotesFolder:WaitForChild("Drop")

-- Folder where all carcasses are stored
local foodFolder = Workspace:WaitForChild("Interactions"):WaitForChild("Food")

--======================================================================
-- Player and Character Setup
--======================================================================
local player = Players.LocalPlayer
-- Wait for the player's character to be loaded
local character = player.Character or player.CharacterAdded:Wait()
-- The HumanoidRootPart is the most reliable part for getting a character's position
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

--======================================================================
-- Main Logic
--======================================================================

-- This function will find, sort, and process all carcasses
local function chunkAndDropAllCarcasses()
	print("Starting carcass processing...")

	-- 1. Get all current carcasses
	local allCarcasses = {}
	for _, child in ipairs(foodFolder:GetChildren()) do
		-- Make sure it's actually a carcass and is a physical part we can get distance from
		if child.Name == "Carcass" and child:IsA("BasePart") then
			table.insert(allCarcasses, child)
		end
	end

	if #allCarcasses == 0 then
		print("No carcasses found to process.")
		return -- Exit the function if there's nothing to do
	end
	
	print("Found " .. #allCarcasses .. " carcasses. Sorting them by distance...")

	-- 2. Sort the carcasses from nearest to farthest
	local playerPosition = humanoidRootPart.Position
	table.sort(allCarcasses, function(carcassA, carcassB)
		local distanceA = (carcassA.Position - playerPosition).Magnitude
		local distanceB = (carcassB.Position - playerPosition).Magnitude
		-- Return true if A is closer than B, sorting A before B
		return distanceA < distanceB
	end)

	print("Carcasses sorted. Beginning processing loop.")

	-- 3. Loop through the sorted list and process each one
	for i, carcass in ipairs(allCarcasses) do
		-- A sanity check to ensure the carcass wasn't destroyed by something else
		if not (carcass and carcass.Parent) then
			print("Carcass #" .. i .. " was removed before it could be processed. Skipping.")
			continue -- Skip to the next iteration of the loop
		end
		
		print("Processing carcass #" .. i .. ": " .. carcass:GetFullName())
		
		-- Step A: Invoke the server to "chunk" the carcass
		-- We wrap this in a pcall (protected call) in case the server call fails
		local success, result = pcall(function()
			-- The remote function expects the carcass instance inside a table
			local args = { carcass }
			return foodChunkRemote:InvokeServer(unpack(args))
		end)

		if not success then
			-- If the server call failed, print the error and move on
			warn("Failed to chunk carcass #" .. i .. ". Error: ", result)
			continue
		end

		print("Successfully chunked. Preparing to drop.")
		
		-- Optional small wait: gives the server a moment to process the chunking
		-- before we ask it to drop the result. Can prevent race conditions.
		task.wait(0.1)

		-- Step B: Fire the server to "drop" the item
		dropRemote:FireServer()
		print("Drop command sent for chunked item.")

		-- Step C: Wait 1 second before processing the next carcass
		-- We don't need to wait after the very last one
		if i < #allCarcasses then
			print("Waiting 1 second before next carcass...")
			task.wait(1)
		end
	end

	print("Finished processing all carcasses.")
end

task.wait(3)
chunkAndDropAllCarcasses()
