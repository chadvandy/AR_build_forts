-- luacheck: globals core cm effect out
-- luacheck: globals find_uicomponent UIComponent Util Button TextButton FlowLayout Container ListView Frame
-- luacheck: globals build

local function table_contains(t, val)
    for _, v in ipairs(t) do
        if v == val then
            return true
        end
    end
    return false
end

_G.build = _G.build or {}
local build = _G.build
build.spawn_funcs = build.spawn_funcs or {}
build.localizations = build.localizations or {}
-------------------initialize values
if not cm:get_saved_value("next_fort_number") then cm:set_saved_value("next_fort_number", 1); end;
if not cm:get_saved_value("next_watchtower_number") then cm:set_saved_value("next_watchtower_number", 1); end;
if not cm:get_saved_value("next_watchtower_agent_number") then cm:set_saved_value("next_watchtower_agent_number", 1); end;

-------------------Dilemma function
function BuildDeployables()
	local x = cm:get_saved_value("temp_x");
	local y = cm:get_saved_value("temp_y");
cm:trigger_dilemma(cm:model():world():whose_turn_is_it():name(), "build_dilemma");
end;
-------------------Create agent
function CreateWatchtowers(watchtower_number, watchtower_x, watchtower_y)
local viable_x, viable_y = cm:find_valid_spawn_location_for_character_from_position(cm:model():world():whose_turn_is_it():name(), watchtower_x, watchtower_y, false, 1);
out("creating agent")
    cm:create_agent(
        cm:model():world():whose_turn_is_it():name(),
        "spy",
        "emp_witch_hunter",
        viable_x,
        viable_y,
        false,
        function(cqi)
        local agent = cm:char_lookup_str(cqi);
out("cqi of agent is:")
out(cqi)
            cm:set_saved_value("agent_watchtower_number_"..watchtower_number, cqi);
        end
    );
cm:set_saved_value("watchtower_agent_"..watchtower_number, watchtower_number)
end;

-----------------Delete agents
function DeleteWatchtowers()
out("deleting watchtowers!")
	local num_watchtower_agents = cm:get_saved_value("watchtower_number")
if num_watchtower_agents then
out("number of agents to delete is:")
out(num_watchtower_agents)
	for i = 1, num_watchtower_agents do
  		if cm:get_saved_value("agent_watchtower_number_"..i) then
out("deleting this:")
out(cm:get_saved_value("agent_watchtower_number_"..i))
out("for tower")
out(i)
		local character_kill = cm:get_character_by_cqi(cm:get_saved_value("agent_watchtower_number_"..i));
		if character_kill then
		cm:kill_character(character_kill:command_queue_index(), true, true)
out("deleted it, next!")
		end
		end
	end
end
end;
-------------------Button
build.create_main_button = function()
    local build_buttonParent =
        find_uicomponent(
        core:get_ui_root(),
        "units_panel",
        "main_units_panel",
        "recruitment_docker",
		"recruitment_options",
		"title_docker"
    )

    local build_dow_main_ui_button = Util.digForComponent(core:get_ui_root(), "build_dow_main_ui_button")
    if not build_dow_main_ui_button then
        build_dow_main_ui_button =
            Button.new("build_dow_main_ui_button", build_buttonParent, "SQUARE", "ui/skins/default/icon_build.png")
    end
    build_dow_main_ui_button.uic:PropagatePriority(101)
    -- build_dow_main_ui_button:SetImagePath("ui/skins/default/icon_build.png")

    local build_army_abilities_panel =
        find_uicomponent(
        core:get_ui_root(),
        "units_panel",
        "main_units_panel",
        "recruitment_docker",
        "recruitment_options"
    )
    build_dow_main_ui_button:Resize(28, 28)
    build_dow_main_ui_button:PositionRelativeTo(build_army_abilities_panel, 573, 12)
    build_dow_main_ui_button:SetState("hover")
    build_dow_main_ui_button.uic:SetTooltipText("Build Structure")
    build_dow_main_ui_button.uic:PropagatePriority(101)
    build_dow_main_ui_button:SetState("active")
    build_dow_main_ui_button.uic:PropagatePriority(101)
    build_dow_main_ui_button:RegisterForClick(
        function()
            local build_minimise_unit_panel_button =
                find_uicomponent(
                core:get_ui_root(),
                "units_panel",
                "main_units_panel",
                "recruitment_docker",
                "recruitment_options",
                "title_docker",
                "button_minimise"
	)
            if build_minimise_unit_panel_button then
                build_minimise_unit_panel_button:SimulateLClick()
            end
out("you clicked ze button!")
BuildDeployables()
        end
    )
    build.build_dow_main_ui_button = build_dow_main_ui_button
