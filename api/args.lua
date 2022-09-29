-- Variables --
local argParseMT = {}

-- Metatable objects for different argument types --
local superMT = {}
local stringArgMT = setmetatable({}, {__index = superMT})
local intArgMT = setmetatable({}, {__index = superMT})
local boolArgMT = setmetatable({}, {__index = superMT})
-- Variables --

-- Functions --
function superMT:setRequired(required)
    assert(type(required) == "boolean", "Value must be true or false")

    self.isRequired = required
    return self
end

function superMT:setDescription(description)
    self.description = description
    return self
end

function stringArgMT:setDefault(default)
    assert(type(default == "string"), "Default value must be a string")

    self.defaultValue = default
    return self
end

function stringArgMT:parse(value)
    if self.minLength and #value < self.minLength then
        return false, "Value shorter than minimum length"
    end

    if self.maxLength and #value > self.maxLength then
        return false, "Value longer than maximum length"
    end

    return true, value
end

function stringArgMT:setMinLength(minLength)
    assert(tonumber(minLength), "Minimum length value must be number")

    self.minLength = minLength
    return self
end

function stringArgMT:setMaxLength(maxLength)
    assert(tonumber(maxLength), "Minimum length value must be number")

    self.maxLength = maxLength
    return self
end

function intArgMT:setDefault(default)
    assert(type(default == "number"), "Default value must be a number")

    self.defaultValue = default
    return self
end

function intArgMT:parse(value)
    local parsed = tonumber(value)

    if not parsed then
        return false, "Could not parse value as integer"
    end

    if self.min and parsed < self.min then
        return false, "Value below minimum"
    end

    if self.max and parsed > self.max then
        return false, "Value above maximum"
    end

    return true, parsed
end

function intArgMT:setMin(min)
    assert(tonumber(min), "Minimum value must be number")

    self.min = min
    return self
end

function intArgMT:setMax(max)
    assert(tonumber(max), "Maximum value must be number")

    self.max = max
    return self
end

function boolArgMT:setDefault(default)
    assert(type(default == "boolean"), "Default value must be a boolean")

    self.defaultValue = default
    return self
end

function boolArgMT:parse(value)
    if value == "true" or value == "" or value == "1" then  -- Empty just sets flag to true
        return true, true
    elseif value == "false" or value == "0" then
        return true, false
    end

    return false, "Value not true or false"
end

local function createArgument(argType)
    local argument = {}

    if argType == "string" then
        return setmetatable(argument, {__index=stringArgMT})
    elseif argType == "integer" then
        return setmetatable(argument, {__index=intArgMT})
    elseif argType == "boolean" then
        return setmetatable(argument, {__index=boolArgMT})
    end

    error("Argument type '" .. argType .. "' not defined")
end

function argParseMT:setAlias(abbr, full)
    self.alias[abbr] = full
end

function argParseMT:setAliases(abbrFullPairs)
    for k, v in pairs(abbrFullPairs) do
        self:setAlias(k, v)
    end
end

local function splitArguments(...)
    local rawArgs = {...}
    local options, arguments = {}, {}
    local optionsEnd = 1

    -- Search for end of options backwards
    for i = #rawArgs, 1, -1 do
        if rawArgs[i]:match("^%-%-?$") then
            -- '--' or '-' as delimiter between options and arguments
            table.remove(rawArgs, i)
            optionsEnd = i - 1
            break
        elseif rawArgs[i]:match("^%-%-?.+$") then
            -- Found a valid option, following value will be option value
            -- otherwise, if end is reached, option must be a flag
            optionsEnd = math.min(#rawArgs, i + 1)
            break
        else
            optionsEnd = i
        end
    end

    for i = 1, #rawArgs do
        if i <= optionsEnd then
            options[#options + 1] = rawArgs[i]
        else
            arguments[#arguments + 1] = rawArgs[i]
        end
    end

    return options, arguments
end

local function inflateOptions(self, options)
    local inflatedOptions = {}

    for _, v in pairs(options) do
        local shortOption, value = v:match("^%-([A-Za-z]+)(%d*)$")

        if shortOption then
            for abbrOption in shortOption:gmatch(".") do
                if self.alias[abbrOption] then
                    inflatedOptions[#inflatedOptions + 1] = "--" .. self.alias[abbrOption]

                    if value and #value > 0 then
                        inflatedOptions[#inflatedOptions + 1] = value
                    end
                else
                    error("Unrecognized option '-" .. abbrOption .. "'", 0)
                end
            end
        else
            inflatedOptions[#inflatedOptions + 1] = v
        end
    end

    return inflatedOptions
end

local function createOptionPairs(inflatedOptions)
    local optionPairs = {}
    local currentOption

    for _, v in pairs(inflatedOptions) do
        local optionName = v:match("^%-%-(.+)$")

        if optionName then
            if currentOption then
                optionPairs[currentOption] = ""
            end

            currentOption = optionName
        elseif currentOption then
            optionPairs[currentOption] = v
            currentOption = nil
        end
    end

    if currentOption then
        optionPairs[currentOption] = ""
    end

    return optionPairs
end

local function parseArgValues(self, optionPairs)
    for k, v in pairs(optionPairs) do
        if not self.arguments[k] then
            error("Unknown option '" .. k .. "'")
        end

        local succ, result = self.arguments[k]:parse(v)

        if not succ then
            error("Could not parse arg '" .. k .. "': " .. result, 3)
        end

        optionPairs[k] = result
    end

    return optionPairs
end

local function fillDefaults(self, optionPairs)
    for name, argument in pairs(self.arguments) do
        if optionPairs[name] == nil and argument.defaultValue ~= nil then
            optionPairs[name] = argument.defaultValue
        end
    end

    return optionPairs
end

local function checkRequiredArguments(self, optionPairs)
    for name, argument in pairs(self.arguments) do
        if optionPairs[name] == nil and argument.isRequired then
            error("Argument '" .. name .. "' is required")
        end
    end

    return optionPairs
end

function argParseMT:addArgument(name, argType)
    local argument = createArgument(argType)
    self.arguments[name] = argument

    return argument
end

function argParseMT:parse(...)
    local options, arguments = splitArguments(...)

    return checkRequiredArguments(self,
            fillDefaults(self,
                    parseArgValues(self,
                            createOptionPairs(
                                    inflateOptions(self, options)
                            )
                    )
            )
    ), arguments
end

local function collectAliases(argParseObj, fullName)
    local aliases = {}

    for key, value in pairs(argParseObj.alias) do
        if value == fullName then
            aliases[#aliases + 1] = key
        end
    end

    return aliases
end

function argParseMT:printHelp()
    local rows = {}
    for name, value in pairs(self.arguments) do
        rows[#rows + 1] = {
            name,
            table.concat(collectAliases(self, name), ", "),
            value.description or ""
        }
    end

    textutils.pagedTabulate(colors.lightBlue, {"Argument", "Alias", "Description"}, colors.white, table.unpack(rows))
end

local function new()
    return setmetatable(
            {arguments = {}, alias = {}},
            {__index = argParseMT}
    )
end
-- Functions --


-- Returning of API --
return {
    new = new
}
-- Returning of API --