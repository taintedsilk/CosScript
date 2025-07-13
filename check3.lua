-- =================================================================
-- Script: Auto Spiral Chunk & Drop (Continuous)
-- Description: Continuously finds the nearest valuable carcass, teleports
-- the player in a spiral pattern, chunking and dropping food at each point.
-- =================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- =================================================================
-- Configuration
-- =================================================================
local MAX_DISTANCE = 200      -- How far to look for a carcass.
local NUM_DROPS = 20          -- How many times to chunk and drop per carcass.
local RADIUS_STEP = 3         -- How many studs the spiral grows outwards with each drop.
local ANGLE_STEP = math.pi / 6 -- The angle change for each drop (pi/6 = 30 degrees).
local DELAY_BETWEEN_DROPS = 0.25 -- Seconds to wait between each drop.
local DELAY_BETWEEN_SEARCHES = 2 -- Seconds to wait if no carcass is found.

-- A list of all valid carcass names to target.
local VALID_CARCASS_NAMES = {
    ["Carcass"] = true,
    ["Sea Carcass"] = true,
    ["Herbivore Carcass"] = true,
    ["Omnivore Carcass"] = true,
    ["Carnivore Carcass"] = true
}

-- =================================================================
-- Helper Functions
-- =================================================================
local function getItemPosition(item)
    if not item then return nil end
	if item:IsA("BasePart") then
		return item.Position
	elseif item:IsA("Model") and item.PrimaryPart then
		return item.PrimaryPart.Position
	end
	return nil
end

-- =================================================================
-- Main Logic
-- =================================================================
task.spawn(function()
    print("Initializing Continuous Spiral Chunk & Drop script...")

    -- Wait for remotes and containers to exist
    local FoodChunkRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FoodChunk")
    local DropRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Drop")
    local FoodContainer = workspace:WaitForChild("Interactions"):WaitForChild("Food")

    if not (FoodChunkRemote and DropRemote and FoodContainer) then
        warn("Could not find necessary Remotes or Food container. Aborting.")
        return
    end

    -- Main loop to continuously find and process carcasses
    while true do
        local character = LocalPlayer.Character
        if not (character and character.Parent) then
            print("Player character not found. Waiting...")
            LocalPlayer.CharacterAdded:Wait()
            print("Character found. Resuming.")
            character = LocalPlayer.Character
        end
        
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then
            warn("Player HumanoidRootPart not found. Skipping cycle.")
            task.wait(DELAY_BETWEEN_SEARCHES)
            continue -- Skips to the next iteration of the while loop
        end

        local playerPosition = rootPart.Position

        -- Step 1: Find the best single carcass to use for the current sequence
        local targetCarcass = nil
        local minDistance = MAX_DISTANCE

        for _, foodItem in ipairs(FoodContainer:GetChildren()) do
            -- Check if the name is in our valid list and it has a value > 10
            if VALID_CARCASS_NAMES[foodItem.Name] and foodItem:GetAttribute("Value") > 10 then
                local itemPos = getItemPosition(foodItem)
                if itemPos then
                    local distance = (playerPosition - itemPos).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        targetCarcass = foodItem
                    end
                end
            end
        end

        -- If we found a valid carcass, start the sequence. Otherwise, wait and search again.
        if targetCarcass then
            print("Target found: " .. targetCarcass.Name .. ". Starting spiral drop sequence.")
            
            -- Step 2: Begin the spiral teleport and drop loop
            local startCFrame = rootPart.CFrame

            for i = 1, NUM_DROPS do
                -- Re-check if the character and target still exist before each action
                if not (targetCarcass and targetCarcass:GetAttribute("Value") > 10) then
                    print("Player, target carcass, or its value was removed. Finding new target.")
                    break -- Exit the for loop to find a new carcass
                end

                -- Calculate spiral position
                local angle = i * ANGLE_STEP
                local radius = i * RADIUS_STEP
                
                -- Calculate the offset from the starting position on the XZ plane
                local offsetX = radius * math.cos(angle)
                local offsetZ = radius * math.sin(angle)
                local targetPosition = startCFrame.Position + Vector3.new(offsetX, 0, offsetZ)

                -- Teleport the player to the calculated point
                rootPart.CFrame = CFrame.new(targetPosition)
                task.wait(0.1) -- Short wait for physics to settle

                -- Perform the chunk and drop actions
                print(string.format("Dropping chunk %d/%d at spiral point.", i, NUM_DROPS))
                FoodChunkRemote:InvokeServer(targetCarcass)
                DropRemote:FireServer()

                -- Wait before the next iteration
                task.wait(DELAY_BETWEEN_DROPS)
            end
            
            print("Finished spiral for this target.")

        else
            -- If we didn't find a valid carcass, wait before searching again.
            print("No valid carcass with Value > 10 found within " .. MAX_DISTANCE .. " studs. Searching again in " .. DELAY_BETWEEN_SEARCHES .. "s.")
            task.wait(DELAY_BETWEEN_SEARCHES)
        end
    end
end)
