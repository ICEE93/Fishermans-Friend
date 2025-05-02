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

-- Attempt to load common modules
local color_module, vec3_module, vec2_module
local load_ok_geo = true
local load_ok_color = true

if type(require) == "function" then
    local function direct_require(module_name, module_path)
        if core_api.log and Settings and Settings.verbose_logging then core_api.log("FishermansFriend: Loading '".. module_path .."'...") end
        local result = require(module_path)
        local required_funcs_ok = true
        if module_name == "Color" then
            if type(result) ~= "table" or type(result.new) ~= "function" or type(result.get_rainbow_color) ~= "function" or type(result.get) ~= "function" or type(result.red) ~= "function" then
                 if core_api.log_warning then core_api.log_warning("FishermansFriend: Module '" .. module_path .. "' loaded but is missing required functions.") end
                 required_funcs_ok = false
            end
        elseif (module_name == "Vec3" or module_name == "Vec2") and type(result) ~= "table" then
             if core_api.log_warning then core_api.log_warning("FishermansFriend: Module '" .. module_path .. "' did not return a table.") end
             required_funcs_ok = false
        elseif type(result) ~= "table" and module_name ~= "Color" then
             if core_api.log_warning then core_api.log_warning("FishermansFriend: Module '" .. module_path .. "' loaded but did not return a table (Type: "..type(result)..").") end
            required_funcs_ok = false
        end

        if required_funcs_ok then
             if core_api.log and Settings and Settings.verbose_logging then core_api.log("FishermansFriend: OK Loaded '".. module_path .."'.") end
             return result, true
        else
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
if not graphics or not object_manager or not menu or not input then
    if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Missing core API components.") else print("FishermansFriend: FATAL - Missing core API components") end
    return
end
if not core_api.get_ping or not core_api.time then
     if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Missing core functions (get_ping, time).") else print("FishermansFriend: FATAL - Missing core ping/time") end
     return
end
if not input.use_item or not input.use_object then
    if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Missing required core.input functions (use_item, use_object).") else print("FishermansFriend: FATAL - Missing core.input functions") end
    return
end


-- Check if essential modules loaded successfully
if not load_ok_geo or not vec3_module or not vec2_module then
     if core_api.log_error then core_api.log_error("FishermansFriend: FATAL - Cannot run without Vec3 and/or Vec2 modules.") else print("FishermansFriend: FATAL - Cannot run without Vec3/Vec2") end
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

-- Log status after loading
if core_api.log then
    core_api.log("--- FishermansFriend Post-Load Check ---")
    core_api.log("Input type: " .. type(input)) -- Log input type
    -- (Other logs omitted)
    core_api.log("----------------------------------------")
end


-- ==============================================================================
-- 2. CONFIGURATION & SETTINGS
-- ==============================================================================
local const_line_thickness = 3.0
local const_ghoulfish_curse_id = 456216 -- <<< VERIFY ID
local const_cursed_ghoulfish_item_id = 220152 -- <<< VERIFY ID
local const_cleanse_cooldown = 2000
local const_FISHING_SPELL_ID = 131474 -- <<< VERIFY THIS SPELL ID!

local Settings = {
    is_enabled = true,
    max_range = 240.0,
    default_line_color_base = color.white(),
    use_get_all_objects = false,
    show_pool_names = true,
    pool_name_text_size = 14,
    enable_pool_glow = true,
    enable_cleanse_ghoulfish = true,
    enable_auto_catch = false, -- <<< Default OFF
    latency_display_text_size = 16,
    latency_display_pos = Vec2.new(10, 10),
    show_latency = false,
    verbose_logging = false
}

-- Define specific base colors
local COLOR_BLOOD_BASE = color.red()
local COLOR_SHARK_BASE = color.blue()

-- State for Glow Tracking
local GlowingPools = {}

-- State for Cleanse Cooldown
local last_cleanse_attempt_time = 0

-- State for auto-catch
local auto_catch_pending = false
local auto_catch_trigger_time = 0
local auto_catch_bobber_target = nil

