-- Imports --
local tlib = require("/api/tlib")

-- Variables --
local tryRefuelLava = true
local lavaRefuelLowerThreshold = 80000
local lavaRefuelUpperThreshold = turtle.getFuelLevel()

local enableShaftRestoration = true
local preciseShaftRestoration = true

local prg = {
    facing = 0,
    currHeight = 0,
}

local tPlaceBelow = {
    ["minecraft:dirt"]              = true,
    ["minecraft:cobblestone"]       = true,
    ["minecraft:gravel"]            = true,
    ["minecraft:sand"]              = true,
    ["minecraft:sandstone"]         = true,
    ["minecraft:granite"]           = true,
    ["minecraft:andesite"]          = true,
    ["minecraft:diorite"]           = true,
    ["bluepower:marble"]            = true,
    ["quark:smooth_basalt"]         = true,
    ["quark:cobbled_deepslate"]     = true,
    ["minecraft:netherrack"]        = true,
    ["minecraft:blackstone"]        = true,
    ["quark:cobbled_deepslate"]     = true,
    ["quark:slate"]                 = true,
    ["minecraft:magma_block"]       = true,
    ["minecraft:nether_wart_block"] = true,
    ["minecraft:warped_wart_block"] = true,
    ["minecraft:basalt"]            = true,
    ["minecraft:smooth_basalt"]     = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:soul_sand"]         = true,
    ["minecraft:soul_soil"]         = true,
    ["minecraft:tuff"]              = true,
    ["minecraft:rail"]              = true,
    ["create:scorchia"]             = true,
}

local oreDict = {
    tags = {
        ["forge:ores"] = true
    },
    blocks = {
        ["minecraft:shroomlight"] = true,
        ["minecraft:glowstone"]   = true
    }
}

local closingBlockWish = "minecraft:cobblestone"
local firstBlockDug

local specialBlockDrops = {
    ["minecraft:grass"]          = "minecraft:dirt",
    ["minecraft:stone"]          = "minecraft:cobblestone",
    ["quark:deepslate"]          = "quark:cobbled_deepslate",
    ["minecraft:deepslate"]      = "minecraft:cobbled_deepslate",
    ["minecraft:warped_nylium"]  = "minecraft:netherrack",
    ["minecraft:crimson_nylium"] = "minecraft:netherrack"
}
-- If no special kind available, return the block searched for
setmetatable(specialBlockDrops, {__index = function(_, key) return key end})

local blockHeightMap = {}
local lavaRefuelActive
-- Variables --


-- Functions --
local function interrupt( msg, key )
    term.setCursorPos( 1, 13 )
    term.clearLine()
    term.setCursorPos( 1, 13 )
    term.write( msg )

    while true do
        local e = { os.pullEvent() }

        if e[1] == "key" and e[2] == key then
            return
        end
    end
end

local function refuel( lvl, stop )
    local selSlot = turtle.getSelectedSlot()

    if turtle.getFuelLevel() == "unlimited" then
        return true
    end

    while turtle.getFuelLevel() < lvl do
        if not tlib.refuel(lvl) then
            if stop ~= false then -- Nil will cause this as well
                interrupt("Out of fuel - RSHIFT to continue", keys.rightShift)
            else
                return false
            end
        end
    end

    return true, turtle.getSelectedSlot() ~= selSlot and turtle.select( selSlot )
end

local function doLavaRefuel(blockBelow)
    lavaRefuelActive = lavaRefuelActive or turtle.getFuelLevel() < lavaRefuelLowerThreshold

    if not lavaRefuelActive then
        return
    end

    local prevSlot = turtle.getSelectedSlot()

    if tlib.findAndSelect("minecraft:bucket") then
        if blockBelow then turtle.placeDown() else turtle.place() end
        turtle.refuel()
        turtle.select(prevSlot)

        lavaRefuelActive = turtle.getFuelLevel() < lavaRefuelUpperThreshold
    end
end

local function goDown()
    while not turtle.down() do
        if not turtle.attackDown() then sleep(1) end
    end

    prg.currHeight = prg.currHeight + 1
end

local function goUp()
    while not turtle.up() do
        if not turtle.attackUp() then sleep(1) end
    end

    prg.currHeight = prg.currHeight - 1
end

