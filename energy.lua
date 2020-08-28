-- Variables --
local SCHEME = {
	BG_COLOUR				=	"f";
	FG_COLOUR				=	"e";
	FG_NET_ENERGY_LOSS		=	"d";
	FG_NET_ENERGY_GAIN		=	"c";
    CELL_NUMBER             =   "e";

	LIST_BG_COLOUR			=	"a";
	SCROLL_BAR_FG			=	"9";
	LIST_OBJECT_BG1			=	"f";
	LIST_OBJECT_BG2			=	"8";
	LIST_OBJECT_PERC_BAR	=	"6";
	GRAPH_BG				=	"7";

	OUTPUT_OFF_FG			=	"e";
	OUTPUT_ON_FG			=	"c";
}

local COLOUR_PALETTE = {
    [ "f" ]     =   0x2b2b2b;
    [ "e" ]     =   0xe0e0e0;
    [ "d" ]     =   0xD24D57;
    [ "c" ]     =   0x5C97BF;
    [ "b" ]     =   0xFFFFFF;
	[ "a" ]		=	0x303030;
	[ "9" ]		=	0x9b9b9b;
	[ "8" ]		=	0x1c1c1c;
	[ "7" ]		=	0xc6c6c6;
	[ "6" ]		=	0x964400;
}

local program = {
    energy_zones	=	{
        {
			name			= "Optional Output",
            isPlural        = false,
            side            = "right",
            fromPercentage  = 40,
            toPercentage    = 95,
            defaultState    = true,
        },
        {
			name			= "Generators",
            isPlural        = true,
            side            = "left",
            fromPercentage  = 75,
            toPercentage    = 95,
            defaultState    = false,
        },
        {
			name			= "Low Energy Alarm",
            isPlural        = false,
            side            = "top",
            fromPercentage  = 20,
            toPercentage    = 20,
            defaultState    = false,
        },
    },

	check_interval		=	5;
	updateSign_interval	=	2;

	PATH			=	{
		gui				= "/lib_energy/gui.lua",
        cms             = "/lib_energy/cms.lua",
		ui_file			= "/lib_energy/energy_ui",
		gui_elements	= "/lib_energy/lib_gui"
	};

	cell_levels			=	{
		maximum		=	0;
		current		=	-1;
		lower_peak	=	0;
		higher_peak	=	0;
	};

	energy_cells		=	nil;
	--[[
		{
			peripheral		=	proxied peripheral;
			currentEnergy	=	current energy stored;
			maximumEnergy	=	maximum energy stored;
		}
	]]--

	VALID_PERIPHERALS	=	{
        ["silents_mechanisms:machine"] = true,
        ["energy_device"]             = true,
		["ie_lv_capacitor"]           = true,
		["rftools_powercell"]         = true,
	},

	updateSigns			=	{ "o", "ø" };
	currentSign			=	1;

	--[[
		Which interface is currently selected?
		Valid values: "generalInfo", "cellInfo", "outputInfo"
	]]--
	currentInterface	=	"generalInfo";
}

local ui
-- Variables --


-- Functions --
local function getEnergyCellsConnected()
	local peripheralsAvailable = peripheral.getNames()

	program.energy_cells = {}

	for _, v in pairs(peripheralsAvailable) do
		if program.VALID_PERIPHERALS[peripheral.getType(v)] then
			program.energy_cells[#program.energy_cells+1] = {
				peripheral = peripheral.wrap(v);
				change = 0;
				currentEnergy = -1;
			}
		end
	end
end

local function getMaximumEnergyStored()
	local maximumAmount = 0
	local cellMaximum = 0

	for k, v in pairs(program.energy_cells) do
		cellMaximum = v.peripheral.getMaxEnergy()
		v.maximumEnergy = cellMaximum
		maximumAmount = maximumAmount + cellMaximum
	end

	return maximumAmount
end

