if not __game_mode == __lib_type_campaign then
    -- only trigger this on campaign
    return
end

local fort_manager = {
    button_key = "build_fort",
    button = nil,
}

function fort_manager:create_main_button()
    local parent = find_uicomponent(
        core:get_ui_root(),
        "layout",
        "hud_center_docker",
        "hud_center",
        "small_bar",
        "button_group_army"
    )

    local button = find_uicomponent(parent, self.button_key)
    if not button then
        button = UIComponent(parent:CreateComponent(self.button_key, "ui/templates/square_medium_button"))
        button:SetImagePath("ui/skins/default/icon_build.png")
    end

    --button:PropagatePriority(101)

    --button:SetState("hover")

    button:SetTooltipText("Build Structure||Deploy the engineers of this army to construct a fort or watchtower.", true)
    button:SetState("active")
    --button:Resize(28, 28)

    self.button = button

    parent:Layout()

    core:remove_listener("fort_build_button")
    core:add_listener(
        "fort_build_button",
        "ComponentLClickUp",
        function(context)
            return context.string == self.button_key
        end,
        function(context)
            self:deployable_dilemma()
        end,
        true
    )
end

function fort_manager:deployable_dilemma()
	--[[local x = cm:get_saved_value("temp_x");
	local y = cm:get_saved_value("temp_y");]]
    cm:trigger_dilemma(cm:model():world():whose_turn_is_it():name(), "build_dilemma");
end

function fort_manager:create_watchtower(watchtower_number, watchtower_x, watchtower_y)
    local viable_x, viable_y = cm:find_valid_spawn_location_for_character_from_position(cm:model():world():whose_turn_is_it():name(), watchtower_x, watchtower_y, false, 1);
    --out("creating agent")

    cm:create_agent(
        cm:model():world():whose_turn_is_it():name(),
        "spy",
        "emp_witch_hunter",
        viable_x,
        viable_y,
        false,
        function(cqi)
            local agent = cm:char_lookup_str(cqi);
            cm:set_saved_value("agent_watchtower_number_"..watchtower_number, cqi);
        end
    );

    cm:set_saved_value("watchtower_agent_"..watchtower_number, watchtower_number)
end

function fort_manager:delete_watchtowers()
    --out("deleting watchtowers!")
    local num_watchtower_agents = cm:get_saved_value("watchtower_number")
    
    if num_watchtower_agents and num_watchtower_agents > 0 then
        for i = 1, num_watchtower_agents do
            if cm:get_saved_value("agent_watchtower_number_"..i) then
                local character_kill = cm:get_character_by_cqi(cm:get_saved_value("agent_watchtower_number_"..i));
                if character_kill then
                    cm:kill_character(character_kill:command_queue_index(), true, true)
                end
            end
        end
    end
end

