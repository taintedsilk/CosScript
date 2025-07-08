-- ======================= CONFIGURATION =======================
local GITHUB_SCRIPT_URL = "https://raw.githubusercontent.com/taintedsilk/CosScript/refs/heads/main/legogrind.lua"
local GRIND_DURATION_MINUTES = 30
local DEBUG = false
-- =============================================================

-- ======================= SERVICES & LIBS =======================
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
-- =============================================================
-- Disable rendering for less resource usage while farming
game:GetService("RunService"):Set3dRenderingEnabled(false)
setfpscap(30)

-- ======================= SERVER HOPPING LOGIC =======================
local function joinSmallestServer()
    if not queueteleport then
        warn("Cannot rejoin: `queue_on_teleport` function not found in your executor.")
        return
    end

    print("Finding a small server to join...")
    local placeId = game.PlaceId
    local serversApi = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    local targetServer = nil
    local nextCursor = nil

    local success, result = pcall(function()
        repeat
            local url = serversApi .. (nextCursor and "&cursor=" .. nextCursor or "")
            local response = game:HttpGet(url)
            local decoded = HttpService:JSONDecode(response)

            if decoded and decoded.data and #decoded.data > 0 then
                for _, server in ipairs(decoded.data) do
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        targetServer = server
                        break
                    end
                end
            end
            
            nextCursor = decoded.nextPageCursor
        until targetServer or not nextCursor
    end)

    if not success then
        warn("Failed to fetch server list: ", result)
        return
    end

    if targetServer then
        print(string.format("Found server with %d players. Teleporting...", targetServer.playing))
        
        queueteleport("loadstring(game:HttpGet('" .. GITHUB_SCRIPT_URL .. "'))()")
        TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
    else
        warn("Could not find a suitable server to join.")
    end
end
-- ===================================================================

-- Must claim daily reward to spawn in
local function claimDailyReward()
    print("Checking for daily reward popup...")

    -- Wait for the Player's GUI to be available
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- Wait up to 10 seconds for the DailyLoginGui to appear.
    -- If it doesn't, we assume it's already been claimed and continue.
    local dailyLoginGui = playerGui:WaitForChild("DailyLoginGui", 10)

    if dailyLoginGui then
        print("Daily Login GUI found. Attempting to claim reward...")
        
        -- Use a protected call (pcall) to prevent errors if the button structure is unexpected
        local success, err = pcall(function()
            -- Find the frame containing the buttons
            local currencyFrame = dailyLoginGui:WaitForChild("ContainerFrame", 5):WaitForChild("CurrencyFrame", 5)
            
            -- Wait for the Claim button's label and click it
            local claimLabel = currencyFrame:WaitForChild("ClaimButton", 5):WaitForChild("UpperLabel", 5)
            firesignal(claimLabel.MouseButton1Click)
            print("Clicked Claim button.")
            
            -- Wait a moment for the game to process the claim
            task.wait(0.5) 
            
            -- Wait for the Close button's label and click it
            local closeLabel = currencyFrame:WaitForChild("CloseButton", 5):WaitForChild("UpperLabel", 5)
            firesignal(closeLabel.MouseButton1Click)
            print("Clicked Close button.")
        end)
        
        if not success then
            warn("Could not claim daily reward, an object was missing: " .. tostring(err))
        else
            print("Daily reward claimed successfully.")
        end
    else
        print("Daily Login GUI not found. Assuming it was already claimed.")
    end
end

-- Spawn in any slot
local function pressPlayOnSlots()
    print("Attempting to press 'Play' on the first 3 slots...")
    task.wait(2) 
    
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local slotsFrame = playerGui:WaitForChild("SaveSelectionGui", 10)
        :WaitForChild("ContainerFrame", 10)
        :WaitForChild("AllSlotsFrame", 10)
        :WaitForChild("SlotsFrame", 10)

    if not slotsFrame then
        warn("Could not find the slots frame. Skipping play button presses.")
        return
    end
    
    for i = 1, 3 do
        local slotNumber = tostring(i)
        local slot = slotsFrame:FindFirstChild(slotNumber)
        
        if slot then
            local success, err = pcall(function()
                local innerFrame = slot:WaitForChild("InnerFrame", 5)
                firesignal(innerFrame.MouseButton1Click)
                task.wait(0.2)
                
                local playButtonLabel = innerFrame:WaitForChild("CreatureFrame", 5)
                    :WaitForChild("ButtonsFrame", 5)
                    :WaitForChild("PlayButton", 5)
                    :WaitForChild("UpperLabel", 5)
                
                firesignal(playButtonLabel.MouseButton1Click)
                print("Clicked Play on Slot " .. slotNumber)
                task.wait(0.5)
            end)
            if not success then
                warn("Failed to click play on slot " .. slotNumber .. ": " .. err)
            end
        else
            warn("Slot " .. slotNumber .. " not found.")
        end
    end
    print("Finished starting game on all available slots.")
