-- ==============================================================================
-- 1. SETUP & MODULES (Using core.log, No PCALL)
-- ==============================================================================
local core_api = core
if not core_api then print("FishermansFriend: FATAL - core_api is nil!") return end

-- Required Core Components
local graphics = core_api.graphics
local object_manager = core_api.object_manager
local menu = core_api.menu
local input = core_api.input -- Needed for use_item, use_object
local spell_book = core_api.spell_book -- Added for spell checks

-- Attempt to load common modules
local color_module, vec3_module, vec2_module
local load_ok_geo = true
local load_ok_color = true



-- Forward declare Settings table for use in direct_require
local Settings = {}
---@return number
local role = core.get_user_role_flags()

-- Attempt to load buff manager and enums for cleanse logic
local buff_manager_api, enums_api
if type(require) == "function" then
    local load_ok_buff_mgr, bm_temp = pcall(require, "common/modules/buff_manager")
    if load_ok_buff_mgr and type(bm_temp) == "table" then
        buff_manager_api = bm_temp
       -- if core_api.log then core_api.log("FishermansFriend: OK Loaded 'common/modules/buff_manager'.") end
    else
      --  if core_api.log_error then core_api.log_error("FishermansFriend: FAILED to load 'common/modules/buff_manager'. Error: " .. tostring(bm_temp)) end
    end

    local load_ok_enums, enums_temp = pcall(require, "common/enums")
    if load_ok_enums and type(enums_temp) == "table" then
        enums_api = enums_temp
       -- if core_api.log then core_api.log("FishermansFriend: OK Loaded 'common/enums'.") end
    else
       --  if core_api.log_error then core_api.log_error("FishermansFriend: FAILED to load 'common/enums'. Error: " .. tostring(enums_temp)) end
    end
else
    -- if core_api.log_error then core_api.log_error("FishermansFriend: Cannot load buff_manager/enums - 'require' function not available.") end
end
-- *** END OF ADDED BLOCK ***
if type(require) == "function" then
    local function direct_require(module_name, module_path)
     --   if core_api.log then core_api.log("FishermansFriend: Loading '".. module_path .."'...") end
        local status, result = pcall(require, module_path)
        if not status then
             if core_api.log_error then core_api.log_error("FishermansFriend: FAILED to load module '" .. module_path .. "'. Error: " .. tostring(result)) else print("FishermansFriend: FAILED to load module '" .. module_path .. "'. Error: " .. tostring(result)) end
             return nil, false
        end

        local required_funcs_ok = true
        if module_name == "Color" then
            if type(result) ~= "table" or type(result.new) ~= "function" or type(result.get_rainbow_color) ~= "function" or type(result.get) ~= "function" or type(result.red) ~= "function" then
               --  if core_api.log_warning then core_api.log_warning("FishermansFriend: Module '" .. module_path .. "' loaded but is missing required Color functions/structure.") end
                 required_funcs_ok = false
            end
        elseif (module_name == "Vec3" or module_name == "Vec2") then
             if type(result) ~= "table" then
                -- if core_api.log_warning then core_api.log_warning("FishermansFriend: Module '" .. module_path .. "' did not return a table. Type: "..type(result)) end
                 required_funcs_ok = false
            elseif type(result.new) ~= "function" then
              --   if core_api.log_warning then core_api.log_warning("FishermansFriend: "..module_name.." module loaded but missing .new function.") end
                 required_funcs_ok = false
            end
        elseif type(result) ~= "table" and module_name ~= "Color" then
           --  if core_api.log_warning then core_api.log_warning("FishermansFriend: Module '" .. module_path .. "' loaded but did not return a table (Type: "..type(result)..").") end
            required_funcs_ok = false
        end

        if required_funcs_ok then
          --   if core_api.log then core_api.log("FishermansFriend: OK Loaded '".. module_path .."'.") end
             return result, true
        else
             if core_api.log_error then core_api.log_error("FishermansFriend: Module '" .. module_path .. "' failed validation.") else print("FishermansFriend: Module '" .. module_path .. "' failed validation.") end
             return nil, false
        end
    end
    color_module, load_ok_color = direct_require("Color", "common/color")
    vec3_module, load_ok_geo = direct_require("Vec3", "common/geometry/vector_3")
    local vec2_temp
    vec2_temp, load_ok_geo = direct_require("Vec2", "common/geometry/vector_2")
    if load_ok_geo then vec2_module = vec2_temp end
else
     if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - 'require' function not available.") else print("FishermansFriend: FATAL - 'require' function not available.") end
     return
end

-- Check essential API components
if not graphics or not object_manager or not menu or not input or not spell_book then
    if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Missing core API components (graphics, object_manager, menu, input, or spell_book).") else print("FishermansFriend: FATAL - Missing core API components") end
    return
end
if not core_api.get_ping or not core_api.time then
     if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Missing core functions (get_ping, time).") else print("FishermansFriend: FATAL - Missing core ping/time") end
     return
end
if not input.use_item or not input.use_object or not input.cast_target_spell then
    if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Missing required core.input functions (use_item, use_object, cast_target_spell).") else print("FishermansFriend: FATAL - Missing core.input functions") end
    return