local function formatNumber( number, nTargetNumberLength )
	local formatted, match = tostring( math.floor( number ) ), nil

	if nTargetNumberLength then
		formatted = ( "0" ):rep( #tostring( math.floor( nTargetNumberLength ) )-#formatted ) .. formatted
	end


    while match ~= 0 do
        formatted, match = formatted:gsub( "^(-?%d+)(%d%d%d)", "%1,%2" )
    end

    return formatted
end

local function updateCellInfo( cell )
    cell.textArea.setVariable("ENERGYSTORED", formatNumber(cell.currentEnergy, cell.maximumEnergy))
	cell.textArea.setVariable("CHANGE", formatNumber(cell.change))
	cell.fillGraph.setBoundaries({width = 100 * (cell.currentEnergy / cell.maximumEnergy ) .. "%"})

    if program.currentInterface == "cellInfo" then
        cell.fillGraph.draw()
        cell.textArea.draw()
    end
end

local function getEnergyStored()
	local currentAmount = 0
	local cellAmount = 0
    local currTime

	for k, v in pairs( program.energy_cells ) do
        currTime = os.clock()
		cellAmount = v.peripheral.getEnergy()

		if v.currentEnergy ~= -1 then
			v.change = (cellAmount - v.currentEnergy) / ((currTime - v.prevTime) * 20)
		end

		v.currentEnergy = cellAmount
        v.prevTime = currTime

        updateCellInfo(v)

		currentAmount = currentAmount + cellAmount

        -- Reduce overhead
        os.sleep(0.5)
	end

	return currentAmount
end

local function makeCellListEntries()
	local currentCanvas, currentGraphBackground

	for k, v in ipairs( program.energy_cells ) do
		currentCanvas = gui.createGUIObject( {
			top			=	0;
			height		=	5;
			left		=	0;
			right		=	0;
			bg_color	=	k%2 == 0 and SCHEME.LIST_OBJECT_BG1 or SCHEME.LIST_OBJECT_BG2;
		}, "CanvasObject", ui.cellList )

		currentGraphBackground = gui.createGUIObject( {
			top			=	1;
			left		=	1;
			right		=	1;
			height		=	1;
			bg_color	=	SCHEME.GRAPH_BG;
		}, "CanvasObject", currentCanvas )

		v.fillGraph = gui.createGUIObject( {
			top			=	0;
			left		=	0;
			width		=	100*( v.currentEnergy/v.maximumEnergy ) .. "%";
			bottom		=	0;
			bg_color	=	SCHEME.LIST_OBJECT_PERC_BAR;
		}, "CanvasObject", currentGraphBackground )

		v.textArea = gui.createGUIObject( {
			top			=	2;
			left		=	1;
			right		=	1;
			bottom		=	0;
			bg_color	=	k%2 == 0 and SCHEME.LIST_OBJECT_BG1 or SCHEME.LIST_OBJECT_BG2;
			fg_color	=	SCHEME.FG_COLOUR;
			text		=	{
				"%%ENERGYSTORED;/%%MAXIMUMENERGY; RF";
				"%%CHANGE; RF/t"
			};
			variables	=	{
				ENERGYSTORED	=	formatNumber( v.currentEnergy, v.maximumEnergy );
				MAXIMUMENERGY	=	formatNumber( v.maximumEnergy );
				CHANGE			=	v.change > 0 and "+" or "" .. formatNumber( v.change );
			}
		}, "TextArea", currentCanvas )
	end
end

local function makeOutputListEntries()
	for k, v in pairs( program.energy_zones ) do
		v.textArea = gui.createGUIObject( {
			top			= 0,
			left		= 0,
			right		= 0,
			height		= 4,
            fg_color    = SCHEME.FG_COLOUR,
			bg_color	=	k % 2 == 0 and SCHEME.LIST_OBJECT_BG1 or SCHEME.LIST_OBJECT_BG2,
			margin		=	1,
			text		=	{
				v.name .. (v.isPlural and " are" or " is") .. " &%%STATUSCOLOUR;;turned %%STATUS;&o;",
				"Turn" .. (v.isPlural and "" or "s") .. " %%NOTSTATUS; at %%PERCENTAGE;%",
			},
			variables	=	{
				STATUSCOLOUR	=	v.defaultState and SCHEME.OUTPUT_ON_FG or SCHEME.OUTPUT_OFF_FG,
				STATUS			=	v.defaultState and "on" or "off",
				NOTSTATUS		=	v.defaultState and "off" or "on",
				PERCENTAGE		=	v.fromPercentage,
			}
		}, "TextArea", ui.outputList )
	end
end

local function formatSeconds( number )
	local days = math.floor( number/86400 )
	number = number - days*86400
	local hours = math.floor( number/3600 )
	number = number - hours*3600
	local minutes = math.floor( number/60 )
	number = number - minutes*60

	return ( days > 0 and days.."d " or "" )..
		( hours > 0 and hours.."h " or "" )..
		( minutes > 0 and minutes.."m " or "" )..
		( number >= 0 and number.."s" or "")
end

local function setRedstoneOutput( currentPercentage )
	local stateDiffersDefault

	for k, v in pairs(program.energy_zones) do
		if v.currentlyActive == nil then
			v.currentlyActive = false
		end

		if currentPercentage <= v.fromPercentage and not v.currentlyActive then
			v.currentlyActive = true
		elseif currentPercentage > v.toPercentage and v.currentlyActive then
			v.currentlyActive = false
		end

		stateDiffersDefault = v.currentlyActive ~= v.defaultState

		v.textArea.setVariable("STATUS", stateDiffersDefault and "on" or "off")
		v.textArea.setVariable("STATUSCOLOUR", stateDiffersDefault and SCHEME.OUTPUT_ON_FG or SCHEME.OUTPUT_OFF_FG)
		v.textArea.setVariable("NOTSTATUS", stateDiffersDefault and "off" or "on")
		v.textArea.setVariable("PERCENTAGE", v.currentlyActive and v.toPercentage or v.fromPercentage)
        rs.setOutput(v.side, stateDiffersDefault)
	end

	if program.currentInterface == "outputInfo" then
		ui.outputList.draw()
	end
end

local function continuousCellCheck()
	local maxLossGainChanged = false
    local prevTime
    local timeDiff

    while true do
        prevTime = os.clock()
    	local energyStored = getEnergyStored()

    	if program.cell_levels.current == -1 then
    		program.cell_levels.current = energyStored
    	end

    	local currentChange = (energyStored-program.cell_levels.current) / ((os.clock() - prevTime) * 20)
    	local remainingSeconds
    	currentChange = currentChange > 0 and math.ceil(currentChange) or math.floor(currentChange)
    	program.cell_levels.current = energyStored

    	if currentChange > program.cell_levels.higher_peak then
    		program.cell_levels.higher_peak = currentChange
    		ui.maxLossGain.setVariable( "MAXIMUMGAIN", "+" .. formatNumber( currentChange ) )
			maxLossGainChanged = true
    	elseif currentChange < program.cell_levels.lower_peak then
    		program.cell_levels.lower_peak = currentChange
    		ui.maxLossGain.setVariable( "MAXIMUMLOSS", formatNumber( currentChange ) )
			maxLossGainChanged = true
    	end

    	ui.currentEnergyInfo.setVariable(
    		"CURRENTCHANGE", ( currentChange > 0 and "+" or "" ) .. formatNumber( currentChange )
    	)
    	ui.currentEnergyInfo.setVariable(
    		"COLOR", currentChange > 0 and SCHEME.FG_NET_ENERGY_GAIN or currentChange < 0 and SCHEME.FG_NET_ENERGY_LOSS or SCHEME.FG_COLOUR
    	)
    	ui.currentEnergyInfo.setVariable(
    		"CURRENTENERGY", formatNumber( energyStored )
    	)
    	ui.currentEnergyInfo.setVariable(
    		"CURRENTPERCENTAGE", math.floor( energyStored/program.cell_levels.maximum*100 )
    	)

    	if currentChange ~= 0 then
    		remainingSeconds = math.floor( ( currentChange<0 and energyStored or program.cell_levels.maximum-energyStored )/( math.abs( currentChange*20 ) ) )
    	end

    	ui.remainingInfo.setVariable(
    		"TIME", currentChange ~= 0 and formatSeconds( remainingSeconds ) or ""
    	)
    	ui.remainingInfo.setVariable(
    		"RTYPE", currentChange > 0 and remainingSeconds and "until full" or currentChange == 0 and "" or "until empty"
    	)
    	ui.remainingInfo.setVariable(
    		"COLOR", currentChange > 0 and SCHEME.FG_NET_ENERGY_GAIN or SCHEME.FG_NET_ENERGY_LOSS
    	)

    	setRedstoneOutput( math.floor( energyStored/program.cell_levels.maximum*100 ) )

		if program.currentInterface == "generalInfo" then
	    	ui.remainingInfo.draw()
	    	ui.currentEnergyInfo.draw()

			if maxLossGainChanged then
				ui.maxLossGain.draw()
				maxLossGainChanged = false
			end
		end

        os.sleep(program.check_interval)
    end
end

local function updateSign()
	while true do
		if program.currentSign < #program.updateSigns then
			program.currentSign = program.currentSign + 1
		else
			program.currentSign = 1
		end

		if program.currentInterface == "generalInfo" then
			ui.updateSign.setVariable( "UPDATESIGN", program.updateSigns[ program.currentSign ] )
			ui.updateSign.draw()
		end

		os.sleep(program.updateSign_interval)
	end
end

local function initialise()
    os.loadAPI(program.PATH.gui)
    os.loadAPI(program.PATH.cms)

	gui.setPath(program.PATH.gui_elements)
	gui.setPalette(COLOUR_PALETTE)

	ui = gui.loadUIFile(program.PATH.ui_file, {SCHEME = SCHEME, program = program})

	getEnergyCellsConnected()
    program.cell_levels.maximum = getMaximumEnergyStored()
	ui.amountCells.setVariable( "NUMCELLS", #program.energy_cells )

    -- Remove 's' from cells if #cells is 1
	if #program.energy_cells == 1 then
		ui.amountCells.setVariable( "OPTS", "" )
	end

    -- Create all the list entries
	makeCellListEntries()
	makeOutputListEntries()

    -- Show the UI for the first time
    ui.mainCanvas.draw()

	continuousCellCheck = cms.add(continuousCellCheck)
	updateSign = cms.add(updateSign)

    continuousCellCheck()
    updateSign()
end
-- Functions --


-- Initialisation --
initialise()
-- Initialisation --


-- Main Program --
local e, hitmap
while true do
	e = { cms.yield() }

	if e[1] == "char" and e[2]:lower() == "q" then
        cms.remove(continuousCellCheck)
        cms.remove(updateSign)
		break
	elseif e[1] == "mouse_click" then
		if program.currentInterface == "generalInfo" then
			hitmap = gui.checkCanvasForClick( ui.mainCanvas, e[3], e[4] )
		elseif program.currentInterface == "cellInfo" then
			hitmap = gui.checkCanvasForClick( ui.cellInfoCanvas, e[3], e[4] )
		else
			hitmap = gui.checkCanvasForClick( ui.outputInfoCanvas, e[3], e[4] )
		end

		if hitmap[1] == ui.toCellInfo then
			program.currentInterface = "cellInfo"
			ui.cellInfoCanvas.draw()
		elseif hitmap[1] == ui.toOutputInfo then
			program.currentInterface = "outputInfo"
			ui.outputInfoCanvas.draw()
		elseif hitmap[1] == ui.cellInfoToMainCanvas or hitmap[1] == ui.outputInfoToMainCanvas then
			program.currentInterface = "generalInfo"
			ui.mainCanvas.draw()
		elseif hitmap[1] == ui.cellScrollUp then
			if ui.cellList.setScroll( -1, true ) then
				ui.cellList.draw()
			end
		elseif hitmap[1] == ui.cellScrollDown then
			if ui.cellList.setScroll( 1, true ) then
				ui.cellList.draw()
			end
		elseif hitmap[1] == ui.outputScrollUp then
			if ui.outputList.setScroll( -1, true ) then
				ui.outputList.draw()
			end
		elseif hitmap[1] == ui.outputScrollDown then
			if ui.outputList.setScroll( 1, true ) then
				ui.outputList.draw()
			end
		end
	end
end
-- Main Program --
