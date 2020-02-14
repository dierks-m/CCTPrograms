-- Variables --
local tArgs = { ... }
local nWidth, nLength
local sInvName

local tSlot = {
	storage		=	16,
}

local nAvailableSlots = 16
local nPlacedBlocks = 0
local nNeededBlocks = 0

local nInitialCursorX, nInitialCursorY = term.getCursorPos()
-- Variables --


-- Functions --
local function userInput( sMessage )
	local nXSize, nYSize = term.getSize()
	local tEvent

	term.setCursorPos( 1, nYSize )
	term.write( sMessage .. " - RSHIFT to continue " )

	while true do
		tEvent = { os.pullEvent() }

		if tEvent[1] == "key" and tEvent[2] == 344 then
			break
		end
	end

	term.clearLine()
end

local function refuel( nFuelLevel )
	local nSelectedSlot = turtle.getSelectedSlot()
	local bSlotForbidden = false
	nFuelLevel = nFuelLevel or 1

	while turtle.getFuelLevel() < nFuelLevel do
		for i = 1, 16 do
			for _, v in pairs( tSlot ) do
				if i == v then
					bSlotForbidden = true
					break
				end
			end

			if not bSlotForbidden then
				turtle.select( i )

				while turtle.refuel( 1 ) and turtle.getFuelLevel() < nFuelLevel do
					sleep( 0 ) -- Yield
				end
			end
		end

		if turtle.getFuelLevel() < nFuelLevel then
			userInput( "No fuel" )
		else
			break
		end
	end

	turtle.select( nSelectedSlot )
end

local function move( sDirection )
	--[[
		Move in direction <sDirection> and destroy blocks in the way.
		If there is any other obstruction, the turtle will wait until it goes away.

		sDirection	-	Direction in which to move, possible directions:
			forward, up, down, back
	]]--

	if sDirection == "left" then
		turtle.turnLeft()
		return
	elseif sDirection == "right" then
		turtle.turnRight()
		return
	end

	if turtle.getFuelLevel() < 1 then
		refuel( 512 )
	end

	while not turtle[ sDirection ]() do
		sleep( 5 )
	end
end

local function findNextEmptySlot( nCurrentPosition )
	local bFoundSlot

	while not bFoundSlot and nCurrentPosition < 17 do
		bFoundSlot = true

		for _, v in pairs( tSlot ) do
			if v == nCurrentPosition then
				-- This slot is occupied for other purposes
				bFoundSlot = false
				break
			end
		end

		if bFoundSlot and turtle.getItemCount( nCurrentPosition ) > 0 then
			bFoundSlot = false
		end

		if bFoundSlot then
			return nCurrentPosition
		else
			nCurrentPosition = nCurrentPosition + 1
		end
	end

	-- We went through all slots and found no suitable one (nCurrentPosition > 16)
	return false
end

local function findMaterial( sMaterial )
	local tItemDetail
	local nFirstEmptySlot

	for i = 1, 16 do
		tItemDetail = turtle.getItemDetail( i )

		if tItemDetail and tItemDetail.name == sMaterial then
			turtle.select( i )
			return true
		elseif tArgs.useStorage and not tItemDetail and not nFirstEmptySlot then
			-- First free slot items would go into when sucking from drawer
			nFirstEmptySlot = i
		end
	end

	if tArgs.useStorage then
		tItemDetail = turtle.getItemDetail( tSlot.storage )

		if not tItemDetail or tItemDetail.name ~= sInvName then
			-- No storage available
			return false
		end

		turtle.select( tSlot.storage )
		turtle.placeUp()

		local nItemAmount = math.min( nAvailableSlots*64, nNeededBlocks-nPlacedBlocks )
		local nCurrentTargetSlot = nFirstEmptySlot

		while nCurrentTargetSlot and nItemAmount > 0 do
			-- Make sure the items don't go into a reserved slot (could be in middle of inventory)
			turtle.select( nCurrentTargetSlot )

			if not turtle.suckUp( math.min( 64, nItemAmount ) ) then
				-- Drawer empty
				break
			end

			tItemDetail = turtle.getItemDetail( nCurrentTargetSlot )

			if tItemDetail.name ~= sMaterial then
				-- Drawer contained the wrong items
				turtle.dropUp()
				break
			else
				nItemAmount = nItemAmount - tItemDetail.count
			end

			nCurrentTargetSlot = findNextEmptySlot( nCurrentTargetSlot )
		end

		turtle.select( tSlot.storage )
		turtle.digUp()
		turtle.select( nFirstEmptySlot )

		-- We retrieved at least some items
		if not nCurrentTargetSlot or nCurrentTargetSlot > nFirstEmptySlot then
			return true
		end
	end

	-- Either no items were found or the drawer contained the wrong items
	return false
end