end

core:remove_listener("build_UnitsPanelOpenedListener")
core:add_listener(
    "build_UnitsPanelOpenedListener",
    "PanelOpenedCampaign",
    function(context)
        return context.string == "units_recruitment"
    end,
    function()
        local build_dow_main_ui_button = Util.digForComponent(core:get_ui_root(), "build_dow_main_ui_button")
        if not build_dow_main_ui_button then
            build.create_main_button()
        end
    end,
    true
)

core:remove_listener("build_UnitsPanelClosedListener")
core:add_listener(
    "build_UnitsPanelClosedListener",
    "PanelClosedCampaign",
    function(context)
        return context.string == "units_recruitment"
    end,
    function()
        cm:remove_callback("build_remove_main_button_cb")
        cm:callback(
            function()
                local build_dow_main_ui_button = Util.digForComponent(core:get_ui_root(), "build_dow_main_ui_button")
                if build_dow_main_ui_button then
                    Util.delete(build_dow_main_ui_button)
                    build.build_dow_main_ui_button = nil
                end
                core:remove_listener("build_main_button_click_listener")
            end,
            0.1,
            "build_remove_main_button_cb"
        )
    end,
    true
)

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
	local selected_character = context:character()
	local cqi = context:character():cqi()
	cm:set_saved_value("temp_character_build", cqi);
    end,
    true
)

core:add_listener(
	"dilemma_choice_build_deployables",
	"DilemmaChoiceMadeEvent",
	true,
	function(context)
	local choice = context:choice();
out("choice is")
out(choice)
	local faction = cm:model():world():whose_turn_is_it()
	local faction_culture = faction:culture()
	local faction_subculture = faction:subculture()
	local dilemma = context:dilemma();
		if dilemma == "build_dilemma" and choice == 1 then
		local fort_number = cm:get_saved_value("next_fort_number")
		local character = cm:get_character_by_cqi(cm:get_saved_value("temp_character_build"));
		local character_cqi = cm:get_saved_value("temp_character_build")
		local x = character:logical_position_x();
		local y = character:logical_position_y();
			if faction_culture  == "wh_main_emp_empire" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "emp_fort", x+1, y, 6, "", "");
			end;
			if faction_culture  == "wh_main_brt_bretonnia" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "brt_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh_main_dwf_dwarfs" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "dwf_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh2_main_def_dark_elves" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "def_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh2_main_hef_high_elves" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "hef_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh2_main_lzd_lizardmen" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "lzd_fort", x, y, 6, "", "");
			end;
			if faction_subculture  == "wh_main_sc_nor_norsca" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "nor_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh2_main_skv_skaven" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "skv_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh_main_vmp_vampire_counts" or faction_culture  == "wh2_dlc11_cst_vampire_coast" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "vmp_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh_main_grn_greenskins" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "grn_fort", x, y, 6, "", "");
			end;
			if faction_subculture  == "wh_main_sc_chs_chaos" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "chs_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh_dlc05_wef_wood_elves" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "wef_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh2_dlc09_tmb_tomb_kings" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "tk_fort", x, y, 6, "", "");
			end;
			if faction_culture  == "wh_dlc03_bst_beastmen" then
			cm:add_interactable_campaign_marker("fort_"..fort_number, "bst_fort", x, y, 6, "", "");
			end;
		cm:set_saved_value("next_fort_number", fort_number + 1)
		cm:apply_effect_bundle_to_characters_force("fort_effect", character_cqi, 1, false)
		end;
		if dilemma == "build_dilemma" and choice == 0 then
		local watchtower_number = cm:get_saved_value("next_watchtower_number")
		local character = cm:get_character_by_cqi(cm:get_saved_value("temp_character_build"));
		local x = character:logical_position_x();
		local y = character:logical_position_y();
			if faction_culture  == "wh_main_emp_empire" then
