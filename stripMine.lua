-- Variables --
local tProgram		=	{
	availableSlots		=	16,
	fuelLevel			=	512,
	invCheckInterval	=	10,

	placeChests			=	false,

	platformWhitelist	=	{
		[ "minecraft:cobblestone" ] = true,
		[ "minecraft:stone" ] = true,
		[ "minecraft:dirt" ] = true,
		[ "minecraft:granite" ] = true,
		[ "minecraft:diorite" ] = true,
		[ "minecraft:andesite" ] = true,
	}
}

local tChestNames = {
	[ "minecraft:chest" ]			=	true,
	[ "minecraft:trapped_chest" ]	=	true,
	[ "ironchest:iron_chest" ]		=	true,
	[ "ironchest:gold_chest" ]		=	true,
	[ "ironchest:diamond_chest" ]	=	true,
	[ "ironchest:copper_chest" ]	=	true,
	[ "ironchest:silver_chest" ]	=	true,
	[ "ironchest:crystal_chest" ]	=	true,
	[ "ironchest:obsidian_chest" ]	=	true
}

local sDrawerName
local sShulkerName

local tSlot			=	{
	chest		=	15,
	torch		=	16,
	drawer		=	15,
	shulker		=	14
}

local tDrawerContent	=	{
	[ "minecraft:cobblestone" ]	=	true,
	[ "minecraft:diorite" ]		=	true,
	[ "minecraft:andesite" ]	=	true,
	[ "minecraft:gravel" ]		=	true,
	--[ "minecraft:granite" ]		=	true
}

local tArgs			=	{ ... }

local xSize, ySize = term.getSize()
local nXSpace = xSize - 7
local nInitialCursorX, nInitialCursorY = term.getCursorPos()

local tInspectMapping = {
	up		=	"inspectUp",
	down	=	"inspectDown",
	forward	=	"inspect"
}
-- Variables --


-- Functions --
local function dig( sDirection )
	--[[
		sDirection	-	Direction in which to dig, possible directions:
			forward, up, down
	]]--

	local bIsBlock, tBlock = turtle[ tInspectMapping[ sDirection ] ]()

	if not bIsBlock then
		return false
	end

	while sDirection == "up" and turtle.detectUp() or
		sDirection == "down" and turtle.detectDown() or
		sDirection == "forward" and turtle.detect() do

		if sDirection == "up" then
			turtle.digUp()
		elseif sDirection == "down" then
			turtle.digDown()
		elseif sDirection == "forward" then
			turtle.dig()
		end

		if tBlock.name == "minecraft:gravel" or tBlock.name == "minecraft:sand" then
			sleep( 0.25 )
		end
	end

	return true
end

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

local function printProgress( nCurrentBlock )
	term.setCursorPos( 1, ySize )

	local str = "Block " .. nCurrentBlock .. " out of " .. tArgs.length

	term.write( str )
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
		refuel( tProgram.fuelLevel )
	end

	while not turtle[ sDirection ]() do
		if sDirection == "back" or not dig( sDirection ) then
			if sDirection == "forward" and not turtle.attack() or
			sDirection == "down" and not turtle.attackDown() or
			sDirection == "up" and not turtle.attackUp() then
				sleep( 1 )
			end
		end
	end
end

local function placePlatform()
	if turtle.detectDown() then
		return
	end

	local tCurrentItem

	for i = 1, 16 do
		tCurrentItem = turtle.getItemDetail( i )

		if tCurrentItem and tProgram.platformWhitelist[ tCurrentItem.name ] then
			if i ~= turtle.getSelectedSlot() then
				turtle.select( i )
			end

			break
		end
	end

	turtle.placeDown()
end

local function compressStacks()
	local bSlotForbidden -- True if the slot is otherwise used (chest, torch, etc.)
	local bSlotSelected -- True if slot from which items are transferred away is selected
	local nTransferToIndex = 1
	local vItemDetailFrom, vItemDetailTo

	for i = 2, 16 do
		for k, v in pairs( tSlot ) do
			if i == v then
				bSlotForbidden = true
				break
			end
		end

		if not bSlotForbidden then
			vItemDetailFrom = turtle.getItemDetail( i )

			while turtle.getItemCount( i ) > 0 do
				-- We've reached the slot from which we're trying to transfer from
				if nTransferToIndex == i then
					break
				end

				vItemDetailTo = turtle.getItemDetail( nTransferToIndex )

				-- Only if the slot is empty or the item type is the same, bother checking
				if not vItemDetailTo or vItemDetailFrom.name == vItemDetailTo.name then
					-- Only select the slot we're transferring *from* if we can actually transfer
					if not bSlotSelected then
						turtle.select( i )
						bSlotSelected = true
					end

					turtle.transferTo( nTransferToIndex )
				end

				nTransferToIndex = nTransferToIndex + 1
			end

			bSlotSelected = false
			nTransferToIndex = 1
		end
	end
