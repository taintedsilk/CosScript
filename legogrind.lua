local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Ensure PlayerGui is available
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Define all necessary remotes
local DeleteSlotRemote = Remotes:WaitForChild("DeleteSlotRemote")
local StartLegoEventRemote = Remotes:WaitForChild("StartLegoEvent")
local LegoEggDestroyedRemote = Remotes:WaitForChild("LegoEggDestroyed")
local SpawnRemote = Remotes:WaitForChild("SpawnRemote")

-- A local signal to bridge the hook and our waiting function
local spawnInvokedSignal = Instance.new("BindableEvent")

-- ======================= THE HOOK =======================
-- This is working correctly and remains unchanged.
local oldIndex
oldIndex = hookmetamethod(game, "__index", function(target, key)
    local originalMember = oldIndex(target, key)
    if target == SpawnRemote and key == "InvokeServer" then
        return function(...)
            local args = {...}
            
            -- Debug printing of arguments
            -- for i, argument in ipairs(args) do
            --     print(string.format("  - Arg #%d: %s (Type: %s)", i, tostring(argument), type(argument)))
            -- end

            local slotName = args[2] -- The actual slot name
            if type(slotName) == "string" then
                spawnInvokedSignal:Fire(slotName)
            else
                warn("HOOK: Argument #2 was not a string.")
            end

            return originalMember(...)
        end
    end
    return originalMember
end)
-- =========================================================

-- This helper function processes a single slot to the reputation target.
-- It remains unchanged.
local function processSingleSlot(slotName)
    local reputationStat = PlayerGui:WaitForChild("Data"):WaitForChild(slotName):WaitForChild("Stats"):WaitForChild("LegoReputation")
    while reputationStat.Value > -100 do
        local randomEgg = tostring(math.random(1, 5))
        LegoEggDestroyedRemote:FireServer(randomEgg)
        task.wait(0.1) 
    end
end


-- This function runs one full, correctly ordered cycle.
-- It remains unchanged.
local function runFullCycle(slotToDelete)

    -- 1. Start the event to trigger a new spawn.
    StartLegoEventRemote:FireServer()

    -- 2. Wait for the new slot to be created.
    local newSlotName = spawnInvokedSignal.Event:Wait()
    
    task.wait(0.2)

    -- 3. Now that the new slot exists, delete the previous one.
    if slotToDelete then
        local deleteArgs = { slotToDelete, false }
        DeleteSlotRemote:InvokeServer(unpack(deleteArgs))
    end

    -- 4. Process the new slot.
    processSingleSlot(newSlotName)
    
    -- 5. Return the name of the slot we just processed.
    return newSlotName
end



local slotNameToDelete = nil -- Start with no slot to delete

while true do
    slotNameToDelete = runFullCycle(slotNameToDelete)
end
