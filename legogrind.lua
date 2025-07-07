-- ======================= CONFIGURATION =======================
-- IMPORTANT: Replace this with the RAW GitHub URL of your script.
local GITHUB_SCRIPT_URL = "https://raw.githubusercontent.com/taintedsilk/CosScript/refs/heads/main/legogrind.lua"

-- How long to grind in each server before rejoining (in minutes).
local GRIND_DURATION_MINUTES = 1

-- Set to true to print detailed logs for debugging, false to run silently.
local DEBUG = false
-- =============================================================


-- ======================= SERVICES & LIBS =======================
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Executor-specific function for queuing a script to run after teleporting.
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
-- =============================================================


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


-- ======================= GAME-SPECIFIC LOGIC =======================

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
        local reputationStat = PlayerGui:WaitForChild("Data"):WaitForChild(slotName):WaitForChild("Stats"):WaitForChild("LegoReputation")
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
        task.wait(0.2)

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
    
    -- Return the name of the last slot for final deletion
    return lastProcessedSlot, DeleteSlotRemote
end
-- ===================================================================


-- ======================= MAIN EXECUTION FLOW =======================

-- 1. Start the game by clicking play on the initial slots.
pcall(pressPlayOnSlots)
task.wait(5)

-- 2. Begin the main grind loop and get the name of the last slot processed.
local lastProcessedSlot, DeleteSlotRemote = startGrindLoop()

-- 3. After the grind, delete the final active slot.
if lastProcessedSlot and DeleteSlotRemote then
    print(string.format("Main grind complete. Deleting final slot '%s' before rejoining.", lastProcessedSlot))
    pcall(function()
        DeleteSlotRemote:InvokeServer(lastProcessedSlot, false)
    end)
    task.wait(0.5) -- Give the server a moment to process the deletion.
else
    print("Main grind complete. No final slot to delete.")
end

-- 4. Find a new server and rejoin.
print("Preparing to rejoin a new server.")
joinSmallestServer()
-- ===================================================================