end
if not spell_book.is_spell_learned or not spell_book.is_usable_spell then
    if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Missing required core.spell_book functions (is_spell_learned, is_usable_spell).") else print("FishermansFriend: FATAL - Missing core.spell_book functions") end
    return
end

-- Check if essential modules loaded successfully
if not load_ok_geo or not vec3_module or not vec2_module then
     if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Cannot run without Vec3 and/or Vec2 modules.") else print("FishermansFriend: FATAL - Cannot run without Vec3/Vec2") end
     if not load_ok_geo then
         vec3_module = nil
         vec2_module = nil
     end
     Vec3 = vec3_module
     Vec2 = vec2_module
     return
end
if not load_ok_color or not color_module then
     if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Color module ('color.lua') failed load or invalid.") else print("FishermansFriend: FATAL - Color module failed load") end
     return
end

-- Use loaded modules
local color = color_module
local Vec3 = vec3_module
local Vec2 = vec2_module

-- Final check for Vec3 constructor after assignment
if not Vec3 or type(Vec3.new) ~= 'function' then
     if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Vec3 module loaded but Vec3.new is not available!") else print("FishermansFriend: FATAL - Vec3.new not available!") end
     return
end

-- Log status after loading
if core_api.log then
  --  core_api.log("--- FishermansFriend Post-Load Check ---")
  --  core_api.log("Input type: " .. type(input))
  --  core_api.log("SpellBook type: " .. type(spell_book))
  --  core_api.log("Vec3 type (variable): " .. type(Vec3))
  --  core_api.log("----------------------------------------")
end


-- ==============================================================================
-- 2. CONFIGURATION & SETTINGS
-- ==============================================================================
local const_line_thickness = 3.0
local const_ghoulfish_curse_id = 456216 -- <<< VERIFY ID
local const_cursed_ghoulfish_item_id = 220152 -- <<< VERIFY ID
local const_cleanse_cooldown = 2000 -- Check cleanse eligibility every 2 seconds
local const_auto_cast_cooldown = 1500 -- Cooldown in ms after attempting an auto-cast
local const_bobber_max_range = 30.0 -- Max range in yards to check for bobbers
local const_bobber_max_range_sq = const_bobber_max_range * const_bobber_max_range -- Squared for efficiency
local const_FISHING_CHANNEL_SPELL_ID = 131474 -- <<< ** VERIFY THIS IS CORRECT FOR YOUR VERSION **
local const_catch_delay_ms = 0.700 -- Fixed delay between detection and click
-- Add this new state variable for scheduled casting
local next_cast_schedule_time = 0

-- !!! VERIFY THESE FISHING SPELL IDS - ORDER HIGHEST RANK TO LOWEST !!!
local FISHING_SPELL_IDS = {
 131474, 88868, 18248, 51294, 33095, 7620, 7731, 7732,
}

-- Populate Settings table now that modules are loaded
Settings = {
    is_enabled = true,
    max_range = 240.0, -- Max range for drawing pool lines
    default_line_color_base = color.white(),
    use_get_all_objects = false,
    show_pool_names = true,
    pool_name_text_size = 14,
    enable_pool_glow = true,
    enable_cleanse_ghoulfish = true,
    enable_auto_catch = false,
    enable_auto_cast = false,
    latency_display_text_size = 16,
    latency_display_pos = Vec2.new(10, 10),
    show_latency = false,
    verbose_logging = false, -- Enables detailed cleanse info / other messages
    logged_missing_bobber_func = false,
    logged_missing_debuff_func = false,
    logged_missing_usable_func = false
}

-- Define specific base colors
local COLOR_BLOOD_BASE = color.red()
local COLOR_SHARK_BASE = color.blue()

-- State for Glow Tracking
local GlowingPools = {}

-- State for Cleanse Cooldown
local last_cleanse_attempt_time = 0

-- State for auto-cast
local last_auto_cast_attempt_time = 0
local is_looting = false
local loot_check_time = 0
local last_loot_count = 0
local LOOT_CHECK_DELAY = 200 -- ms between loot attempts

-- State variables for the fixed 200ms auto-catch delay
local catch_click_pending = false
local catch_click_trigger_time = 0
local catch_click_bobber_target = nil

-- List of known fishing bobber names
local FISHING_BOBBER_NAMES = {
    ["Fishing Bobber"] = true,  -- Default English
    ["Angelhaken"] = true,      -- German
    ["Appât"] = true,          -- French
    ["Anzuelo de pesca"] = true, -- Spanish
    ["Amo da pesca"] = true,   -- Italian
    ["Блесна"] = true,         -- Russian
    ["낚시찌"] = true,          -- Korean
    ["钓鱼浮漂"] = true,        -- Simplified Chinese
    ["釣魚浮標"] = true         -- Traditional Chinese
}