local function placeBlock()
	if turtle.detectDown() then
		nNeededBlocks = nNeededBlocks - 1
		return false
	end

	local tItemDetail = turtle.getItemDetail()

	if not tItemDetail or tItemDetail.name ~= tArgs.material then
		while not findMaterial( tArgs.material ) do
			userInput( "No blocks found" )
		end
	end

	while not turtle.placeDown() do
		if not turtle.attackDown() and not turtle.attack() then
			sleep( 1 )
		end
	end

	return true
end

local function drawerCleanup()
	local nSelectedSlot = turtle.getSelectedSlot()
	local tItemDetail = turtle.getItemDetail( tSlot.storage )
	local bPlacedDrawer = false

	if not tItemDetail or tItemDetail.name ~= sInvName then
		return
	end

	for i = 1, 16 do
		tItemDetail = turtle.getItemDetail( i )

		if tItemDetail and tItemDetail.name == tArgs.material then
			-- Only bother placing drawer when there are actually items to clean up
			if not bPlacedDrawer then
				turtle.select( tSlot.storage )
				turtle.placeUp()
				bPlacedDrawer = true
			end

			turtle.select( i )
			turtle.dropUp()
		end
	end

	if bPlacedDrawer then
		turtle.select( tSlot.storage )
		turtle.digUp()
		turtle.select( nSelectedSlot )
	end
end

local function parseArgs( tArgs )
	local tParsedArgs = {}
	local sArgName
	local vArgValue

	for _, sArg in pairs( tArgs ) do
		sArgName = sArg:match( "[%w_]+" )
		vArgValue = sArg:match( "[%w_]+%s*=%s*([%w_:%.]+)" )

		if vArgValue then
			if vArgValue == "true" then
				vArgValue = true
			elseif vArgValue == "false" then
				vArgValue = false
			elseif tonumber( vArgValue ) then
				vArgValue = tonumber( vArgValue )
			end

			tParsedArgs[ sArgName ] = vArgValue
		else
			tParsedArgs[ sArgName ] = true
		end
	end

	return tParsedArgs
end

local function printUsage()
	print( "Usage: " .. shell.getRunningProgram() .. " <width> <length> [args]\n" )
	print( "Use: " .. shell.getRunningProgram() .. " help\nfor a list of possible arguments" )
end

local function printHelp()
	textutils.pagedPrint( [=[
Valid arguments:

[material=minecraft:stone]:
Makes the program use stone for building
If no material is specified, material in slot 1 will be used

[drawer=true]
Makes the program take items out of a drawer in slot 16

[shulker=true]
Same as drawer option]=] )
end
-- Functions --


-- Initialisation --
if tonumber( tArgs[1] ) and tonumber( tArgs[2] ) then
	nWidth, nLength = tonumber( tArgs[1] ), tonumber( tArgs[2] )
	nNeededBlocks = nWidth * nLength -- Total amount of blocks needed (estimation)

	if nWidth < 1 or nLength < 1 then
		print( "Invalid sizing!" )
		printUsage()
		return
	end

	tArgs[1], tArgs[2] = nil, nil

	tArgs = parseArgs( tArgs )
else
	tArgs = parseArgs( tArgs )

	if tArgs.help then
		printHelp()
		return
	end

	printUsage()
	return
end

tArgs.useStorage = tArgs.drawer == true or tArgs.shulker == true

if tArgs.shulker == true then
	local tShulkerDetail = turtle.getItemDetail( tSlot.storage )

	if tShulkerDetail and tShulkerDetail.name:match( "shulker_box" ) then
		sInvName = tShulkerDetail.name
	end
end

if tArgs.drawer == true then
	local tDrawerDetail = turtle.getItemDetail( tSlot.storage )

	if tDrawerDetail and tDrawerDetail.name:match( "full_drawers_1" ) then
		sInvName = tDrawerDetail.name
	end
end

if not tArgs.material then
	local tMaterial = turtle.getItemDetail( 1 )

	if tMaterial then
		tArgs.material = tMaterial.name
	else
		print( "No material in slot 1 found!" )
		return
	end
end

for _ in pairs( tSlot ) do
	nAvailableSlots = nAvailableSlots - 1
end
-- Initialisation --


-- Main Program --
for x = 1, nWidth do
	for y = 1, nLength do
		if placeBlock() then
			nPlacedBlocks = nPlacedBlocks + 1
		end

		if y < nLength then
			move( "forward" )
		end
	end

	if x < nWidth then
		if x % 2 == 0 then
			move( "left" )
			move( "forward" )
			move( "left" )
		else
			move( "right" )
			move( "forward" )
			move( "right" )
		end
	end
end

if tArgs.useStorage then
	drawerCleanup()
end

term.setCursorPos( nInitialCursorX, nInitialCursorY )
print( "Placed down " .. nPlacedBlocks .. " block" .. ( nPlacedBlocks ~= 1 and "s" or "" ) )
-- Main Program --