-- ==============================================================================
-- 3. FISHING POOL NAMES (!!! USER SHOULD ADD MORE EXACT NAMES !!!)
-- ==============================================================================
-- (List remains the same - truncated)
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
    use_all_objects_toggle = menu.checkbox(Settings.use_get_all_objects, "ff_use_all"),
    -- Visuals Sub-tree
    visuals_tree = menu.tree_node(),
    show_names_toggle = menu.checkbox(Settings.show_pool_names, "ff_show_names"),
    pool_name_size_slider = menu.slider_int(8, 24, Settings.pool_name_text_size, "ff_pool_name_size"),
    enable_glow_toggle = menu.checkbox(Settings.enable_pool_glow, "ff_enable_glow"),
    -- Utility Sub-tree
    utility_tree = menu.tree_node(),
    cleanse_toggle = menu.checkbox(Settings.enable_cleanse_ghoulfish, "ff_cleanse_ghoulfish"),
    auto_catch_toggle = menu.checkbox(Settings.enable_auto_catch, "ff_auto_catch"), -- Needs tooltip update maybe
    -- Debug Sub-tree
    debug_tree = menu.tree_node(),
    verbose_log_toggle = menu.checkbox(Settings.verbose_logging, "ff_verbose_log"),
    latency_toggle = menu.checkbox(Settings.show_latency, "ff_show_latency")
}

-- ==============================================================================
-- 5. HELPER FUNCTION - Find Closest Fishing Bobber (UNRELIABLE METHOD)
-- ==============================================================================
local function FindClosestBobber(player, player_pos)
    -- WARNING: Uses proximity - may target wrong bobber if players are close!
    if not player or not player_pos or not object_manager.get_visible_objects or not Vec3 then
        if core_api.log_warning then core_api.log_warning("FindClosestBobber: Missing required components.") end
        return nil
    end

    local visible_objects = object_manager.get_visible_objects()
    if not visible_objects then return nil end

    local closest_bobber = nil
    local min_dist_sq = -1

    for _, obj in ipairs(visible_objects) do
        if obj and obj:is_valid() and obj.get_name and obj.get_position then
            local name = obj:get_name()
            -- !!! VERIFY THIS NAME !!!
            if name == "Fishing Bobber" then
                local bobber_pos = obj:get_position()
                if bobber_pos then
                    local dist_sq = -1
                    if player_pos.dist_sq_to then dist_sq = player_pos:dist_sq_to(bobber_pos)
                    elseif player_pos.dist_to then local d = player_pos:dist_to(bobber_pos); dist_sq = d*d end

                    if dist_sq >= 0 and (min_dist_sq < 0 or dist_sq < min_dist_sq) then
                        min_dist_sq = dist_sq
                        closest_bobber = obj
                    end
                end
            end
        end
    end

    if closest_bobber and core_api.log and Settings.verbose_logging then
         core_api.log("FishermansFriend: Found closest bobber (DistSq: " .. string.format("%.2f", min_dist_sq) .. ")")
    elseif not closest_bobber and core_api.log and Settings.verbose_logging then
         core_api.log("FishermansFriend: No visible 'Fishing Bobber' object found.")
    end
    return closest_bobber
end


-- ==============================================================================
-- 6. LOOT PROCESSING FUNCTION (REMOVED)
-- ==============================================================================
-- Removed

