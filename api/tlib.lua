-- Variables --
--[[
Special block drops that drop a different item from the block, along
with the maximum amount of items dropped]]
local blockDrop = {
    ["minecraft:stone"]         = {"minecraft:cobblestone", 1},
    ["minecraft:redstone_ore"]  = {"minecraft:redstone", 5},
    ["minecraft:lapis_ore"]     = {"minecraft:lapis_lazuli", 8},
    ["minecraft:coal_ore"]      = {"minecraft:coal", 1},
    ["minecraft:diamond_ore"]   = {"minecraft:diamond", 1},
    ["minecraft:emerald_ore"]   = {"minecraft:emerald", 1}
}


INDESTRUCTIBLE_BLOCK    = 1
NO_INVENTORY_SPACE      = 2
NO_FUEL                 = 3
MOVEMENT_OBSTRUCTED     = 4
-- Variables --



-- Functions --
function getBlockDrop(block)
    if type(block) ~= "table" then
        -- Either there was no block or there is something wonky going on
        return
    end

    local drop = blockDrop[block.name]

    if drop then
        -- Translate block drop
        return drop[1], drop[2]
    end

    -- Otherwise, assume the block drops 'itself'
    return block.name, 1
end

function hasItemSpace(itemName, count)
    --[[
    Checks whether given item with count fits in the turtle's inventory
    ]]

    -- We can assume getBlockDrop was blindly passed on to this function and there was no block
    if not itemName then
        return true
    end

    local availableSpace = 0
    count = count or 1

    -- Run backwards, as from there, it is the likeliest to find an empty slot
    for i = 16, 1, -1 do
        if turtle.getItemCount(i) == 0 then
            return true
        else
            local item = turtle.getItemDetail(i)

            if item.name == itemName then
                availableSpace = availableSpace + turtle.getItemSpace(i)
            end

            -- Check if we've accumulated enough space and abort if we do
            if availableSpace >= count then
                return true
            end
        end
    end

    return false
end

function compressStacks(forbidden)
    --[[
    Compresses all item stacks except <forbidden> to the top left of the inventory
    <forbidden> may use numerical or string indices, but the value must be the slot
                that is forbidden
    ]]
    forbidden = type(forbidden) == "table" and forbidden or {}

    -- As we compress to top left, only bother with slot 2 and upwards
    for slot = 2, 16 do
        local itemDetailFrom = turtle.getItemDetail(slot)

        -- If there are no items to compress, continue
        if itemDetailFrom then
            -- bool if current indexed slot is forbidden
            local currSlotForbidden = false

            for _, v in pairs(forbidden) do
                if slot == v then
                    currSlotForbidden = true
                    break
                end
            end

            -- Only transfer from allowed slots and leave other stacks alone
            if not currSlotForbidden then
                local transferFromSelected = false -- Only select the slot we're transferring from one time

                -- Increases until slot-1 to try and get rid of all items from the current
                -- selected slot in order to compress
                local transferToIndex = 1
                local itemDetailTo

                while transferToIndex < slot and turtle.getItemCount(slot) > 0 do
                    itemDetailTo = turtle.getItemDetail(transferToIndex)

                    if not itemDetailTo or itemDetailTo.name == itemDetailFrom.name and turtle.getItemSpace(transferToIndex) > 0 then
                        if not transferFromSelected then
                            -- Only select the first time we're actually transferring something
                            transferFromSelected = true
                            turtle.select(slot)
                        end

                        turtle.transferTo(transferToIndex)
                    end

                    transferToIndex = transferToIndex + 1
                end
            end
        end
    end
end

function compressTo(targetSlot, itemName, forbidden)
    --[[
    Tries to collect items from the inventory and push it to target slot <targetSlot>
    Either expects there to already be some items or an item name <itemName> to push there
    ]]
    forbidden = type(forbidden) == "table" and forbidden or {}

    if type("itemName") ~= "string" then
        local itemDetail = turtle.getItemDetail(targetSlot)

        if not itemDetail then
            return false
        end

        itemName = itemDetail.name
    end

    local currSlotFrom = 1
    local prevItemAmount = turtle.getItemCount(targetSlot)

    while currSlotFrom <= 16 and turtle.getItemSpace(targetSlot) > 0 do
        local itemDetail = turtle.getItemDetail(currSlotFrom)

        if itemDetail and itemDetail.name == itemName and currSlotFrom ~= targetSlot then
            local currSlotForbidden = false

            for _, v in pairs(forbidden) do
                if v == itemName then
                    currSlotForbidden = true
                    break
                end
            end

            if not currSlotForbidden then
                turtle.select(currSlotFrom)
                turtle.transferTo(targetSlot)
            end
        end

        currSlotFrom = currSlotFrom + 1
    end

    return turtle.getItemCount(targetSlot) - prevItemAmount
