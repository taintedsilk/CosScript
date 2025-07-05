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
-- This remains unchanged and is working correctly.
local oldIndex
oldIndex = hookmetamethod(game, "__index", function(target, key)
    local originalMember = oldIndex(target, key)
    if target == SpawnRemote and key == "InvokeServer" then
        return function(...)
            print("HOOK: Intercepted SpawnRemote:InvokeServer()")
            local args = {...}
            
            -- Print arguments for debugging
            for i, argument in ipairs(args) do
                print(string.format("  - Arg #%d: %s (Type: %s)", i, tostring(argument), type(argument)))
            end

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

-- This helper function remains unchanged
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


-- ======================= THE CYCLE FUNCTION (REORDERED) =======================
-- This function now performs the actions in the correct sequence.
local function runFullCycle(slotToDelete)
    print("-----------------------------------------")
    print("Starting new cycle.")

    -- 1. Start the server-side process which will lead to a new slot spawning.
    StartLegoEventRemote:FireServer()

    -- 2. Wait for the hook to detect the SpawnRemote call and give us the new slot name.
    print("Waiting for new slot to spawn...")
    local newSlotName = spawnInvokedSignal.Event:Wait()
    print("New slot has spawned:", newSlotName)
    
    -- A small, optional delay to ensure the new slot is fully rendered/initialized if needed.
    task.wait(0.2)

    -- 3. NOW that the new slot exists, delete the previous one (if one was provided).
    if slotToDelete then
        print("Deleting previous slot:", slotToDelete)
        local deleteArgs = { slotToDelete, false }
        DeleteSlotRemote:InvokeServer(unpack(deleteArgs))
    else
        print("No previous slot to delete (first run).")
    end

    -- 4. Run the processing loop for the newly spawned slot.
    processSingleSlot(newSlotName)

    print("Cycle complete for slot", newSlotName)
    
    -- 5. Return the name of the slot we just worked on, to be deleted in the next cycle.
    return newSlotName
end


-- ======================= EXECUTION LOGIC =======================
-- This part remains the same.

print("\n--- RUNNING FIRST CYCLE ---")
local slotFromFirstCycle = runFullCycle(nil)
task.wait(1)

print("\n--- RUNNING SECOND CYCLE ---")
local slotFromSecondCycle = runFullCycle(slotFromFirstCycle)

print("\n=========================================")
print("Completed two cycles as requested.")
print("First cycle processed:", slotFromFirstCycle)
print("Second cycle processed:", slotFromSecondCycle)
print("=========================================")