function fort_manager:init()
    -------------------initialize values
	if not cm:get_saved_value("next_fort_number") then cm:set_saved_value("next_fort_number", 1); end;
	if not cm:get_saved_value("next_watchtower_number") then cm:set_saved_value("next_watchtower_number", 1); end;
    if not cm:get_saved_value("next_watchtower_agent_number") then cm:set_saved_value("next_watchtower_agent_number", 1); end;
    
    -- initialize listeners --

    -- create the button when the panel is opened
    core:add_listener(
        "build_UnitsPanelOpenedListener",
        "PanelOpenedCampaign",
        function(context)
            return context.string == "units_panel"
        end,
        function()
            local test = self.button
            if not is_uicomponent(test) then
                self:create_main_button()
            end
        end,
        true
    )
    
    -- remove UI stuff when the panel closes
    core:add_listener(
        "fm_units_panel_closed",
        "PanelClosedCampaign",
        function(context)
            return context.string == "units_panel"
        end,
        function(context)
            self.button = nil
        end,
        true
    )

    -- apply the fort effect bundle when an army enters a fort zone
    -- TODO make sure the fort knows what faction a fort is owned by
    core:add_listener(
        "fm_fort_area_entered",
        "AreaEntered",
        function(context)
            return string.find(context:area_key(), "fort")
        end,
        function(context)
            local character = context:character();
            local cqi = context:character():cqi()
            --[[local faction_name = cm:get_local_faction();
            local faction = cm:get_faction(faction_name);]]

            if cm:char_is_general_with_army(character) then
                if context:character():faction():is_human() then
                    cm:apply_effect_bundle_to_characters_force("fort_effect", cqi, 0, false)
                end;
            end;
        end,
        true
    );

    -- remove the fort effect bundle!
    -- TODO, ditto, make sure the manager recognizes who owns this fort.
    core:add_listener(
        "area_exited_build_structures",
        "AreaExited",
        function(context)
            return string.find(context:area_key(), "fort")
        end,
        function(context)
            local character = context:character();
            local cqi = context:character():cqi()

            if cm:char_is_general_with_army(character) then
                if context:character():faction():is_human() then 
                    cm:remove_effect_bundle_from_characters_force("fort_effect", cqi)
                end;
            end;
        end,
        true
    );

    -- construction listener
    core:add_listener(
        "dilemma_choice_build_deployables",
        "DilemmaChoiceMadeEvent",
        function(context)
            return context:dilemma() == "build_dilemma"
        end,
        function(context)
            local choice = context:choice();

            local faction = cm:model():world():whose_turn_is_it()
            local faction_culture = faction:culture()
            local faction_subculture = faction:subculture()
            local dilemma = context:dilemma();



            if choice == 0 then -- watchtower
                local watchtower_number = cm:get_saved_value("next_watchtower_number")
                local character = cm:get_character_by_cqi(cm:get_saved_value("temp_character_build"));
                local x = character:logical_position_x();
                local y = character:logical_position_y();

                local watchtower_key = ""
                local cult_to_watchtower_key = {
                    wh_main_emp_empire = "emp_watchtower",
                    wh_main_brt_bretonnia = "brt_watchtower",
                    wh_main_dwf_dwarfs = "dwf_watchtower",
                    wh2_main_def_dark_elves = "def_watchtower",
                    wh2_main_hef_high_elves = "hef_watchtower",
                    wh2_main_lzd_lizardmen = "lzd_watchtower",
                    wh2_main_skv_skaven = "skv_watchtower",
                    wh_main_vmp_vampire_counts = "vmp_watchtower",
                    wh2_dlc11_cst_vampire_coast = "vmp_watchtower",
                    wh_main_grn_greenskins = "grn_watchtower",
                    wh_dlc05_wef_wood_elves = "wef_watchtower",
                    wh2_dlc09_tmb_tomb_kings = "tk_watchtower",
                    wh_dlc03_bst_beastmen = "bst_watchtower",
                }

                local subcult_to_watchtower_key = {
                    wh_main_sc_nor_norsca = "nor_watchtower",
                    wh_main_sc_chs_chaos = "chs_watchtower",
                }

                watchtower_key = subcult_to_watchtower_key[faction_subculture]
                if watchtower_key == "" or watchtower_key == nil then
                    watchtower_key = cult_to_watchtower_key[faction_culture]
                end

                if watchtower_key == "" or watchtower_key == nil then
                    -- not found due to modded subcult, TODO error
                    return
                end


                cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, watchtower_key, x, y, 1, "", "");
        
                cm:set_saved_value("watchtower_"..watchtower_number, watchtower_number); out("created watchtower"); out("watchtower_"..watchtower_number)
                cm:set_saved_value("x_watchtower_"..watchtower_number, x) 
                cm:set_saved_value("y_watchtower_"..watchtower_number, y)
                cm:set_saved_value("watchtower_number", watchtower_number)
                cm:set_saved_value("next_watchtower_number", watchtower_number + 1)


            elseif choice == 1 then -- fort
                local fort_number = cm:get_saved_value("next_fort_number")
                local character = cm:get_character_by_cqi(cm:get_saved_value("temp_character_build"));
                local character_cqi = cm:get_saved_value("temp_character_build")
                local x = character:logical_position_x();
                local y = character:logical_position_y();

                local fort_key = ""

                local subcult_to_fort_key = {
                    wh_main_sc_nor_norsca = "nor_fort",
                    wh_main_sc_chs_chaos = "chs_fort",
                }

                local cult_to_fort_key = {
                    wh_main_emp_empire = "emp_fort",
                    wh_main_brt_bretonnia = "brt_fort",
                    wh_main_dwf_dwarfs = "dwf_fort",
                    wh2_main_def_dark_elves = "def_fort",
                    wh2_main_hef_high_elves = "hef_fort",
                    wh2_main_lzd_lizardmen = "lzd_fort",
                    wh2_main_skv_skaven = "skv_fort",
                    wh_main_vmp_vampire_counts = "vmp_fort",
                    wh2_dlc11_cst_vampire_coast = "vmp_fort",
                    wh_main_grn_greenskins = "grn_fort",
                    wh_dlc05_wef_wood_elves = "wef_fort",
                    wh2_dlc09_tmb_tomb_kings = "tk_fort",
                    wh_dlc03_bst_beastmen = "bst_fort"
                }

                fort_key = subcult_to_fort_key[faction_subculture]
                if fort_key == nil then
                    fort_key = cult_to_fort_key[faction_culture]
                end

                if fort_key == nil then
                    -- no fort found for this culture, TODO this error
                    return
                end

                -- create the fort on map
                cm:add_interactable_campaign_marker("fort_"..fort_number, fort_key, x, y, 6, "", "");

                -- save the new fort number index + apply EB
                cm:set_saved_value("next_fort_number", fort_number + 1)
                cm:apply_effect_bundle_to_characters_force("fort_effect", character_cqi, 0, false)
            end
        end,
        true
    );

    -- create + delete watchtowers on human endturn
    core:add_listener(
        "faction_turn_end_createwatchtowers",
        "FactionTurnEnd",
        function(context) 
            return context:faction():is_human()
        end,
        function()
            cm:disable_event_feed_events(true,"wh_event_category_agent","","");

            local num_watchtowers =  cm:get_saved_value("next_watchtower_number")

            for i = 1, num_watchtowers do
                local watchtower_number = cm:get_saved_value("watchtower_"..i)
                local watchtower_x = cm:get_saved_value("x_watchtower_"..i)
                local watchtower_y = cm:get_saved_value("y_watchtower_"..i)

                if watchtower_number then
                    self:create_watchtower(watchtower_number, watchtower_x, watchtower_y)
                end
            end

            --  out("proceeding to the deletion")
            self:delete_watchtowers()
            
            cm:callback(function() 
                cm:disable_event_feed_events(false,"wh_event_category_agent","","") 
            end, 0.3)
        end,
        true
    );

    -- track selected character (to know where to spawn le stuffs) -- TODO mp support!
    core:add_listener(
        "build_CharacterSelected_Listener",
        "CharacterSelected",
        function(context)
            local faction_name = context:character():faction():name()
            return cm:model():faction_is_local(faction_name) and
                cm:model():world():whose_turn_is_it():name() == faction_name and
                context:character():character_type_key() == "general"
        end,
        function(context)
            local cqi = context:character():cqi()
            cm:set_saved_value("temp_character_build", cqi);
        end,
        true
    )
end


cm:add_first_tick_callback(function()
    fort_manager:init()
end)