-- ==============================================================================
-- 3. FISHING POOL AND BOBBER NAMES
-- ==============================================================================
local FISHING_POOL_NAMES = {
    ["Floating Wreckage"] = true, ["School of Tastyfish"] = true, ["School of Deviate Fish"] = true,
    ["Oily Blackmouth School"] = true, ["Firefin Snapper School"] = true, ["School of Sagefish"] = true,
    ["Greater Sagefish School"] = true, ["Stonescale Eel Swarm"] = true, ["School of Spotted Feltail"] = true,
    ["School of Darter"] = true, ["School of Highland Mixed Fish"] = true, ["Steam Pump Flotsam"] = true,
    ["School of Sporefish"] = true, ["Mudfish School"] = true, ["Bluefish School"] = true,
    ["School of Goldenscale Vendorfish"] = true, ["Borean Man O' War School"] = true,
    ["Deep Sea Monsterbelly School"] = true, ["Dragonfin Angelfish School"] = true, ["Fangtooth Herring School"] = true,
    ["Glacial Salmon School"] = true, ["Glassfin Minnow School"] = true, ["Imperial Manta Ray School"] = true,
    ["Moonglow Cuttlefish School"] = true, ["Musselback Sculpin School"] = true, ["Nettlefish School"] = true,
    ["Pygmy Suckerfish School"] = true, ["Highland Guppy School"] = true, ["Mountain Trout School"] = true,
    ["Deepsea Sagefish School"] = true, ["Fathom Eel Swarm"] = true, ["Blackbelly Mudfish School"] = true,
    ["Shipwreck Debris"] = true, ["Pool of Volatile Fire"] = true, ["Reef Octopus Swarm"] = true,
    ["Golden Carp School"] = true, ["Emperor Salmon School"] = true, ["Jade Lungfish School"] = true,
    ["Krasarang Paddlefish School"] = true, ["Redbelly Mandarin School"] = true, ["Giant Mantis Shrimp Swarm"] = true,
    ["Tiger Gourami School"] = true, ["Spinefish School"] = true, ["Abyssal Gulper School"] = true,
    ["Blackwater Whiptail School"] = true, ["Blind Lake Sturgeon School"] = true, ["Fire Ammonite School"] = true,
    ["Fat Sleeper School"] = true, ["Jawless Skulker School"] = true, ["Sea Scorpion Swarm"] = true,
    ["Black Barracuda School"] = true, ["Cursed Queenfish School"] = true, ["Highmountain Salmon School"] = true,
    ["Mossgill Perch School"] = true, ["Runescale Koi School"] = true, ["Stormray School"] = true,
    ["Ancient Vrykul Ring"] = true, ["Oodelfjisk Pool"] = true, ["Leyshimmer Blenny Pool"] = true,
    ["Great Sea Catfish School"] = true, ["Lane Snapper School"] = true, ["Sand Shifter School"] = true,
    ["Slimy Mackerel School"] = true, ["Tiragarde Perch School"] = true, ["Frenzied Fangtooth School"] = true,
    ["Midnight Salmon Pool"] = true, ["Abyssal Focus"] = true, ["Elysian Thade School"] = true,
    ["Lost Sole School"] = true, ["Pocked Bonefish School"] = true, ["Silvergill Pike School"] = true,
    ["Iridescent Amberjack School"] = true, ["Temporal Dragonhead School"] = true, ["Cerulean Spinefish School"] = true,
    ["Aileron Seamoth School"] = true, ["Islefin Dorado School"] = true, ["Prismatic Leaper School"] = true,
    ["Thousandbite Piranha School"] = true, ["Frosted Rimefin Tuna Pool"] = true, ["Magma Thresher Pool"] = true,
    ["Shimmering Treasure Pool"] = true, ["River Mouth Fishing Hole"] = true, ["Glimmerpool"] = true,
    ["Blood in the Water"] = true, ["Bloody Perch Swarm"] = true, ["Calm Surfacing Ripple"] = true,
    ["Festering Rotpool"] = true, ["Swarm of Slum Sharks"] = true, ["Infused Ichor Spill"] = true,
    ["River Bass Pool"] = true, ["Anglerseeker Torrent"] = true, ["Stargazer Swarm"] = true,
    ["Royal Ripple"] = true,
}


-- ==============================================================================
-- 4. MENU ELEMENTS
-- ==============================================================================
local menu_elements = {
    main_tree = menu.tree_node(),
    enable_script = menu.checkbox(Settings.is_enabled, "ff_enable"),
    range_slider = menu.slider_float(10.0, 240.0, Settings.max_range, "ff_range"),
    --use_all_objects_toggle = menu.checkbox(Settings.use_get_all_objects, "ff_use_all"),
    -- Visuals Sub-tree
    visuals_tree = menu.tree_node(),
    show_names_toggle = menu.checkbox(Settings.show_pool_names, "ff_show_names"),
    pool_name_size_slider = menu.slider_int(8, 24, Settings.pool_name_text_size, "ff_pool_name_size"),
    enable_glow_toggle = menu.checkbox(Settings.enable_pool_glow, "ff_enable_glow"),
    -- Utility Sub-tree
    utility_tree = menu.tree_node(),
    cleanse_toggle = menu.checkbox(Settings.enable_cleanse_ghoulfish, "ff_cleanse_ghoulfish"),
    auto_catch_toggle = menu.checkbox(Settings.enable_auto_catch, "ff_auto_catch"),
    auto_cast_toggle = menu.checkbox(Settings.enable_auto_cast, "ff_auto_cast"),
    -- Debug Sub-tree
    debug_tree = menu.tree_node(),
    verbose_log_toggle = menu.checkbox(Settings.verbose_logging, "ff_verbose_log"), -- Enables detailed cleanse info / other messages
    latency_toggle = menu.checkbox(Settings.show_latency, "ff_show_latency")
}

