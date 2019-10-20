-- Variables --
local tArgs = { ... }
local nWidth, nLength

local tValidBlocks = {
	[ "minecraft:cobblestone" ]		=	true,
	[ "minecraft:glass" ]			=	true
}
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
	nFuelLevel = nFuelLevel or 1

	while turtle.getFuelLevel() < nFuelLevel do
		for i = 1, 16 do
			turtle.select( i )

			while turtle.refuel( 1 ) and turtle.getFuelLevel() < nFuelLevel do
			end
		end

		if turtle.getFuelLevel() < 1 then
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

local function findMaterial( sMaterial )
	local tItemDetail

	for i = 1, 16 do
		tItemDetail = turtle.getItemDetail( i )

		if tItemDetail and tItemDetail == sMaterial then
			turtle.select( i )
			return true
		end
	end

	return false
end

local function placeBlock()
	while turtle.getItemCount() == 0 and not findMaterial( tArgs.material ) do
		userInput( "No blocks found" )
	end

	while not turtle.placeDown() and not turtle.detectDown() do
		if not turtle.attackDown() then
			turtle.attack()
		end
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
	print([[
Valid arguments:

[material=minecraft:stone]:
Makes the program use stone for building
If no material is specified, material in slot 1 will be used]] )
end
-- Functions --


-- Initialisation --
if tonumber( tArgs[1] ) and tonumber( tArgs[2] ) then
	nWidth, nLength = tonumber( tArgs[1] ), tonumber( tArgs[2] )

	if nWidth <= 0 or nLength <= 0 then
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

if not tArgs.material then
	local tMaterial = turtle.getItemDetail( 1 )

	if tMaterial then
		tArgs.material = tMaterial.name
	else
		print( "No material in slot 1 found!" )
		return
	end
end
-- Initialisation --


-- Main Program --
for x = 1, nWidth do
	for y = 1, nLength do
		placeBlock()

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
-- Main Program --
