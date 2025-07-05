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

-- ======================= THE HOOK (FINAL CORRECTION) =======================
-- Capture the original __index metamethod.
local oldIndex
oldIndex = hookmetamethod(game, "__index", function(target, key)
    -- First, call the original __index to get what it would normally return (e.g., the InvokeServer function).
    local originalMember = oldIndex(target, key)

    -- Now, we check if this is the specific member we are interested in.
    if target == SpawnRemote and key == "InvokeServer" then
        
        -- Return a new function that will be called instead of the original.
        return function(...)
            print("HOOK: Intercepted a call to SpawnRemote:InvokeServer()!")

            local args = {...}
            
            local slotName = args[2] 
            
            if type(slotName) == "string" then
                print("HOOK: Captured slot name from Argument #2:", slotName)
                -- Fire our signal with the correct slot name.
                spawnInvokedSignal:Fire(slotName)
            else
                warn("HOOK: Argument #2 was not a string, could not fire signal with slot name.")
            end

            -- CRITICAL: Call the original function with its original arguments.
            -- '...' contains the correct 'self' and all other arguments, so we pass it directly.
            return originalMember(...)
        end
    end
    
    -- If it's not the remote/key we care about, just return the original member without modification.
    return originalMember
end)
-- ===================================================================


-- This function processes a SINGLE slot until its reputation is -100
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

-- This function runs one complete cycle of the event.
local function runFullCycle(slotToDelete)
    print("-----------------------------------------")
    print("Starting new cycle.")

    if slotToDelete then
        print("Deleting previous slot:", slotToDelete)
        local deleteArgs = { slotToDelete, false }
        DeleteSlotRemote:InvokeServer(unpack(deleteArgs))
    else
        print("No previous slot to delete, this is the first run.")
    end

    StartLegoEventRemote:FireServer()

    print("Waiting for SpawnRemote to be invoked...")
    local newSlotName = spawnInvokedSignal.Event:Wait()
    print("New slot spawned:", newSlotName)

    processSingleSlot(newSlotName)

    print("Cycle complete for slot", newSlotName)
    return newSlotName
end


-- ======================= EXECUTION LOGIC =======================
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