end

function totalItemCount(itemName)
    --[[
    Returns the total amount in this turtle's inventory for a given item name
    ]]
    local count = 0

    for i = 1, 16 do
        local itemDetail = turtle.getItemDetail(i)

        if itemDetail and itemDetail.name == itemName then
            count = count + itemDetail.count
        end
    end

    return count
end

function dug()
    --[[
    Checks whether a turtle.dig() etc. was successful by looking for the succeeding turtle_inventory event
    Queues a custom event afterwards so if turtle_inventory was not in queue, this properly returns and does
    not get stuck.
    ]]
    os.queueEvent("dug_event")

    local e
    while true do -- Loop, as there may have been events before
        e = os.pullEvent()

        if e == "turtle_inventory" then
            return true
        elseif e == "dug_event" then
            break
        end
    end

    return false
end

function dig()
    local isBlock, block = turtle.inspect()

    if not isBlock then
        return true
    end

    -- Account for falling gravel
    while isBlock do
        if not hasItemSpace(getBlockDrop(block)) then
            -- There's still something left, but no inventory space!
            return false, NO_INVENTORY_SPACE
        end

        if not turtle.dig() then
            return false, INDESTRUCTIBLE_BLOCK
        end

        -- Somehow, the block dropped something that still didn't fit the inventory
        if not dug() then
            return false, NO_INVENTORY_SPACE
        end

        isBlock, block = turtle.inspect()
    end

    return true
end

function digUp()
    local isBlock, block = turtle.inspectUp()

    if not isBlock then
        return true
    end

    -- Account for falling gravel
    while isBlock do
        if not hasItemSpace(getBlockDrop(block)) then
            return false, NO_INVENTORY_SPACE
        end

        if not turtle.digUp() then
            return false, INDESTRUCTIBLE_BLOCK
        end

        if not dug() then
            return false, NO_INVENTORY_SPACE
        end

        isBlock, block = turtle.inspectUp()
    end

    return true
end

function digDown()
    local isBlock, block = turtle.inspectDown()

    if not isBlock then
        return true
    end

    if not hasItemSpace(getBlockDrop(block)) then
        return false, NO_INVENTORY_SPACE
    end

    if not turtle.digDown() then
        return false, INDESTRUCTIBLE_BLOCK
    end

    if not dug() then
        return false, NO_INVENTORY_SPACE
    end

    return true
end

function forward(wait)
    wait = wait ~= false

    if turtle.detect() then
        return false, MOVEMENT_OBSTRUCTED
    end

    if turtle.getFuelLevel() < 1 then
        return false, NO_FUEL
    end

    while not turtle.forward() do
        if not turtle.attack() and wait then
            sleep(1)
        end
    end

    return true
end

function up()
    wait = wait ~= false

    if turtle.detectUp() then
        return false, MOVEMENT_OBSTRUCTED
    end

    if turtle.getFuelLevel() < 1 then
        return false, NO_FUEL
    end

    while not turtle.up() do
        if not turtle.attackUp() and wait then
            sleep(1)
        end
    end

    return true
end

function down()
    wait = wait ~= false

    if turtle.detectDown() then
        return false, MOVEMENT_OBSTRUCTED
    end

    if turtle.getFuelLevel() < 1 then
        return false, NO_FUEL
    end

    while not turtle.down() do
        if not turtle.attackDown() and wait then
            sleep(1)
        end
    end

    return true
end

function back()
    if turtle.getFuelLevel() < 1 then
        return false, NO_FUEL
    end

    if not turtle.back() then
        return false, MOVEMENT_OBSTRUCTED
    end

    return true
end
-- Functions --