end

local function placeChest()
	local bPlaceChest = tArgs.chest and turtle.getItemCount( tSlot.chest ) > 0 and turtle.getItemDetail( tSlot.chest )["name"] == "minecraft:chest"
	local bPlaceDrawer = tArgs.drawer and turtle.getItemCount( tSlot.drawer ) > 0 and turtle.getItemDetail( tSlot.drawer )["name"] == sDrawerName
	local bPlaceShulker = tArgs.shulker and turtle.getItemCount( tSlot.shulker ) > 0 and turtle.getItemDetail( tSlot.shulker )["name"] == sShulkerName

	if not ( bPlaceChest or bPlaceDrawer or bPlaceShulker ) then
		return false
	end

	local bSlotAvailable = true
	local bSavedJunkItem = false
	local nSelectedSlot = turtle.getSelectedSlot()
	local bCompressStacks = bPlaceDrawer and not ( bPlaceChest or bPlaceShulker )

	local nItemCount = 0
	local nTargetCount = 0

	if bPlaceChest then
		dig( "down" )
		turtle.select( tSlot.chest )
		turtle.placeDown()
	end

	if bPlaceDrawer then
		turtle.select( tSlot.drawer )
		turtle.placeUp()
	end

	if bPlaceShulker then
		if bPlaceChest or bPlaceDrawer then
			-- Otherwise the item dug out would go in the chest slot
			turtle.select( nSelectedSlot )
		end

		dig( "forward" )
		turtle.select( tSlot.shulker )
		turtle.place()
	end

	for i = 1, 16 do
		for k, v in pairs( tSlot ) do
			if i == v then
				bSlotAvailable = false
				break
			end
		end

		if bSlotAvailable then
			nItemCount = turtle.getItemCount( i )

			-- Save some items for building bridges in lava lakes etc.
			if not bSavedJunkItem then
				if nItemCount > 0 and tProgram.platformWhitelist[ turtle.getItemDetail( i )["name"] ] then
					nTargetCount = math.min( 32, nItemCount )
					bSavedJunkItem = true
				end

			else
				nTargetCount = 0
			end

			-- Only bother selecting slots when there are items (selecting is slow)
			if nItemCount > 0 then
				turtle.select( i )
			end

			if nItemCount > nTargetCount and bPlaceDrawer and tDrawerContent[ turtle.getItemDetail( i )["name"] ] then
				turtle.dropUp( nItemCount - nTargetCount )

				nItemCount = turtle.getItemCount() -- Maybe not all items could fit
			end

			if nItemCount > nTargetCount and bPlaceChest then
				turtle.dropDown( nItemCount - nTargetCount )

				nItemCount = turtle.getItemCount() -- Maybe still some items left
			end

			if nItemCount > nTargetCount and bPlaceShulker then
				turtle.drop( nItemCount - nTargetCount )
			end

			if turtle.getItemCount() > nTargetCount then
				-- If we couldn't get rid of this stack at all, try and compress it,
				-- as it may be in a random slot
				bCompressStacks = true
			end
		end

		bSlotAvailable = true
	end

	if bPlaceShulker then
		turtle.select( tSlot.shulker )

		if turtle.getItemCount() > 0 then
			-- Maybe inventory was full and an item landed here anyway
			turtle.dropDown()
		end

		turtle.dig()
	end

	if bPlaceDrawer then
		turtle.select( tSlot.drawer )

		if turtle.getItemCount() > 0 then
			-- Maybe inventory was full and an item landed here anyway
			turtle.dropDown()
		end

		turtle.digUp()
	end

	if bCompressStacks then
		compressStacks()
	end

	turtle.select( nSelectedSlot )
end

local function checkInventory( bPlacedChest )
	local nBlockedSlots = 0
	local bSlotIgnore = false

	for i = 1, 16 do
		for k, v in pairs( tSlot ) do
			if i == v then
				bSlotIgnore = true
				break
			end
		end

		if not bSlotIgnore and turtle.getItemCount( i ) > 0 then
			nBlockedSlots = nBlockedSlots + 1
		end

		bSlotIgnore = false
	end

	if nBlockedSlots == tProgram.availableSlots then
		if ( not tArgs.chest and not tArgs.drawer and not tArgs.shulker ) or bPlacedChest then
			userInput( "Inventory full" )
			return
		end

		placeChest()
		checkInventory( true )
	end
