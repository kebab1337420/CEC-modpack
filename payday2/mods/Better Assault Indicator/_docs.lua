---@meta
--[[
    This file is not loaded, it is here to provide code completion in VSCode
]]

---@type Color
_G.Color = {}
---@type boolean
_G.IS_VR = ...

---@class Color
---@field r number
---@field g number
---@field b number
---@field white self
---@field black self
---@field red self

---@class mathlib
---@field lerp fun(a: number, b: number, lerp: number): number Linearly interpolates between `a` and `b` by `lerp`
---@field round fun(n: number, precision: number?): number Rounds number with precision
---@field clamp fun(number: number, min: number, max: number): number Returns `number` clamped to the inclusive range of `min` and `max`

_G.CoreMenuNode = {}
---@class CoreMenuNode.MenuNode
---@field new fun(self: self, data_node: table?): self
---@field set_callback_handler fun(self: self, callback_handler: MenuCallbackHandler)
_G.CoreMenuNode.MenuNode = {}

---@class CoreMenuItem.Item
---@field dirty fun(self: self)
---@field name fun(self: self): string
---@field set_enabled fun(self: self, enabled: boolean)
---@field set_parameter fun(self: self, name: any, value: any)
---@field parameters fun(self: self): table
---@field type fun(self: self): string

---@class CoreMenuItemOption.ItemOption
---@field parameters fun(self: self): table
---@field value fun(self: self): any

---@class MenuItemDivider : CoreMenuItem.Item

---@class CoreMenuItemToggle.ItemToggle : CoreMenuItem.Item
---@field value fun(self: self): "on"|"off"

---@class CoreMenuItemSlider.ItemSlider : CoreMenuItem.Item
---@field set_decimal_count fun(self: self, decimal_count: number)
---@field raw_value_string fun(self: self): string
---@field value fun(self: self): number
---@field value_string fun(self: self): string

---@class MenuItemMultiChoice : CoreMenuItem.Item
---@field _all_options CoreMenuItemOption.ItemOption[]
---@field value fun(self: self): integer
---@field set_value fun(self: self, value: integer)

---@class MenuItemCustomizeController : CoreMenuItem.Item

---@class MenuItemInput : CoreMenuItem.Item