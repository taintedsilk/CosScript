-- =================================================================
-- Script: Auto Spiral Chunk & Drop (Constant Search Version)
-- Description: Teleports the player in a spiral pattern. At each
-- point, it finds the nearest valuable carcass, chunks it, and
-- drops the food.
-- =================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- =================================================================
-- Configuration
-- =================================================================
local MAX_DISTANCE = 200      -- How far to look for a carcass from each spiral point.
local NUM_DROPS = 50          -- How many times to chunk and drop, creating points in the spiral.
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

-- New function to find the closest carcass from a given position.
local function findClosestValidCarcass(searchPosition, maxSearchDistance)
    local foodContainer = workspace:GetService("Interactions"):FindFirstChild("Food")
    if not foodContainer then return nil end

    local bestTarget = nil
    local minDistance = maxSearchDistance

    for _, foodItem in ipairs(foodContainer:GetChildren()) do
        -- Check if the name is in our valid list and it has a value > 10
        if VALID_CARCASS_NAMES[foodItem.Name] and foodItem:GetAttribute("Value") > 10 then
            local itemPos = getItemPosition(foodItem)
            if itemPos then
                local distance = (searchPosition - itemPos).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    bestTarget = foodItem
                end
            end
        end
    end
    return bestTarget
end

-- =================================================================
-- Main Logic
-- =================================================================
task.spawn(function()
    print("Initializing Spiral Chunk & Drop script (Constant Search Mode)...")

    -- Wait for remotes to exist
    local FoodChunkRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FoodChunk")
    local DropRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Drop")

    if not (FoodChunkRemote and DropRemote) then
        warn("Could not find necessary Remotes. Aborting.")
        return
    end

    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")
    
    if not rootPart then
        warn("Player HumanoidRootPart not found. Aborting.")
        return
    end

    print("Starting spiral drop sequence.")
    
    -- Store the starting position to return to at the end
    local startCFrame = rootPart.CFrame

    -- Begin the spiral teleport and drop loop
    for i = 1, NUM_DROPS do
        -- Check if the character still exists
        if not (character and character.Parent) then
             print("Player character was removed. Stopping sequence.")
             break
        end

        -- Step 1: Calculate spiral position
        local angle = i * ANGLE_STEP
        local radius = i * RADIUS_STEP
        
        -- Calculate the offset from the starting position on the XZ plane
        local offsetX = radius * math.cos(angle)
        local offsetZ = radius * math.sin(angle)
        local targetPosition = startCFrame.Position + Vector3.new(offsetX, 0, offsetZ)

        -- Step 2: Teleport the player to the calculated point
        rootPart.CFrame = CFrame.new(targetPosition)
        task.wait(0.1) -- Short wait for physics to settle after teleport

        -- Step 3: Find the closest carcass from the NEW position
        local targetCarcass = findClosestValidCarcass(rootPart.Position, MAX_DISTANCE)

        -- Step 4: Perform the chunk and drop actions if a carcass was found
        if targetCarcass then
            print(string.format("Chunk %d/%d: Found '%s'. Dropping at spiral point.", i, NUM_DROPS, targetCarcass.Name))
            FoodChunkRemote:InvokeServer(targetCarcass)
            DropRemote:FireServer()
        else
            warn(string.format("Chunk %d/%d: No valid carcass found within %d studs of this spiral point. Skipping drop.", i, NUM_DROPS, MAX_DISTANCE))
        end

        -- Wait before the next iteration
        task.wait(DELAY_BETWEEN_DROPS)
    end
    
    -- Teleport back to the original position after finishing
    rootPart.CFrame = startCFrame
    print("Spiral chunk and drop sequence finished. Returned to start location.")
end)
