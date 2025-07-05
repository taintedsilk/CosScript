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
-- We need to find and define the SpawnRemote
local SpawnRemote = Remotes:WaitForChild("SpawnRemote") -- Assuming SpawnRemote is in the Remotes folder

-- A local signal to bridge the hook and our waiting function
-- This will now pass the slot name as an argument
local spawnInvokedSignal = Instance.new("BindableEvent")

-- ======================= THE HOOK (MODIFIED) =======================
-- This captures the original __index metamethod before we override it.
local oldIndex
oldIndex = hookmetamethod(game, "__index", function(target, key, ...)
    -- Check if the target is our remote AND the key is "InvokeServer"
    if target == SpawnRemote and key == "InvokeServer" then
        print("HOOK: Intercepted a call to SpawnRemote:InvokeServer()!")
        
        -- The arguments passed to InvokeServer are captured in the '...' varargs
        local args = {...}
        local slotName = args[1] -- The first argument is the slot name (e.g., "Slot1")
        
        if type(slotName) == "string" then
            print("HOOK: Captured slot name:", slotName)
            -- Fire our signal with the slot name so the waiting function can proceed
            spawnInvokedSignal:Fire(slotName)
        else
            warn("HOOK: SpawnRemote was invoked without a valid slot name argument.")
        end
    end

    -- IMPORTANT: Call the original __index so we don't break functionality.
    -- Pass all original arguments along.
    return oldIndex(target, key, ...)
end)
-- ===================================================================


-- This function processes a SINGLE slot until its reputation is -100
local function processSingleSlot(slotName)
    print("Now processing slot:", slotName)
    
    -- Use WaitForChild for robustness, ensuring the UI elements exist before we access them
    local reputationStat = PlayerGui:WaitForChild("Data"):WaitForChild(slotName):WaitForChild("Stats"):WaitForChild("LegoReputation")
    
    -- Loop infinitely until the reputation value is -100 or less
    while reputationStat.Value > -100 do
        -- Choose a random egg number from 1 to 5 and convert it to a string
        local randomEgg = tostring(math.random(1, 5))
        
        LegoEggDestroyedRemote:FireServer(randomEgg)
        
        -- Wait a short moment. Also prevents the loop from running too fast and causing issues.
        task.wait(0.1) 
    end
    
    print("Reputation target of -100 reached for:", slotName)
end

-- ======================= MASTER CONTROL LOOP =======================
-- This loop manages the entire cycle of spawning, deleting, and processing slots.
local function startMainCycle()
    local previousSlotName = nil

    while true do
        print("-----------------------------------------")
        print("Starting new cycle. Triggering Lego Event...")
        
        -- 1. Start the server-side process which will lead to a spawn
        StartLegoEventRemote:FireServer()

        -- 2. Wait for the hook to detect the SpawnRemote call and give us the slot name
        print("Waiting for SpawnRemote to be invoked...")
        local currentSlotName = spawnInvokedSignal.Event:Wait()
        print("New slot spawned:", currentSlotName)

        -- 3. If there was a previous slot, delete it now.
        if previousSlotName then
            print("Deleting previous slot:", previousSlotName)
            local deleteArgs = { previousSlotName, false }
            DeleteSlotRemote:InvokeServer(unpack(deleteArgs))
        end

        -- 4. Run the processing loop for the newly spawned slot
        processSingleSlot(currentSlotName)

        -- 5. The current slot is now the "previous" one for the next iteration
        previousSlotName = currentSlotName
        
        print("Cycle complete for slot", currentSlotName, ". Restarting...")
        task.wait(1) -- A brief pause before starting the next full cycle
    end
end

-- Start the main automation process
startMainCycle()