end

-- This function now returns the name of the last processed slot.
local function startGrindLoop()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
    if not Remotes then warn("Remotes folder not found!"); return nil end

    local DeleteSlotRemote = Remotes:WaitForChild("DeleteSlotRemote")
    local StartLegoEventRemote = Remotes:WaitForChild("StartLegoEvent")
    local LegoEggDestroyedRemote = Remotes:WaitForChild("LegoEggDestroyed")
    local SpawnRemote = Remotes:WaitForChild("SpawnRemote")
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    local spawnInvokedSignal = Instance.new("BindableEvent")

    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(target, key)
        local originalMember = oldIndex(target, key)
        if target == SpawnRemote and key == "InvokeServer" then
            return function(...)
                local args = {...}
                local slotName = args[2]
                if type(slotName) == "string" then
                    if DEBUG then print(string.format("DEBUG: HOOK - Captured slot name '%s'.", slotName)) end
                    spawnInvokedSignal:Fire(slotName)
                end
                return originalMember(...)
            end
        end
        return originalMember
    end)
    print("Hook for SpawnRemote has been set.")
    
    local function processSingleSlot(slotName)
        if DEBUG then print(string.format("DEBUG: PROCESS - Starting to process slot '%s'.", slotName)) end
    
        local reputationStat
        local success, result = pcall(function()
            reputationStat = PlayerGui:WaitForChild("Data", 10) 
                :WaitForChild(slotName, 10)
                :WaitForChild("Stats", 10)
                :WaitForChild("LegoReputation", 10)
        end)
    
        if not success or not reputationStat then
            warn(string.format("PROCESS FAILED: Could not find 'LegoReputation' for slot '%s'. The UI may not have loaded in time. Skipping.", slotName))
            return
        end
        
        if DEBUG then print(string.format("DEBUG: PROCESS - Initial reputation for '%s' is %d.", slotName, reputationStat.Value)) end
        
        while reputationStat.Value > -100 do
            LegoEggDestroyedRemote:FireServer(tostring(math.random(1, 5)))
            task.wait(0.1) 
        end
        
        if DEBUG then print(string.format("DEBUG: PROCESS - Finished processing slot '%s'.", slotName)) end
    end


    local function runFullCycle(slotToDelete)
        if DEBUG then print("\n--- STARTING NEW CYCLE ---") end
        StartLegoEventRemote:FireServer()
        if DEBUG then print("DEBUG: CYCLE - Waiting for new slot...") end

        local success, newSlotName = pcall(function() return spawnInvokedSignal.Event:Wait() end)
        if not success then
             warn("Timed out or error while waiting for new slot signal. Ending grind.")
             return nil, true 
        end
        
        if DEBUG then print(string.format("DEBUG: CYCLE - New slot is '%s'.", newSlotName)) end
        task.wait(0.5) 

        if slotToDelete then
            DeleteSlotRemote:InvokeServer(slotToDelete, false)
            if DEBUG then print(string.format("DEBUG: CYCLE - Deleted previous slot '%s'.", slotToDelete)) end
        end

        processSingleSlot(newSlotName)
        return newSlotName, false
    end

    local startTime = os.clock()
    local grindDurationSeconds = GRIND_DURATION_MINUTES * 60
    
    print(string.format("Grind loop initiated. Will run for %d minutes.", GRIND_DURATION_MINUTES))
    
    local lastProcessedSlot = nil
    local timedOut = false
    
    while (os.clock() - startTime) < grindDurationSeconds do
        lastProcessedSlot, timedOut = runFullCycle(lastProcessedSlot)
        if timedOut then break end
    end

    hookmetamethod(game, "__index", oldIndex)
    spawnInvokedSignal:Destroy()
    print("Grind time finished. Hook has been removed.")
    
    return lastProcessedSlot, DeleteSlotRemote
end
-- ===================================================================


-- ======================= MAIN EXECUTION FLOW =======================

-- Step 1: Attempt to claim the daily reward first.
pcall(claimDailyReward)
task.wait(1) 

pcall(pressPlayOnSlots)
task.wait(5)

local lastProcessedSlot, DeleteSlotRemote = startGrindLoop()

if lastProcessedSlot and DeleteSlotRemote then
    print(string.format("Main grind complete. Deleting final slot '%s' before rejoining.", lastProcessedSlot))
    pcall(function()
        DeleteSlotRemote:InvokeServer(lastProcessedSlot, false)
    end)
    task.wait(0.5)
else
    print("Main grind complete. No final slot to delete.")
end

print("Preparing to rejoin a new server.")
-- Rejoin because instance might use too much resource, this prevent crashing
joinSmallestServer()
-- ===================================================================
