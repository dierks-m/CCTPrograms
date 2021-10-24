if not turtle then
    printError( "Requires a Turtle" )
    return
end

local tArgs = {...}
if #tArgs < 2 then
    print( "Usage: excavate <width> <length> [findVerticalBlock (find)] [direction (left)]" )
    return
end

-- Mine in a quarry pattern until we hit something we can't dig
local width  = tonumber(tArgs[1])
local length = tonumber(tArgs[2])

if width < 1 then
    print( "Excavate diameter must be positive" )
    return
end

local depth     = 0
local unloaded  = 0
local collected = 0

local xPos, zPos = 0, 0
local xDir, zDir = 0, 1

local goTo -- Filled in further down
local refuel -- Filled in further down

local function unload(_bKeepOneFuelStack)
    print( "Unloading items..." )

    local fuelStackSlot

    for n = 1, 16 do
        local nCount = turtle.getItemCount(n)

        if nCount > 0 then
            local bDrop = true
            turtle.select(n)

            if _bKeepOneFuelStack and turtle.refuel(0) then
                if fuelStackSlot then
                    -- Compress fuel stacks to keep a full stack at all times
                    if turtle.transferTo(fuelStackSlot) == nCount then
                        -- There's nothing left to drop, as we could all transfer it
                        bDrop = false
                    end
                else
                    fuelStackSlot = n
                    bDrop = false
                end
            end

            if bDrop then
                turtle.drop()
                unloaded = unloaded + nCount
            end
        end
    end

    collected = 0
    turtle.select(1)
end

local function returnSupplies()
    local x,y,z,xd,zd = xPos,depth,zPos,xDir,zDir
    print( "Returning to surface..." )
    goTo( 0,0,0,0,-1 )

    local fuelNeeded = 2*(x+y+z) + 1
    if not refuel( fuelNeeded ) then
        unload( true )
        print( "Waiting for fuel" )
        while not refuel( fuelNeeded ) do
            os.pullEvent( "turtle_inventory" )
        end
    else
        unload( true )
    end

    print( "Resuming mining..." )
    goTo( x,y,z,xd,zd )
end

local function collect()
    local bFull = true
    local nTotalItems = 0

    for n=1, 16 do
        local nCount = turtle.getItemCount(n)

        if nCount == 0 then
            bFull = false
        end

        nTotalItems = nTotalItems + nCount
    end

    if nTotalItems > collected then
        collected = nTotalItems
        if math.fmod(collected + unloaded, 50) == 0 then
            print( "Mined "..(collected + unloaded).." items." )
        end
    end

    if bFull then
        print( "No empty slots left." )
        return false
    end
    return true
end

function refuel( ammount )
    local fuelLevel = turtle.getFuelLevel()
    if fuelLevel == "unlimited" then
        return true
    end

    local needed = ammount or (xPos + zPos + depth + 2)
    if turtle.getFuelLevel() < needed then
        local fueled = false
        for n=1,16 do
            if turtle.getItemCount(n) > 0 then
                turtle.select(n)
                if turtle.refuel(1) then
                    while turtle.getItemCount(n) > 0 and turtle.getFuelLevel() < needed do
                        turtle.refuel(1)
                    end
                    if turtle.getFuelLevel() >= needed then
                        turtle.select(1)
                        return true
                    end
                end
            end
        end
        turtle.select(1)
        return false
    end

    return true
end

local function tryForwards()
    if not refuel() then
        print( "Not enough Fuel" )
        returnSupplies()
    end

    while not turtle.forward() do
        if turtle.detect() then
            if turtle.dig() then
                if not collect() then
                    returnSupplies()
                end
            else
                return false
            end
        elseif turtle.attack() then
            if not collect() then
                returnSupplies()
            end
        else
            sleep( 0.5 )
        end
    end

    xPos = xPos + xDir
    zPos = zPos + zDir
    return true
end

local function tryDown()
    if not refuel() then
        print( "Not enough Fuel" )
        returnSupplies()
    end

    while not turtle.down() do
        if turtle.detectDown() then
            if turtle.digDown() then
                if not collect() then
                    returnSupplies()
                end
            else
                return false
            end
        elseif turtle.attackDown() then
            if not collect() then
                returnSupplies()
            end
        else
            sleep( 0.5 )
        end
    end

    depth = depth + 1
    if math.fmod( depth, 10 ) == 0 then
        print( "Descended "..depth.." metres." )
    end

    return true
