-- ======================= CONFIGURATION =======================
-- Set to true to print detailed logs, false to run silently.
local DEBUG = true
-- =============================================================

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
            if DEBUG then print("DEBUG: HOOK - InvokeServer on SpawnRemote was intercepted.") end
            
            local args = {...}
            
            -- Debug printing of arguments
            if DEBUG then
                for i, argument in ipairs(args) do
                    print(string.format("  - HOOK Arg #%d: %s (Type: %s)", i, tostring(argument), type(argument)))
                end
            end

            local slotName = args[2] -- The actual slot name
            if type(slotName) == "string" then
                if DEBUG then print(string.format("DEBUG: HOOK - Captured slot name '%s'. Firing signal.", slotName)) end
                spawnInvokedSignal:Fire(slotName)
            else
                warn("HOOK: Argument #2 was not a string.")
                if DEBUG then print(string.format("DEBUG: HOOK - Argument #2 was type '%s', not a string. Signal not fired.", type(slotName))) end
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
    if DEBUG then print(string.format("DEBUG: PROCESS - Starting to process slot '%s'.", slotName)) end
    
    local reputationStat = PlayerGui:WaitForChild("Data"):WaitForChild(slotName):WaitForChild("Stats"):WaitForChild("LegoReputation")
    
    if DEBUG then print(string.format("DEBUG: PROCESS - Initial reputation for '%s' is %d.", slotName, reputationStat.Value)) end
    
    while reputationStat.Value > -100 do
        local randomEgg = tostring(math.random(1, 5))
        if DEBUG then print(string.format("  - PROCESS: Firing LegoEggDestroyed. Current rep: %d", reputationStat.Value)) end
        LegoEggDestroyedRemote:FireServer(randomEgg)
        task.wait(0.1) 
    end
    
    if DEBUG then print(string.format("DEBUG: PROCESS - Finished processing slot '%s'. Final reputation: %d.", slotName, reputationStat.Value)) end
end


-- This function runs one full, correctly ordered cycle.
-- It remains unchanged.
local function runFullCycle(slotToDelete)
    if DEBUG then
        print("\n--- STARTING NEW CYCLE ---")
        if slotToDelete then
            print(string.format("DEBUG: CYCLE - The slot to be deleted this cycle is '%s'.", slotToDelete))
        else
            print("DEBUG: CYCLE - This is the first cycle, no slot to delete yet.")
        end
    end

    -- 1. Start the event to trigger a new spawn.
    if DEBUG then print("DEBUG: CYCLE - 1. Firing StartLegoEventRemote.") end
    StartLegoEventRemote:FireServer()

    -- 2. Wait for the new slot to be created.
    if DEBUG then print("DEBUG: CYCLE - 2. Waiting for hook to signal a new slot name...") end
    local newSlotName = spawnInvokedSignal.Event:Wait()
    if DEBUG then print(string.format("DEBUG: CYCLE - 2a. Signal received! New slot is '%s'.", newSlotName)) end
    
    task.wait(0.2)

    -- 3. Now that the new slot exists, delete the previous one.
    if slotToDelete then
        if DEBUG then print(string.format("DEBUG: CYCLE - 3. Deleting previous slot '%s'.", slotToDelete)) end
        local deleteArgs = { slotToDelete, false }
        DeleteSlotRemote:InvokeServer(unpack(deleteArgs))
    else
        if DEBUG then print("DEBUG: CYCLE - 3. Skipping delete step (no previous slot).") end
    end

    -- 4. Process the new slot.
    if DEBUG then print(string.format("DEBUG: CYCLE - 4. Handing off '%s' to processSingleSlot.", newSlotName)) end
    processSingleSlot(newSlotName)
    
    -- 5. Return the name of the slot we just processed.
    if DEBUG then print(string.format("DEBUG: CYCLE - 5. Cycle complete. Returning '%s' for the next iteration.", newSlotName)) end
    return newSlotName
end

-- ======================= MAIN LOOP =======================
if DEBUG then print("DEBUG: Main script initialized. Starting loop.") end

local slotNameToDelete = nil -- Start with no slot to delete

while true do
    slotNameToDelete = runFullCycle(slotNameToDelete)
end