-- ==============================================================================
-- 7. ON UPDATE FUNCTION (Cleanse Logic + Auto Catch)
-- ==============================================================================
local function on_update()
     if not Settings.is_enabled then return end
     if not object_manager or not core_api.time or not input then return end

     local player = object_manager.get_local_player()
     if not player or not player:is_valid() then return end

     local current_time = core.time()

     -- Cleanse Logic
     if Settings.enable_cleanse_ghoulfish and current_time > last_cleanse_attempt_time + const_cleanse_cooldown then
        if player.get_debuffs then
            local debuffs = player:get_debuffs()
            if debuffs then
                 for _, debuff in ipairs(debuffs) do
                     if debuff and debuff.id and debuff.id == const_ghoulfish_curse_id then
                         if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Ghoulfish Curse detected! Attempting cleanse...") end
                         input.use_item(const_cursed_ghoulfish_item_id)
                         last_cleanse_attempt_time = current_time
                         break
                     end
                 end
            end
        else
             if core_api.log_warning and Settings.verbose_logging then core_api.log_warning("FishermansFriend: player:get_debuffs() function not found.") end
        end
     end

     -- == Auto Catch Logic ==
     local is_casting_now = player:is_casting_spell()
     local current_cast_id = player:get_active_spell_id()
     local is_fishing_now = is_casting_now and (current_cast_id == const_FISHING_SPELL_ID)
     local is_moving = player:is_moving()

     if Settings.enable_auto_catch then
          -- Cancel pending catch if player moved or started another cast
          if auto_catch_pending and (is_moving or (is_casting_now and not is_fishing_now)) then
                if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Cancelling pending auto-catch due to movement/cast.") end
                auto_catch_pending = false
                auto_catch_trigger_time = 0
                auto_catch_bobber_target = nil
          end

          -- If not pending and not currently fishing and not moving
          if not auto_catch_pending and not is_fishing_now and not is_moving then
                -- Find the closest bobber first
                local player_pos_now = player:get_position()
                local current_bobber = FindClosestBobber(player, player_pos_now)

                if current_bobber then
                    -- Now check the state ON THE BOBBER OBJECT
                    local bobber_has_fish = false
                    -- !!! Check if the bobber object *actually has* this function before calling !!!
                    if type(current_bobber.does_bobber_have_fish) == "function" then
                         bobber_has_fish = current_bobber:does_bobber_have_fish() -- Call based on user info
                         if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Bobber object state check returned: " .. tostring(bobber_has_fish)) end
                    else
                        -- Log only once if function confirmed missing
                         if core_api.log_warning and not Settings.logged_missing_bobber_func then
                              core_api.log_warning("FishermansFriend: Cannot check bobber state - bobber_obj:does_bobber_have_fish() function not found/verified.")
                              Settings.logged_missing_bobber_func = true
                         end
                    end

                    if bobber_has_fish then
                        auto_catch_pending = true
                        local delay_ms = math.random(200, 1300)
                        auto_catch_trigger_time = core.time() + delay_ms
                        auto_catch_bobber_target = current_bobber -- Store the bobber we found
                        if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Fish hooked on closest bobber! Pending auto-catch in " .. delay_ms .. "ms.") end
                    end
                -- else: FindClosestBobber already logged if verbose and no bobber found
                end
          end

          -- If pending, check timer
          if auto_catch_pending and core.time() >= auto_catch_trigger_time then
                if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Auto-catch timer triggered.") end
                local bobber_to_use = auto_catch_bobber_target

                if bobber_to_use and bobber_to_use:is_valid() then
                    if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Attempting to use bobber object.") end
                    input.use_object(bobber_to_use) -- Use the bobber
                else
                    if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Stored bobber for auto-catch is nil or no longer valid.") end
                end

                -- Reset state after attempt
                auto_catch_pending = false
                auto_catch_trigger_time = 0
                auto_catch_bobber_target = nil
          end
     else
          -- Ensure state is reset if auto-catch is disabled
          if auto_catch_pending then
               auto_catch_pending = false
               auto_catch_trigger_time = 0
               auto_catch_bobber_target = nil
          end
     end -- End Auto Catch Logic block
end