local function turnLeft()
    turtle.turnLeft()
    prg.facing = (prg.facing - 1) % 4
end

local function turnRight()
    turtle.turnRight()
    prg.facing = (prg.facing + 1) % 4
end

local function isOre( isBlock, block )
    if not isBlock then
        return false
    end

    if tryRefuelLava and block.name == "minecraft:lava" then
        doLavaRefuel()
        return false
    end

    if oreDict.blocks[block.name] then return true end

    for tag in pairs(block.tags) do
        if oreDict.tags[tag] then return true end
    end

    return false
end

local function checkWalls()
    if isOre(turtle.inspect()) then
        turtle.dig()
    end

    if prg.facing == 1 or prg.facing == 3 then
        turnLeft()
    else
        turnRight()
    end

    if isOre(turtle.inspect()) then
        turtle.dig()
    end
end

local function getTrashItems()
    local trashItems = {}

    for i = 1, 16 do
        local item = turtle.getItemDetail(i)

        if item and tPlaceBelow[item.name] then
            trashItems[item.name] = (trashItems[item.name] and trashItems[item.name] or 0) + item.count
        end
    end

    return trashItems
end

local function determineClosingBlock(trashItems)
    if trashItems[closingBlockWish] then
        return closingBlockWish
    end

    for k in pairs(trashItems) do
        if k ~= firstBlockDug then
            return k
        end
    end

    return next(trashItems)
end

local function selectTrashItem(trashItems, blockWish)
    if blockWish then
        if (trashItems[blockWish] or 0) < 1 then
            return false
        end

        return tlib.findAndSelect(blockWish) and blockWish
    end


    local lowestCountItem

    -- Select the item with the lowest count to free up as much space as possible
    for k, v in pairs(trashItems) do
        if v > 0 and (not lowestCountItem or v < trashItems[lowestCountItem]) then
            lowestCountItem = k
        end
    end

    if lowestCountItem then
        tlib.findAndSelect(lowestCountItem)
    end

    return lowestCountItem
end

local function placeTrashItem(trashItems)
    if not enableShaftRestoration then
        return
    end

    if preciseShaftRestoration and not blockHeightMap[prg.currHeight + 1] then
        return
    end

    local selectedItem = selectTrashItem(trashItems, blockHeightMap[prg.currHeight + 1])

    if selectedItem and turtle.placeDown() then
        trashItems[selectedItem] = trashItems[selectedItem] - 1
    end
end

local function placeClosingBlock(closingBlock)
    if closingBlock and tlib.findAndSelect(closingBlock) then
        turtle.placeDown()
    end
end

local function digDown()
    local blockPresent, block

    if preciseShaftRestoration or tryRefuelLava or not firstBlockDug then
        blockPresent, block = turtle.inspectDown()
    end

    if not firstBlockDug and blockPresent then
        firstBlockDug = specialBlockDrops[block.name]
    end

    if tryRefuelLava and blockPresent and block.name == "minecraft:lava" then
        doLavaRefuel(true)
    end

    if preciseShaftRestoration then
        if not blockPresent or not turtle.digDown() then return false end
        blockHeightMap[prg.currHeight + 1] = specialBlockDrops[block.name]
    else
        return turtle.digDown()
    end
end

local function makeShaft()
    turtle.select(1)

    while digDown() or not turtle.detectDown() do
        if not refuel(prg.currHeight + 2, false) then
            local currentHeight = prg.currHeight
            for _ = 1, currentHeight do
                goUp()
            end

            refuel(currentHeight * 3)

            for _ = 1, currentHeight do
                goDown()
            end
        end

        goDown()
        checkWalls()
    end

    if prg.facing == 0 then
        turnLeft()
    else
        turnRight()
    end

    local trashItems = getTrashItems()
    local closingBlock = determineClosingBlock(trashItems)

    if closingBlock then
        -- Save one item up for closing the shaft
        trashItems[closingBlock] = trashItems[closingBlock] - 1
    end

    while prg.currHeight > 0 do
        placeTrashItem(trashItems)
        checkWalls()
        goUp()
    end

    placeClosingBlock(closingBlock)

    while prg.facing ~= 0 do
        turnLeft()
    end

    tlib.compressAllStacks()
end
-- Functions --


--[[ MAIN LOOP ]]--
makeShaft()
--[[ MAIN LOOP ]]--
