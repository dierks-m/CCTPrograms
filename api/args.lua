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
    value = value:match("^'(.+)'$") or value -- Strip explicit single quotes

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
    if value == "true" or value == "" or value == "1" or value == true then  -- Empty just sets flag to true
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
        optionsEnd = i - 1

        if rawArgs[i]:match("^%-%-?$") then
            -- '--' or '-' as delimiter between options and arguments
            table.remove(rawArgs, i)
            break
        elseif rawArgs[i]:match("^%-%-.+$") or rawArgs[i]:match("^%-[A-Za-z]+$") then
            -- Found a valid option, following value will be option value
            -- otherwise, if end is reached, option must be a flag
            optionsEnd = math.min(#rawArgs, i + 1)
            break
        elseif rawArgs[i]:match("^%-[A-Za-z]+%d+$") then
            -- Short option, but with value already assigned
            optionsEnd = i
            break
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

---
-- Splits short options with directly attached values (e.g., '-xzf5') to pairs
-- (e.g., '-xzf 5')
local function splitShortOptionValues(options)
    local splitOptions = {}

    for _, v in pairs(options) do
        local shortOption, value = v:match("^(%-[A-Za-z]+)(%d*)$")

        if shortOption and value and #value > 0 then
            table.insert(splitOptions, shortOption)
            table.insert(splitOptions, value)
        else
            table.insert(splitOptions, v)
        end
    end

    return splitOptions
end

local function enterOptionKV(self, option, value, kvStore)
    local shortOption = option:match("^%-([A-Za-z]+)$")

    if shortOption then
        for abbrOption in shortOption:gmatch(".") do
            if self.alias[abbrOption] then
                kvStore[self.alias[abbrOption]] = value
            else
                error("Unrecognized option '-" .. abbrOption .. "'", 0)
            end
        end

        return
    end

    kvStore[option:match("^%-%-(.+)$")] = value
end

local function mapOptions(self, options)
    local optionKVs = {}
    local prevOption

    for _, v in pairs(options) do
        local currOption = v:match("^(%-[A-Za-z]+)$") or v:match("^(%-%-.+)$")

        if prevOption then
            enterOptionKV(self, prevOption, currOption ~= nil or v, optionKVs)
        end

        prevOption = currOption
    end

    if prevOption then
        enterOptionKV(self, prevOption, true, optionKVs)
    end

    return optionKVs
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
                            mapOptions(self,
                                    splitShortOptionValues(options)
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

    textutils.pagedTabulate(colors.grey, {"Argument", "Alias", "Description"}, colors.white, table.unpack(rows))
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
