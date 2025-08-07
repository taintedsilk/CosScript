local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- UI Paths for Vitals
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local HungerLabel = PlayerGui:WaitForChild("CreatureInfoGui"):WaitForChild("ContainerFrame"):WaitForChild("TabFrames"):WaitForChild("MyCreature"):WaitForChild("StatsFrame"):WaitForChild("VitalityFrame"):WaitForChild("Hunger"):WaitForChild("AmountLabel")
local ThirstLabel = PlayerGui:WaitForChild("CreatureInfoGui"):WaitForChild("ContainerFrame"):WaitForChild("TabFrames"):WaitForChild("MyCreature"):WaitForChild("StatsFrame"):WaitForChild("VitalityFrame"):WaitForChild("Thirst"):WaitForChild("AmountLabel")


-- Helper to parse vital stats like "10/100"
local function getVitals(label)
	if not label then return 0, 1 end
	-- Use string matching to safely extract current and max values
	local current, max = label.Text:match("([%d,]+)/([%d,]+)")
	if current and max then
		-- Remove commas for proper conversion to number
		current = tonumber(current:gsub(",", ""))
		max = tonumber(max:gsub(",", ""))
		if current and max then
			return current, max
		end
	end
	-- Return a default value that ensures the condition passes if parsing fails
	return 0, 1
end


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
                    local currentThirst, maxThirst = getVitals(ThirstLabel)
                    
                    if (currentThirst / maxThirst) < 0.95 then
                        local BestLake = GetChildWithHighestAttribute(LakesContainer, "Water", function(Child)
                            return not Child:GetAttribute("Sickly")
                        end)
                        if BestLake then
                            local waterAmount = BestLake:GetAttribute("Water")
                            print("Thirst at " .. currentThirst .. "/" .. maxThirst .. ". Drinking from: " .. BestLake.Name .. " (Water: " .. tostring(waterAmount) .. ").")
                            local args = { BestLake }
                            DrinkRemote:FireServer(unpack(args))
                        end
                    else
                        print("Thirst is above 95%. Skipping.")
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
    Desc = "Eats a random, valid food item nearby.",
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
                    local currentHunger, maxHunger = getVitals(HungerLabel)

                    if (currentHunger / maxHunger) < 0.95 then
                        local character = LocalPlayer.Character
                        if not character then continue end
                        local rootPart = character:FindFirstChild("HumanoidRootPart")
                        if not rootPart then continue end

                        local playerPosition = rootPart.Position
                        local MAX_DISTANCE = 200
                        local validFoods = {}

                        for _, item in ipairs(FoodContainer:GetChildren()) do
                            -- Check 1: Distance
                            local itemPosition = getItemPosition(item)
                            if not itemPosition or (playerPosition - itemPosition).Magnitude > MAX_DISTANCE then
                                continue
                            end

                            -- Check 2: Not rotten
                            if item:GetAttribute("rotten") then
                                continue
                            end

                            -- Check 3: Value is nil or greater than 0
                            local val = item:GetAttribute("Value")
                            if val == nil or (typeof(val) == "number" and val > 0) then
                                table.insert(validFoods, item)
                            end
                        end

                        if #validFoods > 0 then
                            -- Pick a random food from the valid list
                            local randomFood = validFoods[math.random(1, #validFoods)]
                            print("Hunger at " .. currentHunger .. "/" .. maxHunger .. ". Randomly eating: " .. randomFood.Name)
                            FoodRemote:FireServer(randomFood)
                        end
                    else
                        print("Hunger is above 95%. Skipping.")
                    end
                end
                print("Auto Eat stopped.")
            end)
        end
    end,
})