end

local function placeTorch()
	local item = turtle.getItemDetail( tSlot.torch )

	if not item or item.name ~= "minecraft:torch" then
		return false
	end

	local nSelectedSlot

	nSelectedSlot = turtle.getSelectedSlot()
	turtle.select( tSlot.torch )
	move( "up" )
	turtle.placeDown()
	turtle.select( nSelectedSlot )
	move( "forward" )
	move( "down" )

	return true
end

local function parseArgs( tArgs )
	local tParsedArgs = {}
	local sArgName
	local vArgValue

	for i = 1, #tArgs do
		sArgName = tArgs[i]:match( "[%w_]+" )
		vArgValue = tArgs[i]:match( "[%w_]+%s*=%s*([%w_]+)" )

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
	print( "Usage: " .. shell.getRunningProgram() .. " length=<length> [chest[=true]] [drawer[=true]] [shulker[=true]]" )
end

local function printHelp()
	textutils.pagedPrint( [=[
Valid arguments:

[placeTorches[=false]]:
Place torches or not, default is true

[torchSpacing=<spacing>]
Sets the torch spacing to <spacing> being > 0

[emptyAtEnd[=false]]:
Empty the inventory at end of mining, default is true

[chest[=true]]:
Places chest in floor whenever the inventory is full

[drawer[=true]]:
Places a drawer and empties junk items into it

[shulker[=true]]:
Places a shulker and empties items into it whenever inventory is full. Shulker box is picked up again afterwards

[placePlatform[=false]]:
Places blocks whenever there is no solid block below, default is true]=] )
end
-- Functions --


-- Initialisation --
tArgs = parseArgs( tArgs )

if tArgs.help == true then
	printHelp()
	return
end

if type( tArgs.length ) ~= "number" then
	printUsage()
	error( "No length given" )
end

if tArgs.chest and tArgs.shulker then
	error( "Chest and Shulker options are mutually exclusive!" )
end

-- Only false if specified to be false
tArgs.placeTorches = tArgs.placeTorches ~= false

tArgs.placePlatform = tArgs.placePlatform ~= false

tArgs.emptyAtEnd = tArgs.emptyAtEnd ~= false

if tArgs.chest ~= true then
	tSlot.chest = nil
end

if tArgs.drawer ~= true then
	tSlot.drawer = nil
else
	local tDrawerDetail = turtle.getItemDetail( tSlot.drawer )

	if tDrawerDetail and tDrawerDetail:match( "_drawers_[124]") then
		sDrawerName = tDrawerDetail.name
	end
end

if tArgs.shulker ~= true then
	tSlot.shulker = nil
else
	local tShulkerDetail = turtle.getItemDetail( tSlot.shulker )

	if tShulkerDetail and tShulkerDetail.name:match( "shulker_box" ) then
		sShulkerName = tShulkerDetail.name
	end
end

if type( tArgs.torchSpacing ) == "number" then
	tArgs.torchSpacing = tArgs.torchSpacing > 0 or 12
else
	tArgs.torchSpacing = 12 -- 12 is the optimal spacing so the light level is at least 8
end

for k, v in pairs( tSlot ) do
	tProgram.availableSlots = tProgram.availableSlots - 1
end

term.setCursorPos( 1, ySize )
term.clearLine()
-- Initialisation --


-- Main Program --
local bTravelledBlock = false

for i = 1, tArgs.length do
	printProgress( i )

	if tArgs.placeTorches == true and ( i-2 ) % ( tArgs.torchSpacing+1 ) == 0 then
		bTravelledBlock = placeTorch()
	end

	if ( i-2 ) % ( tProgram.invCheckInterval+1 ) == 0 then
		checkInventory()
	end

	if not bTravelledBlock then
		move( "forward" )
		dig( "up" )
	end

	if tArgs.placePlatform == true then
		placePlatform()
	end

	bTravelledBlock = false
end

if tArgs.drawer and tArgs.emptyAtEnd then
	placeChest()
end

-- Clear up the "Block x of y" and make the cursor not be off-screen
term.clearLine()
term.setCursorPos( nInitialCursorX, nInitialCursorY )
-- Main Program --
