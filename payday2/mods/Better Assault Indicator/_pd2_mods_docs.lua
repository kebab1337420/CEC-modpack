---@meta

--------------------
--- SuperBLT DLL ---
--------------------
---@class blt
_G.blt = {}
_G.blt.vm = {}
_G.blt.vm.dofile = dofile
_G.blt.vm.loadfile = loadfile

----------------
--- SuperBLT ---
----------------

---@class json
_G.json = {}
---Converts a Lua table to a JSON string
---@param data table @Data to encode
---@return string @Encoded data
function json.encode(data)
end

---Converts a JSON string to a Lua table
---@param data string @String to decode
---@return table @Decoded data
function json.decode(data)
end

---@class BLTMod
_G.ModInstance = {}

---@class BLT
---@field Mods BLTModManager
_G.BLT = {}

---@class BLTModManager
---@field Mods fun(self: self): BLTMod[]

---@class BLTMod
---@field GetAuthor fun(self: self): string
---@field GetName fun(self: self): string
---@field GetVersion fun(self: self): string
---@field IsEnabled fun(self: self): boolean
---@field SetEnabled fun(self: self, enable: boolean, force: boolean?)

---@class DelayedCalls
---@field Add fun(self: self, id: string, time: number, func: function)
---@field Remove fun(self: self, id: string)
_G.DelayedCalls = {}

---@class Hooks
---@field _function_hooks table
---@field Add fun(self: self, key: string, id: string, func: function)
---@field RemovePreHook fun(self: self, id: string)
---@field RemovePostHook fun(self: self, id: string)
_G.Hooks = {}

---@generic T
---@param object T
---@param func string
---@param id string
---@param post_call fun(self: T, ...)
function Hooks:PostHook(object, func, id, post_call)
end

---@generic T
---@param object T
---@param func string
---@param id string
---@param pre_call fun(self: T, ...)
function Hooks:PreHook(object, func, id, pre_call)
end

---Removes a hooked function call with the specified id to prevent it from being called
---@param id string @Name of the function call to remove
function Hooks:Remove(id)
end

---@class NetworkHelper
_G.NetworkHelper = {}

---`Function in SuperBLT`  
---Sends networked data with a message id to all connected players except specific ones
---@param peer_id integer|integer[] @Peer ID or table of peer IDs of the player(s) to exclude
---@param id string @Unique name of the data to send
---@param data string @Data to send
function NetworkHelper:SendToPeersExcept(peer_id, id, data)
end

---`Function in SuperBLT`  
---Registers a function to be called when network data with a specific message id is received
---@param message_id string @The message id to hook to
---@param hook_id string @A unique name for this hook
---@param func fun(data: string, sender: integer) @Function to be called when network data for that specific message id is received
function NetworkHelper:AddReceiveHook(message_id, hook_id, func)
end

---`Function in SuperBLT`  
---Removes a receive hook
---@param hook_id string @The unique name of the hook to remove
---@param message_id? string @The message id to remove the hook from, if not specified removes all matching hooks
function NetworkHelper:RemoveReceiveHook(hook_id, message_id)
end

---`Function in SuperBLT`  
---Converts a string representation of a color to a color
---@param str string
---@return Color?
function NetworkHelper:StringToColour(str)
end

---`Function in SuperBLT`  
---Rounds a number to the specified precision (decimal places)
---@param num number @The number to round
---@param idp integer? @The number of decimal places to round to (defaults to `0`)
---@return number @The input number rounded to the input precision
function math.round_with_precision(num, idp)
end

---`Function in SuperBLT`  
---Loads a file containing JSON data and converts it into a Lua table
---@param path string @The path (relative to payday2_win32_release.exe) and file name to load the data from
---@return table? @The table containing the data, or `nil` if loading wasn't successful
function io.load_as_json(path)
end

-----------------------
--- End of SuperBLT ---
-----------------------