-- ==============================================================================
-- 5. HELPER FUNCTION - Find Closest Bobber Within Range (No Ownership Check, No goto)
-- ==============================================================================
local function find_closest_bobber_in_range(player_pos_vec3) -- Expecting a Vec3 object
    if not player_pos_vec3 or type(player_pos_vec3.squared_dist_to) ~= 'function' then
        if core_api.log and Settings.verbose_logging then 
            core_api.log("DEBUG: Invalid player_pos_vec3 passed to find_closest_bobber_in_range") 
        end
        return nil
    end

    local success, visible_objects = pcall(function()
        return object_manager.get_visible_objects()
    end)
    
    if not success or not visible_objects then 
        if core_api.log and Settings.verbose_logging then
            core_api.log("DEBUG: Failed to get visible objects: " .. tostring(visible_objects))
        end
        return nil 
    end

    local closest_bobber = nil
    local min_dist_sq = -1

    for _, obj in ipairs(visible_objects) do
        -- Use pcall to safely check object validity
        local is_valid, obj_name = pcall(function()
            if not obj or not obj.is_valid or not obj:is_valid() or not obj.get_name then
                return nil
            end
            return obj:get_name()
        end)

        -- Check if we got a valid bobber name
        if is_valid and obj_name and FISHING_BOBBER_NAMES[obj_name] then
            -- Safely get position
            local success_pos, pos = pcall(function()
                return obj.get_position and obj:get_position()
            end)

            if success_pos and pos and pos.x and pos.y and pos.z then
                local bobber_pos_vec3 = Vec3.new(pos.x, pos.y, pos.z)
                if bobber_pos_vec3 and type(bobber_pos_vec3.squared_dist_to) == 'function' then
                    local dist_sq = player_pos_vec3:squared_dist_to(bobber_pos_vec3)
                    if dist_sq <= const_bobber_max_range_sq then
                        -- Found a valid bobber within range, check if it's the closest
                        if min_dist_sq < 0 or dist_sq < min_dist_sq then
                            min_dist_sq = dist_sq
                            closest_bobber = obj
                        end
                    end -- end range check
                end -- end Vec3 valid check
            end -- end position check
        end -- end name check
    end -- end for loop

    return closest_bobber
end
-- ==============================================================================
-- 6. HELPER FUNCTION - Get Best Fishing Spell
-- ==============================================================================
local function get_best_fishing_spell()
    for _, spell_id in ipairs(FISHING_SPELL_IDS) do
        if spell_book.is_spell_learned(spell_id) and spell_book.is_usable_spell(spell_id) then
            return spell_id -- Return the first (highest rank) learned and usable spell
        end
    end
    return nil -- No learned & usable fishing spell found
end


