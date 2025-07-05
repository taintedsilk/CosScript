-- =================================================================
-- Prerequisites & Helper Functions
-- =================================================================

-- Make sure you do NOT have a line like 'local loadstring = "..."' anywhere above this!

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Helper for "Auto Drink"
local function GetChildWithHighestAttribute(container, attributeName, customCheck)
    local childWithHighestValue = nil
    local highestValue = -math.huge
    if not container then return nil end
    for _, child in ipairs(container:GetChildren()) do
        local checkPassed = customCheck and customCheck(child) or true
        if checkPassed then
            local attrValue = child:GetAttribute(attributeName)
            if attrValue and typeof(attrValue) == "number" and attrValue > highestValue then
                highestValue = attrValue
                childWithHighestValue = child
            end
        end
    end
    return childWithHighestValue
end

-- Helper for "Auto Eat"
local function getItemPosition(item)
	if item:IsA("BasePart") then
		return item.Position
	elseif item:IsA("Model") then
		return item.PrimaryPart and item.PrimaryPart.Position or item:GetPivot().Position
	end
	return nil
end


-- =================================================================
-- WindUI Setup
-- =================================================================

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "My Script",
    Author = "User",
    Size = UDim2.fromOffset(580, 400),
    Folder = "MyScriptFolder"
})

local MainTab = Window:Tab({
    Title = "Automation",
    Icon = "sparkles"
})


-- =================================================================
-- Flags to Control Toggles
-- =================================================================

local Flags = {
    AutoDrink = false,
    AutoEat = false
}


-- =================================================================
-- Auto Drink Toggle
-- =================================================================

MainTab:Toggle({
    Title = "💧 Auto Drink",
    Desc = "Automatically drinks from the lake with the most water.",
    Value = false,
    Callback = function(value)
        Flags.AutoDrink = value
        if Flags.AutoDrink then
            task.spawn(function()
                local DrinkRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("DrinkRemote")
                local LakesContainer = workspace:WaitForChild("Interactions"):WaitForChild("Lakes")
                if not DrinkRemote or not LakesContainer then return end
                
                print("Auto Drink started.")
                while Flags.AutoDrink and task.wait(1) do
                    local BestLake = GetChildWithHighestAttribute(LakesContainer, "Water", function(Child)
                        return not Child:GetAttribute("Sickly")
                    end)
                    if BestLake then
                        local waterAmount = BestLake:GetAttribute("Water")
                        print("Found best lake: " .. BestLake.Name .. " (Water: " .. tostring(waterAmount) .. "). Firing remote.")
                        local args = { BestLake }
                        DrinkRemote:FireServer(unpack(args))
                    end
                end
                print("Auto Drink stopped.")
            end)
        end
    end,
})

-- =================================================================
-- Auto Eat Toggle
-- =================================================================

MainTab:Toggle({
    Title = "🍔 Auto Eat",
    Desc = "Automatically eats the highest-priority food nearby.",
    Value = false,
    Callback = function(value)
        Flags.AutoEat = value

        if Flags.AutoEat then
            task.spawn(function()
                local FoodContainer = workspace:WaitForChild("Interactions"):WaitForChild("Food")
                local FoodRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Food")
                if not FoodContainer or not FoodRemote then return end

                print("Auto Eat started.")
                while Flags.AutoEat and task.wait(1) do
                    local character = LocalPlayer.Character
                    if not character then continue end
                    local rootPart = character:FindFirstChild("HumanoidRootPart")
                    if not rootPart then continue end

                    local playerPosition = rootPart.Position
                    local MAX_DISTANCE = 200
                    local priority1_foods, priority2_foods, priority3_foods = {}, {}, {}

                    for _, item in ipairs(FoodContainer:GetChildren()) do
                        local itemPosition = getItemPosition(item)
                        if not itemPosition or (playerPosition - itemPosition).Magnitude > MAX_DISTANCE then
                            continue
                        end

                        local name = item.Name
                        if name == "Seaweed Pods" or name == "Berries" or name == "Plant Carcass" then
                            if not item:GetAttribute("rotten") then
                                table.insert(priority1_foods, item)
                            end
                        elseif name == "Fruit" then
                            local val = item:GetAttribute("Value")
                            if val and typeof(val) == "number" and val > 0 then
                                table.insert(priority2_foods, item)
                            end
                        elseif name == "Grass" or name == "Algae" then
                            table.insert(priority3_foods, item)
                        end
                    end

                    local bestTarget = nil
                    local targetList = #priority1_foods > 0 and priority1_foods or (#priority2_foods > 0 and priority2_foods or (#priority3_foods > 0 and priority3_foods))
                    
                    if targetList then
                        local closestDistance = math.huge
                        for _, food in ipairs(targetList) do
                            local dist = (playerPosition - getItemPosition(food)).Magnitude
                            if dist < closestDistance then
                                closestDistance = dist
                                bestTarget = food
                            end
                        end
                    end

                    if bestTarget then
                        -- FIXED: Print the name *before* firing the remote to avoid an error.
                        print("Eating best target: " .. bestTarget.Name)
                        FoodRemote:FireServer(bestTarget)
                    end
                end
                print("Auto Eat stopped.")
            end)
        end
    end,
})