-- ==============================================================================
-- 8. ON RENDER FUNCTION (Drawing Logic)
-- ==============================================================================
local function on_render()
    -- Update settings from menu
    if menu_elements then
        Settings.is_enabled = menu_elements.enable_script:get_state()
        Settings.max_range = menu_elements.range_slider:get()
        Settings.use_get_all_objects = menu_elements.use_all_objects_toggle:get_state()
        Settings.show_pool_names = menu_elements.show_names_toggle:get_state()
        Settings.pool_name_text_size = menu_elements.pool_name_size_slider:get()
        Settings.enable_pool_glow = menu_elements.enable_glow_toggle:get_state()
        Settings.enable_cleanse_ghoulfish = menu_elements.cleanse_toggle:get_state()
        Settings.enable_auto_catch = menu_elements.auto_catch_toggle:get_state()
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

    if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Entering on_render") end

    local player = object_manager.get_local_player()
    if not player or not player:is_valid() then return end

    local player_pos = player:get_position()
    if not player_pos then return end

    -- == Update Glow States & Draw ==
    local pools_found_this_frame = {}
    local max_range = Settings.max_range
    local objects_to_check = nil
    local current_time_ms = core.time()

    if Settings.use_get_all_objects then
        objects_to_check = object_manager.get_all_objects()
    else
        objects_to_check = object_manager.get_visible_objects()
    end

    if not objects_to_check then
         if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: No objects returned by object_manager.") end
    else
        if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Checking " .. #objects_to_check .. " objects.") end
        local pools_in_range_count = 0

        for _, obj in ipairs(objects_to_check) do
            if obj and obj:is_valid() and obj.get_name and obj.get_position then
                local obj_key = tostring(obj)
                local obj_name = obj:get_name()
                if obj_name and FISHING_POOL_NAMES[obj_name] then
                    local obj_pos = obj:get_position()
                    if player_pos and obj_pos then
                        if player_pos:dist_to(obj_pos) <= max_range then
                             pools_in_range_count = pools_in_range_count + 1
                             pools_found_this_frame[obj_key] = true

                            -- Set Glow state
                            if Settings.enable_pool_glow and not GlowingPools[obj_key] then
                                 if obj.set_glow then
                                     obj:set_glow(true)
                                     GlowingPools[obj_key] = obj
                                 end
                            end

                            -- Color Logic (Solid Colors, Fixed Rainbow for Blood)
                            local final_line_color
                            if obj_name == "Blood in the Water" then
                                local ratio = 100 -- As requested
                                final_line_color = color.get_rainbow_color(ratio)
                                if not final_line_color then final_line_color = COLOR_BLOOD_BASE end
                            elseif obj_name == "Swarm of Slum Sharks" then
                                final_line_color = COLOR_SHARK_BASE
                            else
                                final_line_color = Settings.default_line_color_base
                            end

                            -- Draw Line & Name
                            if final_line_color then
                                graphics.line_3d(player_pos, obj_pos, final_line_color, const_line_thickness, 2.5, true)
                                if Settings.show_pool_names then
                                    local text_pos = Vec3.new(obj_pos.x, obj_pos.y, obj_pos.z + 0.75)
                                    graphics.text_3d(obj_name, text_pos, Settings.pool_name_text_size, final_line_color, true)
                                end
                            end
                        end
                    end
                end
            end -- End obj checks
        end -- End object loop
        if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Found " .. pools_in_range_count .. " pools in range this frame.") end
    end -- End if objects_to_check

    -- Turn off glow
    local remaining_glowing = {}
    local turn_off_count = 0
    for key, pool_obj in pairs(GlowingPools) do
        local should_glow_now = pools_found_this_frame[key] and Settings.enable_pool_glow
        if pool_obj and pool_obj:is_valid() then
            if should_glow_now then
                 remaining_glowing[key] = pool_obj
            else
                if pool_obj.set_glow then
                    pool_obj:set_glow(false)
                    turn_off_count = turn_off_count + 1
                end
            end
        end
    end
    if turn_off_count > 0 and core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Turned off glow for " .. turn_off_count .. " pools.") end
    GlowingPools = remaining_glowing

    -- == Draw Latency ==
    if Settings.show_latency then
         local ping = core_api.get_ping()
         local ping_text = string.format("Ping: %d ms", ping or 0)
         graphics.text_2d(ping_text, Settings.latency_display_pos, Settings.latency_display_text_size, Settings.default_line_color_base, true)
    end

    if core_api.log and Settings.verbose_logging then core_api.log("FishermansFriend: Exiting on_render") end
end


-- ==============================================================================
-- 9. MENU RENDER FUNCTION
-- ==============================================================================
local function menu_render()
    if not menu_elements or not menu_elements.main_tree then return end
    menu_elements.main_tree:render("Fisherman's Friend", function()
        menu_elements.enable_script:render("Enable Fisherman's Friend")
        menu_elements.range_slider:render("Max Draw Range (Yards)", Settings.max_range)
        menu_elements.use_all_objects_toggle:render("Use 'Get All Objects' (SLOW?)", "Check this to use get_all_objects instead of get_visible_objects.")

        menu_elements.visuals_tree:render("Visuals", function()
            menu_elements.show_names_toggle:render("Show Pool Names")
            menu_elements.pool_name_size_slider:render("Pool Name Size", Settings.pool_name_text_size)
            menu_elements.enable_glow_toggle:render("Enable Persistent Pool Glow")
            if graphics and graphics.text then graphics.text("Line Thickness: " .. string.format("%.1f", const_line_thickness), 10, (menu_elements.enable_glow_toggle.y or 10) + 20) end
        end)

        menu_elements.utility_tree:render("Utility", function()
             menu_elements.cleanse_toggle:render("Auto Cleanse Ghoulfish Curse", "Uses Cursed Ghoulfish item if debuff is active.")
             menu_elements.auto_catch_toggle:render("Enable Auto Catch Fish", "(WARNING: Uses UNDOCUMENTED bobber check & UNRELIABLE targeting!)") -- Updated tooltip
        end)

         menu_elements.debug_tree:render("Debugging", function()
            menu_elements.verbose_log_toggle:render("Enable Verbose Logging", "Logs extra details to console.")
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

    if core_api.log then core_api.log("Fishermans Friend v4.4 (Bobber Obj Check) Loaded Successfully!") end
    if core_api.log_warning then core_api.log_warning("FishermansFriend: AutoCatch uses UNDOCUMENTED bobber:does_bobber_have_fish() and UNRELIABLE closest bobber targeting!") end
    if core_api.log_warning then core_api.log_warning("FishermansFriend: Verify Ghoulfish/Fishing IDs and Bobber Name. No pcalls used.") end
else
    print("FishermansFriend: ERROR - Failed to register core callbacks (render, menu, or update).")
end