-- ==============================================================================
-- 7. ON UPDATE FUNCTION (Fixed 200ms Catch Delay + Cleanse Debug)
-- ==============================================================================
local function on_update()
     if not Settings.is_enabled then return end
     -- Check Vec3 module availability
     if not object_manager or not core_api.time or not input or not spell_book or not core_api.get_ping or not Vec3 then
         if core_api.log_error and not Settings.logged_missing_vec3_module then
            core_api.log_error("FishermansFriend: Vec3 module not available in on_update!")
            Settings.logged_missing_vec3_module = true -- Log once
         end
         return
     end

     -- Get local player ONCE per update tick for consistency
     local player = object_manager.get_local_player()
     if not player or not player:is_valid() then return end

     -- **Get position TABLE and convert to Vec3 object**
     local player_pos_table = player:get_position()
     if not (player_pos_table and player_pos_table.x and player_pos_table.y and player_pos_table.z) then
         if core_api.log then core_api.log("DEBUG ERROR: player:get_position() returned invalid table in on_update!") end
         return -- Skip this tick if position is invalid table
     end
     local player_pos_vec3 = Vec3.new(player_pos_table.x, player_pos_table.y, player_pos_table.z)
     -- Check if conversion worked
     if not (player_pos_vec3 and type(player_pos_vec3.squared_dist_to) == 'function') then
         if core_api.log then core_api.log("DEBUG ERROR: Failed to create valid player_pos_vec3 object in on_update!") end
         return -- Skip this tick if conversion failed
     end


     local current_time = core.time()
     local is_casting_now = player:is_casting_spell()
     local is_channeling_now = player:is_channelling_spell()
     local is_moving = player:is_moving()

 -- == Cleanse Logic (Using Buff Manager) ==
 if Settings.enable_cleanse_ghoulfish and current_time > last_cleanse_attempt_time + const_cleanse_cooldown then
    if core_api.log and Settings.verbose_logging then core_api.log("DEBUG Cleanse: Checking for Ghoulfish Curse...") end
    last_cleanse_attempt_time = current_time -- Update time even if check fails

    -- Check if buff_manager was loaded successfully
    if not buff_manager_api or type(buff_manager_api.get_debuff_data) ~= 'function' then
        if core_api.log_warning and not Settings.logged_missing_buff_mgr then
             core_api.log_warning("FishermansFriend: Cannot check debuffs - buff_manager module not loaded or invalid.")
             Settings.logged_missing_buff_mgr = true -- Log once per session
        end
    else
        -- Use buff_manager to check for the debuff by ID
        -- NOTE: get_debuff_data expects a TABLE of IDs, even if it's just one ID.
        local debuff_data = buff_manager_api:get_debuff_data(player, {456216})

        -- Check the is_active field from the returned data
        if debuff_data and debuff_data.is_active then
            if core_api.log then core_api.log("DEBUG Cleanse: Ghoulfish Curse FOUND (ID: " .. const_ghoulfish_curse_id .. ")! Using buff_manager. Attempting to use item ID: " .. const_cursed_ghoulfish_item_id) end
            input.use_item(const_cursed_ghoulfish_item_id)
            if core_api.log then core_api.log("DEBUG Cleanse: input.use_item called.") end
        else
             if core_api.log and Settings.verbose_logging then core_api.log("DEBUG Cleanse: Ghoulfish Curse (ID: "..const_ghoulfish_curse_id..") was NOT active according to buff_manager.") end
        end
    end
 end -- End Cleanse Logic

     -- == Find Closest Bobber within 30 yards ==
     local closest_bobber_nearby = nil
     -- Search only if auto-catch or auto-cast might need it
     if Settings.enable_auto_catch or Settings.enable_auto_cast then
         local success, result = pcall(function()
             return find_closest_bobber_in_range(player_pos_vec3)
         end)
         if success then
             closest_bobber_nearby = result
         else
             if core_api.log and Settings.verbose_logging then 
                 core_api.log("ERROR in find_closest_bobber_in_range: " .. tostring(result))
             end
             closest_bobber_nearby = nil
         end
     end

     -- == Auto Catch Logic (Fixed 200ms Delay) ==
     if Settings.enable_auto_catch then
         -- Cancel pending click if the target bobber becomes invalid OR if the closest bobber is no longer the target
         if catch_click_pending then
             -- Safely check if target is still valid
             local target_is_still_valid = false
             if catch_click_bobber_target and type(catch_click_bobber_target.is_valid) == 'function' then
                 local success, result = pcall(function() return catch_click_bobber_target:is_valid() end)
                 target_is_still_valid = success and result
             end
             
             -- Safely compare objects
             local current_closest_is_target = false
             if closest_bobber_nearby and catch_click_bobber_target then
                 current_closest_is_target = (tostring(closest_bobber_nearby) == tostring(catch_click_bobber_target))
             end

             if not target_is_still_valid or not current_closest_is_target then
                 if core_api.log and Settings.verbose_logging then 
                     core_api.log("DEBUG: Cancelling pending catch click. Reason: " .. (not target_is_still_valid and "TargetInvalid " or "") .. (not current_closest_is_target and "TargetMismatch " or "")) 
                 end
                 catch_click_pending = false
                 catch_click_trigger_time = 0
                 catch_click_bobber_target = nil
             end
         end

         -- If we found a bobber nearby AND we are not already waiting to click it
         if closest_bobber_nearby and not catch_click_pending then
             -- Check if the bobber has a fish *every tick*
             local bobber_has_fish = false
             local can_check_fish = type(closest_bobber_nearby.does_bobber_have_fish) == "function"

             if can_check_fish then
                 --[[ -- Commented out detailed bobber debug logs per request
                 if core_api.log and Settings.verbose_logging then core_api.log("DEBUG: Calling does_bobber_have_fish() on object: " .. tostring(closest_bobber_nearby)) end
                 --]]
                 bobber_has_fish = closest_bobber_nearby:does_bobber_have_fish()
                 --[[ -- Commented out detailed bobber debug logs per request
                 if core_api.log and Settings.verbose_logging then core_api.log("DEBUG: does_bobber_have_fish() on closest bobber returned: " .. tostring(bobber_has_fish)) end
                 --]]
             else
                 if core_api.log_warning and not Settings.logged_missing_bobber_func then
                      core_api.log_warning("FishermansFriend: Cannot check bobber state - obj:does_bobber_have_fish() function not found.")
                      Settings.logged_missing_bobber_func = true
                 end
             end

             -- If bobber has fish, schedule the delayed click
             if bobber_has_fish then
                 catch_click_pending = true
                 catch_click_trigger_time = current_time + const_catch_delay_ms -- Use fixed delay
                 catch_click_bobber_target = closest_bobber_nearby -- Store the specific bobber object
                 if core_api.log then core_api.log("DEBUG: Fish hooked on closest bobber! Pending click in " .. const_catch_delay_ms .. "ms.") end
             end
         end

         -- If pending, check timer and execute click
         if catch_click_pending and current_time >= catch_click_trigger_time then
                -- Check if the bobber is still valid before clicking
             if core_api.log then core_api.log("DEBUG: Catch click timer triggered.") end
             local bobber_to_use = catch_click_bobber_target

             -- No player busy check here per user request (click regardless)

             if bobber_to_use and bobber_to_use:is_valid() then
                if core_api.log then core_api.log("DEBUG: Stored bobber is valid. Calling input.use_object...") end
                input.use_object(bobber_to_use) -- Using use_object [cite: 80]
                if core_api.log then core_api.log("DEBUG: input.use_object called.") end

                -- *** ADD THIS BLOCK ***
                -- If auto-cast is enabled, schedule the next cast 0.7 seconds from now
                if Settings.enable_auto_cast then
                    next_cast_schedule_time = current_time + 1 -- Schedule 700ms (0.7s) later [cite: 23]
                    if core_api.log then core_api.log("DEBUG: Bobber used. Scheduling next auto-cast in 700ms.") end
                end
                -- *** END OF ADDED BLOCK ***
             else
                 if core_api.log then core_api.log("DEBUG: Stored bobber was nil or invalid when click timer triggered.") end
             end
            -- Always reset state after timer fires
            catch_click_pending = false
            catch_click_trigger_time = 0
            catch_click_bobber_target = nil
            if core_api.log then core_api.log("DEBUG: Resetting catch click state.") end
        end
    else
          -- Ensure state is reset if auto-catch is disabled
         if catch_click_pending then
             catch_click_pending = false
             catch_click_trigger_time = 0
             catch_click_bobber_target = nil
         end
     end -- End Auto Catch Logic block

    -- == Loot Window Handling ==
    if Settings.enable_auto_cast and core.game_ui and core.game_ui.get_loot_item_count then
        local loot_count = core.game_ui.get_loot_item_count()
        
        if loot_count > 0 then
            -- If we just detected loot, note the time and start looting
            if not is_looting then
                is_looting = true
                last_loot_count = loot_count
                loot_check_time = current_time - LOOT_CHECK_DELAY  -- Force immediate action on first check
                if core_api.log then core_api.log("DEBUG: Loot window detected with " .. loot_count .. " items") end
            end
            
            -- Check if we should try looting again (with delay between attempts)
            if current_time >= loot_check_time + LOOT_CHECK_DELAY then
                -- Always try to loot the first item (index 0)
                if core.input and core.input.loot_item then
                    core.input.loot_item(0)
                    if core_api.log then core_api.log("DEBUG: Attempting to loot item (remaining: " .. loot_count .. ")") end
                end
                
                -- Update the last loot check time
                loot_check_time = current_time
                
                -- If we've been trying to loot the same number of items for too long, give up
                if last_loot_count == loot_count then
                    if current_time - loot_check_time > 2000 then  -- 2 seconds of no progress
                        if core.input and core.input.close_loot then
                            core.input.close_loot()
                        end
                        is_looting = false
                        if core_api.log then core_api.log("WARNING: Giving up on looting after no progress") end
                    end
                else
                    last_loot_count = loot_count
                end
            end
            
            -- Don't proceed to casting while looting
            return
        else
            -- If we were looting but now there's no loot, we're done
            if is_looting then
                if core.input and core.input.close_loot then
                    core.input.close_loot()
                end
                is_looting = false
                if core_api.log then core_api.log("DEBUG: Looting complete, no more items") end
            end
        end
    end
    
    -- == Auto Cast Logic (Handles Scheduled & Idle Recasts) ==
    if Settings.enable_auto_cast then
        local should_try_cast = false
        local reason = ""

        -- Check if a scheduled cast is due
        if next_cast_schedule_time > 0 and current_time >= next_cast_schedule_time then
            should_try_cast = true
            reason = "Scheduled cast time met."
            next_cast_schedule_time = 0 -- Consume the schedule
        -- Else, check if regular idle cast is due (and no schedule is pending)
        elseif next_cast_schedule_time == 0 and current_time > last_auto_cast_attempt_time + const_auto_cast_cooldown then
            should_try_cast = true
            reason = "Idle cast cooldown met."
        end

        -- If we should try casting, check if player is ready
        if should_try_cast and not is_looting then
            if not is_casting_now and not is_channeling_now and not is_moving then
                local spell_id_to_cast = get_best_fishing_spell()
                if spell_id_to_cast then
                    if core_api.log then core_api.log("DEBUG: Player ready. " .. reason .. " Attempting auto-cast of spell ID: " .. spell_id_to_cast) end
                    input.cast_target_spell(spell_id_to_cast, player)
                    last_auto_cast_attempt_time = current_time
                else
                    if core_api.log and Settings.verbose_logging then 
                        core_api.log("DEBUG: " .. reason .. " No usable fishing spell found to auto-cast.") 
                    end
                    last_auto_cast_attempt_time = current_time
                end
            -- Added check: If a cast was scheduled but player was busy when the time came, clear the schedule anyway
            elseif next_cast_schedule_time > 0 and current_time >= next_cast_schedule_time then
                if core_api.log then 
                    core_api.log("DEBUG: Scheduled cast time met, but couldn't cast (player busy?). Clearing schedule.") 
                end
                next_cast_schedule_time = 0 -- Clear schedule if missed
            end
        end
    else
        -- Ensure schedule is cleared if auto cast gets disabled
        next_cast_schedule_time = 0
        is_looting = false
    end -- End Auto Cast Logic block

