--===================================================================
--                      CONFIGURATION
--===================================================================

-- Set to 'false' in your executor console to stop the loop
_G.RunCrystalMover = true 

-- How far in front of you the crystals should appear
local DISTANCE_IN_FRONT = 30

-- How far apart the crystals should be from each other
local SPACING = 2 

-- The size multiplier (0.5 means 50% of their original size)
local SIZE_MULTIPLIER = 0.5

print("Crystal Mover script started. To stop, set _G.RunCrystalMover to false.")

--===================================================================
--                      SETUP
--===================================================================

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local crystalSpawnsFolder = workspace:WaitForChild("Lego_Interactions"):WaitForChild("CrystalSpawns")

--===================================================================
--                      MAIN LOOP
--===================================================================

while _G.RunCrystalMover and task.wait(3) do
    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")

    -- If player's character or root part doesn't exist, skip this cycle
    if not rootPart then
        continue -- Skips to the next 'task.wait(1)'
    end

    local horizontalOffset = 0
    local crystalsFound = 0

    -- Find all crystals on every loop, since they get recreated
    for _, spawnFolder in ipairs(crystalSpawnsFolder:GetChildren()) do
        -- Check if the item is a Model/Folder and contains a crystal
        if spawnFolder:IsA("Configuration") or spawnFolder:IsA("Model") then
            local crystal = spawnFolder:FindFirstChild("Crystal")

            if crystal and crystal:IsA("BasePart") then
                -- This is a valid crystal, let's move it
                crystalsFound = crystalsFound + 1

                -- Calculate the position in a line in front of the player
                local targetCFrame = rootPart.CFrame * CFrame.new(horizontalOffset, 0, -DISTANCE_IN_FRONT)
                
                -- Apply the changes
                crystal.Anchored = true
                crystal.size = crystal.size * SIZE_MULTIPLIER
                crystal.CFrame = targetCFrame

                -- Update the offset so the next crystal doesn't stack on top
                horizontalOffset = horizontalOffset + SPACING
            end
        end
    end
    
    -- Center the line of crystals in front of the player
    if crystalsFound > 0 then
        local totalWidth = (crystalsFound - 1) * SPACING
        local startingOffset = -totalWidth / 2
        
        local currentOffset = startingOffset
        for _, spawnFolder in ipairs(crystalSpawnsFolder:GetChildren()) do
             local crystal = spawnFolder:FindFirstChild("Crystal")
             if crystal and crystal:IsA("BasePart") and crystal.Anchored then -- Only move crystals we've processed
                local targetCFrame = rootPart.CFrame * CFrame.new(currentOffset, 0, -DISTANCE_IN_FRONT)
                crystal.CFrame = targetCFrame
                currentOffset = currentOffset + SPACING
            end
        end
    end
end

print("Crystal Mover script has been stopped.")