end

local function turnLeft()
    turtle.turnLeft()
    xDir, zDir = -zDir, xDir
end

local function turnRight()
    turtle.turnRight()
    xDir, zDir = zDir, -xDir
end

function goTo( x, y, z, xd, zd )
    while depth > y do
        if turtle.up() then
            depth = depth - 1
        elseif turtle.digUp() or turtle.attackUp() then
            collect()
        else
            sleep( 0.5 )
        end
    end

    if xPos > x then
        while xDir ~= -1 do
            turnLeft()
        end
        while xPos > x do
            if turtle.forward() then
                xPos = xPos - 1
            elseif turtle.dig() or turtle.attack() then
                collect()
            else
                sleep( 0.5 )
            end
        end
    elseif xPos < x then
        while xDir ~= 1 do
            turnLeft()
        end
        while xPos < x do
            if turtle.forward() then
                xPos = xPos + 1
            elseif turtle.dig() or turtle.attack() then
                collect()
            else
                sleep( 0.5 )
            end
        end
    end

    if zPos > z then
        while zDir ~= -1 do
            turnLeft()
        end
        while zPos > z do
            if turtle.forward() then
                zPos = zPos - 1
            elseif turtle.dig() or turtle.attack() then
                collect()
            else
                sleep( 0.5 )
            end
        end
    elseif zPos < z then
        while zDir ~= 1 do
            turnLeft()
        end
        while zPos < z do
            if turtle.forward() then
                zPos = zPos + 1
            elseif turtle.dig() or turtle.attack() then
                collect()
            else
                sleep( 0.5 )
            end
        end
    end

    while depth < y do
        if turtle.down() then
            depth = depth + 1
        elseif turtle.digDown() or turtle.attackDown() then
            collect()
        else
            sleep( 0.5 )
        end
    end

    while zDir ~= zd or xDir ~= xd do
        turnLeft()
    end
end

local function findFirstBlock()
    while not turtle.detectDown() do
        if not refuel() then
            print( "Not enough Fuel" )
            returnSupplies()
        end

        while not turtle.down() do
            turtle.attackDown()
        end

        depth = depth + 1
    end
end

if not refuel() then
    print( "Out of Fuel" )
    return
end

print( "Excavating..." )

local reseal = false
turtle.select(1)
if turtle.digDown() then
    reseal = true
end

local alternate = 0
local done = false

if tArgs[3] == "find" then
    findFirstBlock()
    -- Go down one block - additionally to the block it goes down anyway
    done = not tryDown()
end

if tArgs[3] == "left" or tArgs[4] == "left" then
    -- Start in other direction
    alternate = 1
end

done = not tryDown()

while not done do
    for n = 1, width do
        turtle.digUp()
        turtle.digDown()

        for m = 1, length - 1 do
            if not tryForwards() then
                done = true
                break
            end

            turtle.digUp()
            turtle.digDown()
        end

        if done then
            break
        end

        if n < width then
            if math.fmod(n + alternate, 2) == 0 then
                turnLeft()
                if not tryForwards() then
                    done = true
                    break
                end

                turnLeft()
            else
                turnRight()
                if not tryForwards() then
                    done = true
                    break
                end
                turnRight()
            end
        end
    end

    if done then
        break
    end

    -- No need to turn if length is one
    if length > 1 then
        turnRight()
        turnRight()

        -- If width is even, we need to go the other direction on new layer
        alternate = 1 - (width % 2) - alternate
    end

    --[[
    We want to go down -at least- two blocks. The first one will end up in the block we dug
    up below. If now bedrock is below us, we can't dig up more and done = true.]]
    done = not (tryDown() and tryDown())

    --[[
    Optionally, go down another block. If this is bedrock, we want to at least
    clear the other two blocks and continue.]]
    tryDown()
end

print( "Returning to surface..." )

-- Return to where we started
goTo(0, 0, 0, 0, -1)
unload(false)
goTo(0, 0, 0, 0, 1)

-- Seal the hole
if reseal then
    turtle.placeDown()
end

if rednet.isOpen() then
    rednet.broadcast({command = "say", args = {message = " is done excavating.", label = os.getComputerLabel(), noSpace = true}}, "chunkLoading")
end

print("Mined " .. (collected + unloaded) .. " items total.")
