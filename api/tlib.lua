-- Functions --
local function findItem(name, blacklist)
    --[[
        Tries to find item with name <name> in inventory,
        ignoring values stored in blacklist.
        name (string)     - Item name pattern to find
        blacklist (table) - Slots to ignore. Only values are considered.
        returns           - First occurence of item with name <name>
    ]]

    if blacklist ~= nil and type(blacklist) ~= "table" then
        error("Expected blacklist to be table, got " .. type(blacklist), 2)
    end

    for i = 1, 16 do
        local skip = false

        if blacklist then
            for _, v in pairs(blacklist) do
                if i == v then
                    skip = true
                    break
                end
            end
        end

        if not skip then
            local itemDetail = turtle.getItemDetail(i)

            if itemDetail and itemDetail.name:match(name) then
                return i
            end
        end
    end

    return false
end

local function findAndSelect(name, blacklist)
    local result = findItem(name, blacklist)

    if result and turtle.getSelectedSlot() ~= result then
        -- turtle.select() takes a tick and thus should only be executed
        -- when necessary!
        turtle.select(result)
    end

    return result
end

local function refuel(targetLevel, blacklist)
    if turtle.getFuelLevel() == "unlimited" then
        return true
    end

    blacklist = type(blacklist) == "table" and blacklist or {}

    while turtle.getFuelLevel() < targetLevel do
        local nextItem = findAndSelect(".", blacklist)

        if not nextItem then
            return false -- No new item was found/all slots already iterated!
        end

        local fuelLevelBefore = turtle.getFuelLevel()

        if turtle.refuel(1) then
            -- Seems to be fuel, now try to consume as much as needed
            local fuelValue = turtle.getFuelLevel() - fuelLevelBefore
            local itemsNeeded = math.ceil((targetLevel - fuelLevelBefore) / fuelValue - 1)
            turtle.refuel(math.min(turtle.getItemCount(), itemsNeeded))
        end

        blacklist[#blacklist + 1] = nextItem
    end

    return true
end

local function compressStacksTo(slot, blacklist)
    local targetSlotContent = turtle.getItemDetail(slot)

    if not targetSlotContent then return end
    local spaceRemaining = turtle.getItemSpace(slot)

    for i = 1, 16 do
        local skip = false

        if blacklist then
            for _, v in pairs(blacklist) do
                if i == v then
                    skip = true
                    break
                end
            end
        end

        if not skip and slot ~= i then
            local sourceSlotContent = turtle.getItemDetail(i)

            if sourceSlotContent and sourceSlotContent.name == targetSlotContent.name then
                turtle.select(i)
                spaceRemaining = spaceRemaining - math.min(spaceRemaining, turtle.getItemCount())
                turtle.transferTo(slot)
            end
        end

        if spaceRemaining == 0 then
            return
        end
    end
end

local function compressAllStacks(blacklist)
    blacklist = type(blacklist) ~= "table" and {} or blacklist

    for i = 1, 16 do
        local skipSlot = false

        for k in pairs(blacklist) do
            if k == i then
                skipSlot = true
                break
            end
        end

        if not skipSlot then
            if turtle.getItemCount(i) == 0 and findAndSelect(".*", blacklist) then
                turtle.transferTo(i)
            end

            compressStacksTo(i, blacklist)
            blacklist[#blacklist + 1] = i
        end
    end
end

local function dig()
    --[[
        turtle.dig() function that is gravel-safe
    ]]

    -- Blindly dig, as checking would need another tick
    -- so just look if we were able to dig.
    local result, msg = turtle.dig()

    if not result then
        return result, msg
    end

    -- Dig away the (potential) gravel!
    while turtle.dig() do
    end

    return true
end

local function digUp()
    local result, msg = turtle.digUp()

    if not result then
        return result, msg
    end

    while turtle.digUp() do
    end

    return true
end
-- Functions --


-- Initialization --
local tlib = {
    findItem = findItem,
    findAndSelect = findAndSelect,
    refuel = refuel,
    compressStacksTo = compressStacksTo,
    compressAllStacks = compressAllStacks,
    dig = dig,
    digUp = digUp,
}
--[[ Also add all features from the turtle API that we have not overridden ]]--
for k, v in pairs(turtle) do
    if not tlib[k] then
        tlib[k] = v
    end
end
-- Initialization --

return tlib
