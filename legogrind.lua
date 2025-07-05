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
-- This captures the original __index metamethod before we override it.
local oldIndex
oldIndex = hookmetamethod(game, "__index", function(target, key, ...)
    if target == SpawnRemote and key == "InvokeServer" then
        print("HOOK: Intercepted a call to SpawnRemote:InvokeServer()!")
        
        local args = {...}
        local slotName = args[1]
        print(args)
        if type(slotName) == "string" then
            print("HOOK: Captured slot name:", slotName)
            spawnInvokedSignal:Fire(slotName)
        else
            warn("HOOK: SpawnRemote was invoked without a valid slot name argument.")
        end
    end

    -- Call the original __index so we don't break functionality.
    return oldIndex(target, key, ...)
end)
-- =========================================================

-- This function processes a SINGLE slot until its reputation is -100
-- (This helper function remains unchanged)
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


-- ======================= THE CYCLE FUNCTION =======================
-- This function runs one complete cycle of the event.
-- It takes the name of a slot to delete (from the previous cycle)
-- and returns the name of the slot it just finished processing.
local function runFullCycle(slotToDelete)
    print("-----------------------------------------")
    print("Starting new cycle.")

    -- 1. If a slot name was provided, delete it.
    --    This happens for all cycles except the very first one.
    if slotToDelete then
        print("Deleting previous slot:", slotToDelete)
        local deleteArgs = { slotToDelete, false }
        DeleteSlotRemote:InvokeServer(unpack(deleteArgs))
    else
        print("No previous slot to delete, this is the first run.")
    end

    -- 2. Start the server-side process which will lead to a spawn
    StartLegoEventRemote:FireServer()

    -- 3. Wait for the hook to detect the SpawnRemote call and give us the new slot name
    print("Waiting for SpawnRemote to be invoked...")
    local newSlotName = spawnInvokedSignal.Event:Wait()
    print("New slot spawned:", newSlotName)

    -- 4. Run the processing loop for the newly spawned slot
    processSingleSlot(newSlotName)

    print("Cycle complete for slot", newSlotName)
    
    -- 5. Return the name of the slot we just worked on
    return newSlotName
end


-- ======================= EXECUTION LOGIC =======================
-- We will now call the cycle function twice.

-- Run the first cycle. We pass 'nil' because there's no previous slot to delete.
-- We store the returned slot name (e.g., "Slot1") in a variable.
print("\n--- RUNNING FIRST CYCLE ---")
local slotFromFirstCycle = runFullCycle(nil)
task.wait(1) -- A brief pause for clarity in logs

-- Run the second cycle. We pass the name of the slot from the first run,
-- so it gets deleted after the new one spawns.
print("\n--- RUNNING SECOND CYCLE ---")
local slotFromSecondCycle = runFullCycle(slotFromFirstCycle)

print("\n=========================================")
print("Completed two cycles as requested.")
print("First cycle processed:", slotFromFirstCycle)
print("Second cycle processed:", slotFromSecondCycle)
print("=========================================")
