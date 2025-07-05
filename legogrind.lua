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
            print("HOOK: Intercepted SpawnRemote:InvokeServer()")
            local args = {...}
            
            -- Debug printing of arguments
            -- for i, argument in ipairs(args) do
            --     print(string.format("  - Arg #%d: %s (Type: %s)", i, tostring(argument), type(argument)))
            -- end

            local slotName = args[2] -- The actual slot name
            if type(slotName) == "string" then
                print("HOOK: Captured slot name:", slotName)
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
    print("Now processing slot:", slotName)
    local reputationStat = PlayerGui:WaitForChild("Data"):WaitForChild(slotName):WaitForChild("Stats"):WaitForChild("LegoReputation")
    while reputationStat.Value > -100 do
        local randomEgg = tostring(math.random(1, 5))
        LegoEggDestroyedRemote:FireServer(randomEgg)
        task.wait(0.1) 
    end
    print("Reputation target of -100 reached for:", slotName)
end


-- This function runs one full, correctly ordered cycle.
-- It remains unchanged.
local function runFullCycle(slotToDelete)
    print("-----------------------------------------")
    print("Starting new cycle.")

    -- 1. Start the event to trigger a new spawn.
    StartLegoEventRemote:FireServer()

    -- 2. Wait for the new slot to be created.
    print("Waiting for new slot to spawn...")
    local newSlotName = spawnInvokedSignal.Event:Wait()
    print("New slot has spawned:", newSlotName)
    
    task.wait(0.2)

    -- 3. Now that the new slot exists, delete the previous one.
    if slotToDelete then
        print("Deleting previous slot:", slotToDelete)
        local deleteArgs = { slotToDelete, false }
        DeleteSlotRemote:InvokeServer(unpack(deleteArgs))
    else
        print("No previous slot to delete (first run).")
    end

    -- 4. Process the new slot.
    processSingleSlot(newSlotName)

    print("Cycle complete for slot", newSlotName)
    
    -- 5. Return the name of the slot we just processed.
    return newSlotName
end


-- ======================= INFINITE EXECUTION LOOP =======================
print("Starting infinite automation process...")
local slotNameToDelete = nil -- Start with no slot to delete

while true do
    slotNameToDelete = runFullCycle(slotNameToDelete)
end