out("creating watchtower")
out("watchtower number is:")
out(watchtower_number)
out("character")
out(x)
out(y)
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "emp_watchtower", x, y, 1, "", "");
out("created watchtower")
			end;
			if faction_culture  == "wh_main_brt_bretonnia" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "brt_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh_main_dwf_dwarfs" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "dwf_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh2_main_def_dark_elves" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "def_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh2_main_hef_high_elves" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "hef_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh2_main_lzd_lizardmen" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "lzd_watchtower", x, y, 1, "", "");
			end;
			if faction_subculture  == "wh_main_sc_nor_norsca" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "nor_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh2_main_skv_skaven" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "skv_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh_main_vmp_vampire_counts" or faction_culture  == "wh2_dlc11_cst_vampire_coast" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "vmp_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh_main_grn_greenskins" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "grn_watchtower", x, y, 1, "", "");
			end;
			if faction_subculture  == "wh_main_sc_chs_chaos" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "chs_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh_dlc05_wef_wood_elves" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "wef_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh2_dlc09_tmb_tomb_kings" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "tk_watchtower", x, y, 1, "", "");
			end;
			if faction_culture  == "wh_dlc03_bst_beastmen" then
			cm:add_interactable_campaign_marker("watchtower_"..watchtower_number, "bst_watchtower", x, y, 1, "", "");
			end;
		cm:set_saved_value("watchtower_"..watchtower_number, watchtower_number); out("created watchtower"); out("watchtower_"..watchtower_number)
		cm:set_saved_value("x_watchtower_"..watchtower_number, x) 
		cm:set_saved_value("y_watchtower_"..watchtower_number, y)
		cm:set_saved_value("watchtower_number", watchtower_number)
		cm:set_saved_value("next_watchtower_number", watchtower_number + 1)
		end;
end,
true
);

core:add_listener(
	"area_entered_build_structures",
	"AreaEntered",
	true,
	function(context)
	local area_key = context:area_key()
	local character = context:character();
	local cqi = context:character():cqi()
	local faction_name = cm:get_local_faction();
	local faction = cm:get_faction(faction_name);
		if cm:char_is_general_with_army(character) then
			if string.find(area_key, "fort") and context:character():faction():is_human() then 
			cm:apply_effect_bundle_to_characters_force("fort_effect", cqi, 1, false)
			end;
		end;
	end,
	true
);

core:add_listener(
	"area_exited_build_structures",
	"AreaExited",
	true,
	function(context)
	local area_key = context:area_key()
	local character = context:character();
	local cqi = context:character():cqi()
	local faction_name = cm:get_local_faction();
	local faction = cm:get_faction(faction_name);
		if cm:char_is_general_with_army(character) then
			if string.find(area_key, "fort") and context:character():faction():is_human() then 
			cm:remove_effect_bundle_from_characters_force("fort_effect", cqi)
			end;
		end;
	end,
	true
);

core:add_listener(
	"faction_turn_end_createwatchtowers",
	"FactionTurnEnd",
	function(context) return context:faction():is_human() == true; end,
	function()
cm:disable_event_feed_events(true,"wh_event_category_agent","","");
out("test_watch1")
	local num_watchtowers =  cm:get_saved_value("next_watchtower_number")
out("number of watchtowers is")
out(num_watchtowers)
		for i = 1, num_watchtowers do
			local watchtower_number = cm:get_saved_value("watchtower_"..i)
out("watchtower number is")
out(watchtower_number)
			local watchtower_x = cm:get_saved_value("x_watchtower_"..i)
out("watchtower x is")
out(watchtower_x)
			local watchtower_y = cm:get_saved_value("y_watchtower_"..i)
out("watchtower y is")
out(watchtower_y)
			if watchtower_number then
out("watchtower exists")
			CreateWatchtowers(watchtower_number, watchtower_x, watchtower_y)
   			end
		end
out("proceeding to the deletion")
	DeleteWatchtowers()
cm:callback(function() cm:disable_event_feed_events(false,"wh_event_category_agent","","") end, 0.3)
end,
true
);