end


-- ==============================================================================
-- 8. ON RENDER FUNCTION (Drawing Logic - Use Vec3.new)
-- ==============================================================================
local function on_render()
    -- Update settings from menu
    if menu_elements then
        Settings.is_enabled = menu_elements.enable_script:get_state()
        Settings.max_range = menu_elements.range_slider:get() -- This is for pool drawing range
      --  Settings.use_get_all_objects = menu_elements.use_all_objects_toggle:get_state()
        Settings.show_pool_names = menu_elements.show_names_toggle:get_state()
        Settings.pool_name_text_size = menu_elements.pool_name_size_slider:get()
        Settings.enable_pool_glow = menu_elements.enable_glow_toggle:get_state()
        Settings.enable_cleanse_ghoulfish = menu_elements.cleanse_toggle:get_state()
        Settings.enable_auto_catch = menu_elements.auto_catch_toggle:get_state()
        Settings.enable_auto_cast = menu_elements.auto_cast_toggle:get_state()
        Settings.verbose_logging = menu_elements.verbose_log_toggle:get_state()
        Settings.show_latency = menu_elements.latency_toggle:get_state()
    end

    if not Settings.is_enabled then
         for key, pool_obj in pairs(GlowingPools) do
             if pool_obj and pool_obj:is_valid() and pool_obj.set_glow then
                 pool_obj:set_glow(false)
             end
         end
         GlowingPools = {}
         return
    end

    -- Check essential components
    if not graphics or not object_manager or not Vec3 or not Vec2 or not color or not color.new or not color.get_rainbow_color or not core_api.time then return end

    local player = object_manager.get_local_player()
    if not player or not player:is_valid() then return end

    -- Get player pos table and convert to Vec3
    local player_pos_table = player:get_position()
    if not (player_pos_table and player_pos_table.x) then return end -- Basic check
    local player_pos_vec3 = Vec3.new(player_pos_table.x, player_pos_table.y, player_pos_table.z)
    if not (player_pos_vec3 and type(player_pos_vec3.dist_to) == 'function') then return end -- Ensure valid Vec3 for drawing

    -- == Update Glow States & Draw Pools ==
    local pools_found_this_frame = {}
    local max_draw_range = Settings.max_range -- Use setting for drawing pools
    local objects_to_check = nil

    if Settings.use_get_all_objects then
        objects_to_check = object_manager.get_all_objects()
    else
        objects_to_check = object_manager.get_visible_objects()
    end

    if objects_to_check then
        for _, obj in ipairs(objects_to_check) do
            -- Only process drawing for fishing pools here
            if obj and obj:is_valid() and obj.get_name and obj.get_position then
                local obj_key = tostring(obj)
                local obj_name = obj:get_name()
                if obj_name and FISHING_POOL_NAMES[obj_name] then
                    local obj_pos_table = obj:get_position()
                    -- Convert obj_pos to Vec3
                    if obj_pos_table and obj_pos_table.x then
                         local obj_pos_vec3 = Vec3.new(obj_pos_table.x, obj_pos_table.y, obj_pos_table.z)
                         if obj_pos_vec3 and type(obj_pos_vec3.dist_to) == 'function' then -- Check conversion worked & has method
                             -- Use the max_draw_range from settings for visibility/drawing
                             if player_pos_vec3:dist_to(obj_pos_vec3) <= max_draw_range then
                                 pools_found_this_frame[obj_key] = true

                                -- Set Glow state
                                if Settings.enable_pool_glow and not GlowingPools[obj_key] then
                                     if obj.set_glow then
                                         obj:set_glow(true)
                                         GlowingPools[obj_key] = obj
                                     end
                                end

                                -- Color Logic
                                local final_line_color
                                if obj_name == "Blood in the Water" then
                                    final_line_color = color.get_rainbow_color(100)
                                    if not final_line_color then final_line_color = COLOR_BLOOD_BASE end
                                elseif obj_name == "Swarm of Slum Sharks" then
                                    final_line_color = COLOR_SHARK_BASE
                                else
                                    final_line_color = Settings.default_line_color_base
                                end

                                -- Draw Line & Name (using Vec3 objects)
                                if final_line_color then
                                    graphics.line_3d(player_pos_vec3, obj_pos_vec3, final_line_color, const_line_thickness, 2.5, true)
                                    if Settings.show_pool_names then
                                        -- Create Vec3 for text position using table data directly is fine here
                                        local text_pos = Vec3.new(obj_pos_table.x, obj_pos_table.y, obj_pos_table.z + 0.75)
                                        graphics.text_3d(obj_name, text_pos, Settings.pool_name_text_size, final_line_color, true)
                                    end
                                end
                            end
                        end
                    end
                end
            end -- End obj checks
        end -- End object loop
    end -- End if objects_to_check

    -- Turn off glow for pools
    local remaining_glowing = {}
    for key, pool_obj in pairs(GlowingPools) do
        local should_glow_now = pools_found_this_frame[key] and Settings.enable_pool_glow
        if pool_obj and pool_obj:is_valid() then
            if should_glow_now then
                 remaining_glowing[key] = pool_obj
            else
                if pool_obj.set_glow then
                    pool_obj:set_glow(false)
                end
            end
        end
    end
    GlowingPools = remaining_glowing

    -- == Draw Latency ==
    if Settings.show_latency then
         local ping = core_api.get_ping()
         local ping_text = string.format("Ping: %d ms", ping or 0)
         graphics.text_2d(ping_text, Settings.latency_display_pos, Settings.latency_display_text_size, Settings.default_line_color_base, true)
    end
