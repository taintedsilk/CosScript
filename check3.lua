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

-- This function will find, sort, and process all carcass models
local function chunkAndDropAllCarcasses()
	print("Starting carcass processing...")

	-- 1. Get all current carcass models that have a PrimaryPart
	local allCarcasses = {}
	for _, child in ipairs(foodFolder:GetChildren()) do
		-- Check if it's a model named "Carcass"
		if child.Name == "Carcass" and child:IsA("Model") then
			-- A model's position is determined by its PrimaryPart. If it's not set, we can't get a location.
			if child.PrimaryPart then
				table.insert(allCarcasses, child)
			else
				-- Warn the developer in the output if a carcass is missing its PrimaryPart
				warn("Carcass model found ('" .. child:GetFullName() .. "') but it has no PrimaryPart set. It will be skipped.")
			end
		end
	end

	if #allCarcasses == 0 then
		print("No valid carcasses found to process.")
		return -- Exit the function if there's nothing to do
	end
	
	print("Found " .. #allCarcasses .. " carcasses. Sorting them by distance...")

	-- 2. Sort the carcasses from nearest to farthest using their PrimaryPart's position
	local playerPosition = humanoidRootPart.Position
	table.sort(allCarcasses, function(carcassA, carcassB)
		-- Get the position from the PrimaryPart of each model
		local distanceA = (carcassA.PrimaryPart.Position - playerPosition).Magnitude
		local distanceB = (carcassB.PrimaryPart.Position - playerPosition).Magnitude
		-- Return true if A is closer than B, sorting A before B
		return distanceA < distanceB
	end)

	print("Carcasses sorted. Beginning processing loop.")

	-- 3. Loop through the sorted list and process each one
	for i, carcassModel in ipairs(allCarcasses) do
		-- A sanity check to ensure the model wasn't destroyed by something else
		if not (carcassModel and carcassModel.Parent) then
			print("Carcass #" .. i .. " was removed before it could be processed. Skipping.")
			continue -- Skip to the next iteration of the loop
		end
		
		print("Processing carcass #" .. i .. ": " .. carcassModel:GetFullName())
		
		-- Step A: Invoke the server to "chunk" the carcass model
		-- We wrap this in a pcall (protected call) to prevent server errors from stopping the loop
		local success, result = pcall(function()
            -- Sending the model instance directly is cleaner than packing/unpacking a single-item table
			return foodChunkRemote:InvokeServer(carcassModel)
		end)

		if not success then
			-- If the server call failed, print the error and move on
			warn("Failed to chunk carcass #" .. i .. ". Error: ", result)
			continue
		end

		print("Successfully chunked. Preparing to drop.")
		
		task.wait(0.1) -- Small delay to allow server to process before dropping

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

-- You can call this function whenever you want the process to start.
-- For this example, we'll just run it once, 3 seconds after the script starts.
task.wait(3)
chunkAndDropAllCarcasses()
