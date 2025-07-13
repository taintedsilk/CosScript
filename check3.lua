local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Helper to get the position of a Model or Part
local function getItemPosition(item)
    if not item then return nil end
	if item:IsA("BasePart") then
		return item.Position
	elseif item:IsA("Model") and item.PrimaryPart then
		return item.PrimaryPart.Position
	end
	return nil
end

-- Main function to run the logic
task.spawn(function()
    print("Starting chunk and drop sequence...")

    -- Define the remotes
    local FoodChunkRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("FoodChunk")
    local DropRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Drop")
    local FoodContainer = workspace:WaitForChild("Interactions"):WaitForChild("Food")

    if not (FoodChunkRemote and DropRemote and FoodContainer) then
        warn("Could not find necessary Remotes or Food container. Aborting.")
        return
    end

    -- Loop 10 times with a 1-second delay
    for i = 1, 10 do
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if not rootPart then
            warn("Player character or HumanoidRootPart not found. Stopping.")
            break
        end

        -- Find the closest valid carcass within 200 studs
        local closestCarcass = nil
        local minDistance = 200 -- Max distance check

        for _, foodItem in ipairs(FoodContainer:GetChildren()) do
            if foodItem.Name == "Carcass" or foodItem.Name == "Sea Carcass" then
                local itemPos = getItemPosition(foodItem)
                if itemPos then
                    local distance = (rootPart.Position - itemPos).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        closestCarcass = foodItem
                    end
                end
            end
        end

        -- If a carcass was found, perform the actions
        if closestCarcass then
            print("Found closest carcass: " .. closestCarcass.Name .. ". Chunking and dropping... (" .. i .. "/10)")
            
            -- Chunk the food from the carcass
            FoodChunkRemote:InvokeServer(closestCarcass)

            -- Drop the chunked item
            DropRemote:FireServer()
        else
            print("No carcass found within 200 studs. Stopping.")
            break -- Exit the loop if no target is available
        end

        task.wait(1) -- Wait for 1 second before the next iteration
    end

    print("Chunk and drop sequence finished.")
end)