end


-- ==============================================================================
-- 9. MENU RENDER FUNCTION
-- ==============================================================================
local function menu_render()
    if not menu_elements or not menu_elements.main_tree then return end
    menu_elements.main_tree:render("Fisherman's Friend", function()
        menu_elements.enable_script:render("Enable Fisherman's Friend")
        menu_elements.range_slider:render("Max Draw Range (Pools)", Settings.max_range) -- Clarified tooltip
      --  menu_elements.use_all_objects_toggle:render("Use 'Get All Objects' (SLOW?)", "Check this to use get_all_objects instead of get_visible_objects.")

        menu_elements.visuals_tree:render("Visuals", function()
            menu_elements.show_names_toggle:render("Show Pool Names")
            menu_elements.pool_name_size_slider:render("Pool Name Size", Settings.pool_name_text_size)
            menu_elements.enable_glow_toggle:render("Enable Persistent Pool Glow")
            if graphics and graphics.text then graphics.text("Line Thickness: " .. string.format("%.1f", const_line_thickness), 10, (menu_elements.enable_glow_toggle.y or 10) + 20) end
        end)

        menu_elements.utility_tree:render("Utility", function()
             menu_elements.cleanse_toggle:render("Auto Cleanse Ghoulfish Curse", "Uses Cursed Ghoulfish item if debuff is active.")
             -- Updated tooltip to reflect action used and delay
             menu_elements.auto_catch_toggle:render("Enable Auto Catch Fish (Delayed)", "Uses closest bobber within "..const_bobber_max_range.."yd & does_bobber_have_fish(), then use_object() after "..const_catch_delay_ms.."ms delay.")
             menu_elements.auto_cast_toggle:render("Enable Auto Cast Fishing", "Automatically casts highest learned fishing spell when idle and no bobber nearby.")
        end)

         menu_elements.debug_tree:render("Debugging", function()
            menu_elements.verbose_log_toggle:render("Enable Verbose Logging", "Logs detailed cleanse info / other messages.") -- Tooltip updated
            menu_elements.latency_toggle:render("Show Latency (Ping)", "Display current ping in top-left corner.")
        end)

        if graphics and graphics.text and color then
            local last_element_y = menu_elements.debug_tree.y or menu_elements.utility_tree.y or 100
            local text_y_start = last_element_y + 40
             graphics.text("Fixed Rainbow lines = Blood in the Water", 10, text_y_start, 16, COLOR_BLOOD_BASE or Settings.default_line_color_base)
             graphics.text("Blue lines = Swarm of Slum Sharks", 10, text_y_start + 15, 16, COLOR_SHARK_BASE or Settings.default_line_color_base)
        end
    end)
end

-- ==============================================================================
-- 10. REGISTER CALLBACKS
-- ==============================================================================
if core_api.register_on_render_callback and core_api.register_on_render_menu_callback and core_api.register_on_update_callback then
    core_api.register_on_render_callback(on_render)
    core_api.register_on_render_menu_callback(menu_render)
    core_api.register_on_update_callback(on_update)

  --  if core_api.log then core_api.log("Fishermans Friend v4.27 (Fixed Catch Delay + Cleanse Debug) Loaded Successfully!") end -- Version updated
   -- if core_api.log_warning then core_api.log_warning("FishermansFriend: Bobber identified by Name 'Fishing Bobber' and proximity.") end
   -- if core_api.log_warning then core_api.log_warning("FishermansFriend: Now using input.use_object() with fixed delay for catching.") end
  --  if core_api.log_warning then core_api.log_warning("FishermansFriend: Verify Fishing Spell IDs in FISHING_SPELL_IDS table!") end
   -- if core_api.log_warning then core_api.log_warning("FishermansFriend: Verify Ghoulfish IDs. No pcalls used.") end
else
    print("FishermansFriend: ERROR - Failed to register core callbacks (render, menu, or update).")
end