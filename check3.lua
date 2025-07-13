-- =================================================================
-- Script: Auto Spiral Chunk & Drop
-- Description: Finds a valuable carcass, then teleports the player
-- in a spiral pattern, chunking and dropping food at each point.
-- =================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- =================================================================
-- Configuration
-- =================================================================
local MAX_DISTANCE = 200      -- How far to look for a carcass.
local NUM_DROPS = 50          -- How many times to chunk and drop, creating 20 points in the spiral.
local RADIUS_STEP = 3         -- How many studs the spiral grows outwards with each drop.
local ANGLE_STEP = math.pi / 6 -- The angle change for each drop (pi/6 = 30 degrees). A smaller value makes the spiral tighter.
local DELAY_BETWEEN_DROPS = 0.25 -- Seconds to wait between each drop.

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
    print("Initializing Spiral Chunk & Drop script...")

    -- Wait for remotes and containers to exist
    local FoodChunkRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FoodChunk")
    local DropRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Drop")
    local FoodContainer = workspace:WaitForChild("Interactions"):WaitForChild("Food")

    if not (FoodChunkRemote and DropRemote and FoodContainer) then
        warn("Could not find necessary Remotes or Food container. Aborting.")
        return
    end

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")
    
    if not rootPart then
        warn("Player HumanoidRootPart not found. Aborting.")
        return
    end

    local playerPosition = rootPart.Position

    -- Step 1: Find the best single carcass to use for the entire sequence
    local targetCarcass = nil
    local minDistance = MAX_DISTANCE

    for _, foodItem in ipairs(FoodContainer:GetChildren()) do
        -- Check if the name is in our valid list and it has a value > 0
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

    -- If we didn't find a valid carcass, stop the script.
    if not targetCarcass then
        print("No valid carcass with Value > 0 found within " .. MAX_DISTANCE .. " studs. Stopping.")
        return
    end

    print("Target found: " .. targetCarcass.Name .. ". Starting spiral drop sequence.")
    
    -- Step 2: Begin the spiral teleport and drop loop
    local startCFrame = rootPart.CFrame

    for i = 1, NUM_DROPS do
        -- Check if the character and target still exist
        if not (character and character.Parent and targetCarcass and targetCarcass.Parent) then
             print("Player or target carcass was removed. Stopping sequence.")
             break
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
        task.wait(0.1) -- Short wait for physics to settle after teleport

        -- Perform the chunk and drop actions
        print(string.format("Dropping chunk %d/%d at spiral point.", i, NUM_DROPS))
        FoodChunkRemote:InvokeServer(targetCarcass)
        DropRemote:FireServer()

        -- Wait before the next iteration
        task.wait(DELAY_BETWEEN_DROPS)
    end
    
    -- Teleport back to the original position after finishing
    rootPart.CFrame = startCFrame
    print("Spiral chunk and drop sequence finished. Returned to start location.")
end)
