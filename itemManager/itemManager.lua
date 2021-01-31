-- Variables --
local configPath = "/configuration.json"
local defaultCheckInterval = 5
local defaultTransferInterval = 1
-- Variables --

-- Functions --
local function loadConfig(path)
    local file = fs.open(path, "r")

    if not file then
        return {}
    end

    local content = file.readAll()
    file.close()

    local json = textutils.unserializeJSON(content)

    if not json then
        print("Failed to parse JSON, please check configuration")
    end

    return json or {}
end

local function handleValidityCheck(handle)
    assert(type(handle.from) == "table", "Source inventory must be table, got " .. type(handle.from))

    assert(type(handle.from.name) == "string", "Source inventory name must be specified, got " .. tostring(handle.from.name))
    assert(
        not handle.from.filter or type(handle.from.filter) == "table",
        "Filter must either be nil, false or a table of names, got " .. tostring(handle.from.filter)
    )
    assert(
        not handle.from.redstone or type(handle.from.redstone) == "table",
        "Redstone must either be nil, false or a table of names, got " .. tostring(handle.from.filter)
    )

    assert(type(handle.to) == "table", "Target inventory must be a table of inventories" .. type(handle.to))
end

local function itemMatches(itemName, handle)
    if not handle.whitelist then
        if not handle.filter or #handle.filter == 0 then
            return true
        end

        for _, v in pairs(handle.filter) do
            if v == itemName then
                return false
            end
        end

        return true
    end

    if not handle.filter or #handle.filter == 0 then
        -- Empty whitelist means this inventory accepts no items
        -- Why one would do that, I don't know. But it's implemented
        return false
    end

    -- Check in itemName is in the whitelist
    for _, v in pairs(handle.filter) do
        if v == itemName then
            return true
        end
    end

    -- No whitelist match, this item is not accepted.
    return false
end

local function updateRedstone(handle, input, bundledInput)
    if handle.redstone.color then
        input = bit.band(bundledInput, colors[handle.redstone.color]) > 0
    end

    if handle.redstone.inverted then
        handle.redstone.isActive = not input
    else
        handle.redstone.isActive = input
    end
end

local function updateAllRedstone(configuration)
    local states = {
        left = {}, right = {}, front = {}, back = {}, top = {}, bottom = {}
    }

    for side, t in pairs(states) do
        t[1] = rs.getInput(side)
        t[2] = rs.getBundledInput(side)
    end

    for _, itemHandle in pairs(configuration) do
        if itemHandle.from.redstone then
            updateRedstone(itemHandle.from, states[itemHandle.from.redstone.side][1], states[itemHandle.from.redstone.side][2])
        end

        for _, toHandle in pairs(itemHandle.to) do
            if toHandle.redstone then
                updateRedstone(toHandle, states[toHandle.redstone.side][1], states[toHandle.redstone.side][2])
            end
        end
    end
end

local function checkRedstone(handle)
    if not handle.redstone then
        return true
    end

    return handle.redstone.isActive
end

local function inventoryHandle(itemHandle)
    -- Creates a new inventory handle for the given inventory object
    -- that can then be run as a coroutine
    handleValidityCheck(itemHandle)

    local checkInterval = tonumber(itemHandle.checkInterval) or defaultCheckInterval
    local transferInterval = tonumber(itemHandle.transferInterval) or defaultTransferInterval

    while true do
        local items = peripheral.call(itemHandle.from.name, "list")

        if next(items) and checkRedstone(itemHandle.from) then
            for slot, v in pairs(items) do
                -- Check if we should actually extract the item
                if itemMatches(v.name, itemHandle.from) then
                    for _, inv in ipairs(itemHandle.to) do
                        if checkRedstone(inv) and itemMatches(v.name, inv) then
                            local numTransferred = peripheral.call(itemHandle.from.name, "pushItems", inv.name, slot)

                            sleep(transferInterval) -- Only sleep if we could actually transfer

                            -- No more to transfer from this particular slot. STAHP.
                            if numTransferred == v.count then
                                break
                            end
                        end
                    end
                end
            end
        else
            sleep(checkInterval)
        end
    end
end

local function mainLoop(config)
    local e

    while true do
        e = {os.pullEvent()}

        if e[1] == "char" and e[2]:lower() == "q" then
            break
        elseif e[1] == "redstone" then
            updateAllRedstone(config)
        end
    end
end
-- Functions --


-- Main Program --
local config = loadConfig(configPath)

local invFuncs = {}
for k, v in pairs(config) do
    invFuncs[#invFuncs + 1] = function() inventoryHandle(v) end
end

updateAllRedstone(config)
parallel.waitForAny(function() mainLoop(config) end, unpack(invFuncs))
-- Main Program --
