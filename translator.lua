-- Chat Translator by ShadyRetard

local NETWORK_GET_ADDR = "http://shady-aimware-api.cf/translate";
local SCRIPT_FILE_NAME = "translator.lua";
local SCRIPT_FILE_ADDR = "https://raw.githubusercontent.com/hyperthegreat/aw_translate/master/translator.lua";
local VERSION_FILE_ADDR = "https://raw.githubusercontent.com/hyperthegreat/aw_translate/master/version.txt";
local VERSION_NUMBER = "1.0.6";

local MESSAGE_COOLDOWN = 30;

local OPEN_TRANSLATE_WINDOW_CB = gui.Checkbox(gui.Reference("MISC", "AUTOMATION", "Other"), "OPEN_TRANSLATE_WINDOW_CB", "Chat translator", false);
local TRANSLATE_WINDOW = gui.Window("TRANSLATE_WINDOW", "Chat Translator", 0, 0, 300, 300);

-- TRANSLATED MESSAGES
local NUM_OF_MESSAGES_SLIDER = gui.Slider(TRANSLATE_WINDOW, "NUM_OF_MESSAGES_SLIDER", "# of shown messages", 10, 0, 50);

-- Other person's language
gui.Text(TRANSLATE_WINDOW, "Other person's language (ISO code): ");
local TRANSLATE_FROM_EDITBOX = gui.Editbox(TRANSLATE_WINDOW, "TRANSLATE_FROM_EDITBOX", "auto");

-- My language
gui.Text(TRANSLATE_WINDOW, "Your language (ISO code): ");
local TRANSLATE_MY_LANGUAGE_EDITBOX = gui.Editbox(TRANSLATE_WINDOW, "TRANSLATE_MY_LANGUAGE_EDITBOX", "en");

-- Translating own message
gui.Text(TRANSLATE_WINDOW, "Your message: ");
local TRANSLATE_MESSAGE_EDITBOX = gui.Editbox(TRANSLATE_WINDOW, "TRANSLATE_MESSAGE_EDITBOX", "");
gui.Text(TRANSLATE_WINDOW, "Translate to language (ISO code): ");
local TRANSLATE_TO_EDITBOX = gui.Editbox(TRANSLATE_WINDOW, "TRANSLATE_TO_EDITBOX", "en");

local EDITOR_POSITION_X, EDITOR_POSITION_Y = 50, 50;

local last_output_read = globals.TickCount();
local last_message_sent = globals.TickCount();

local messages_translated = {};
local text_width, text_height = 300, 0;
local show, pressed = false, true;

local is_dragging = false;
local dragging_offset_x, dragging_offset_y;

local update_available = false;
local version_check_done = false;
local update_downloaded = false;

function userMessageHandler(message)
    if (message:GetID() == 6) then
        local pid = message:GetInt( 1 );
        local text = message:GetString( 4, 1 );
        local name = client.GetPlayerNameByIndex(pid);

        local textallchat = message:GetInt(5);
        local translation = getTranslation("TRANSLATE", name, text, string.lower(TRANSLATE_FROM_EDITBOX:GetValue()),  string.lower(TRANSLATE_MY_LANGUAGE_EDITBOX:GetValue()), textallchat);
        if (translation == nil or translation == "") then
            return;
        end

        table.insert(messages_translated, translation);
    end
end

function drawEventHandler()
    if (update_available and not update_downloaded) then
        if (gui.GetValue("lua_allow_cfg") == false) then
            draw.Color(255, 0, 0, 255);
            draw.Text(0, 0, "[TRANSLATOR] An update is available, please enable Lua Allow Config and Lua Editing in the settings tab");
        else
            local new_version_content = http.Get(SCRIPT_FILE_ADDR);
            local old_script = file.Open(SCRIPT_FILE_NAME, "w");
            old_script:Write(new_version_content);
            old_script:Close();
            update_available = false;
            update_downloaded = true;
        end
    end

    if (update_downloaded) then
        draw.Color(255, 0, 0, 255);
        draw.Text(0, 0, "[TRANSLATOR] An update has automatically been downloaded, please reload the translator script");
        return;
    end

    if (not version_check_done) then
        if (gui.GetValue("lua_allow_http") == false) then
            draw.Color(255, 0, 0, 255);
            draw.Text(0, 0, "[TRANSLATOR] Please enable Lua HTTP Connections in your settings tab to use this script");
            return;
        end

        version_check_done = true;
        local version = http.Get(VERSION_FILE_ADDR);
        if (version ~= VERSION_NUMBER) then
            update_available = true;
        end
    end

    show = OPEN_TRANSLATE_WINDOW_CB:GetValue();

    if input.IsButtonPressed(gui.GetValue("msc_menutoggle")) then
        pressed = not pressed;
    end

    if (show and pressed) then
        TRANSLATE_WINDOW:SetActive(1);
    else
        TRANSLATE_WINDOW:SetActive(0);
    end

    if (last_output_read ~= nil and last_output_read > globals.TickCount()) then
        last_output_read = globals.TickCount();
    end

    if (last_message_sent ~= nil and last_message_sent > globals.TickCount()) then
        last_message_sent = globals.TickCount();
    end

    for i, msg in ipairs(messages_translated) do
        if (#messages_translated - i < NUM_OF_MESSAGES_SLIDER:GetValue()) then
            local w, h = draw.GetTextSize(msg);
            if (text_height == 0 or w > text_width) then
                text_width = math.max(w, text_width);
                text_height = h;
            end
        end
    end

    -- Header
    local header_text_width, header_text_height = draw.GetTextSize("Chat Translations");
    draw.Color(gui.GetValue("clr_gui_window_header"));
    draw.FilledRect(EDITOR_POSITION_X, EDITOR_POSITION_Y, EDITOR_POSITION_X + text_width + 20, EDITOR_POSITION_Y + header_text_height + 10);

    draw.Color(gui.GetValue("clr_gui_window_logo1"));
    draw.Text(EDITOR_POSITION_X + 5, EDITOR_POSITION_Y + 5, "Chat Translations");

    draw.Color(0, 0, 0, 100);
    draw.FilledRect(EDITOR_POSITION_X, EDITOR_POSITION_Y + header_text_height + 10, EDITOR_POSITION_X + text_width + 20, EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20)

    for i, msg in ipairs(messages_translated) do
        if (#messages_translated - i < NUM_OF_MESSAGES_SLIDER:GetValue()) then
            draw.Color(255, 255, 255, 255);
            draw.TextShadow(10 + EDITOR_POSITION_X,  header_text_height + 10 + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + EDITOR_POSITION_Y - (#messages_translated - i) * text_height - 10, msg);
        end
    end

    local mouse_x, mouse_y = input.GetMousePos();

    local left_mouse_down = input.IsButtonDown(1);

    local LOAD_TEXT_W, LOAD_TEXT_H = draw.GetTextSize("TEAM MESSAGE");

    if (is_dragging == true and left_mouse_down == false) then
        is_dragging = false;
        dragging_offset_x = 0;
        dragging_offset_y = 0;
    end

    if (left_mouse_down) then
        dragHandler(header_text_height);
    end

    if (mouse_x > EDITOR_POSITION_X and mouse_x < EDITOR_POSITION_X + LOAD_TEXT_W + 10 and mouse_y > EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20 and mouse_y < EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 30 + LOAD_TEXT_H) then
        draw.Color(0, 0, 0, 200);
        if (left_mouse_down) then
            sendMessage("ME_TEAM");
        end
    else
        draw.Color(0, 0, 0, 100);
    end

    draw.FilledRect(EDITOR_POSITION_X, EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20, EDITOR_POSITION_X + LOAD_TEXT_W + 10, EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 30 + LOAD_TEXT_H)
    draw.Color(255, 255, 255, 255);
    draw.Text(EDITOR_POSITION_X + 5, EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 25, "TEAM MESSAGE");

    local LOAD_TEXT_W2, LOAD_TEXT_H2 = draw.GetTextSize("GLOBAL MESSAGE");
    if (mouse_x > EDITOR_POSITION_X + LOAD_TEXT_W + 10 and mouse_x < EDITOR_POSITION_X + LOAD_TEXT_W + LOAD_TEXT_W2 + 20 and mouse_y > EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20 and mouse_y < EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 30 + LOAD_TEXT_H) then
        draw.Color(0, 0, 0, 200);
        if (left_mouse_down) then
            sendMessage("ME_ALL");
        end
    else
        draw.Color(0, 0, 0, 100);
    end

    draw.FilledRect(EDITOR_POSITION_X + LOAD_TEXT_W + 10, EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20, EDITOR_POSITION_X + LOAD_TEXT_W + LOAD_TEXT_W2 + 20, EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 30 + LOAD_TEXT_H)
    draw.Color(255, 255, 255, 255);
    draw.Text(EDITOR_POSITION_X + LOAD_TEXT_W + 15, EDITOR_POSITION_Y + header_text_height + 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 25, "GLOBAL MESSAGE");
end

function dragHandler(header_text_height)
    local mouse_x, mouse_y = input.GetMousePos();

    if (is_dragging == true) then
        EDITOR_POSITION_X = mouse_x - dragging_offset_x;
        EDITOR_POSITION_Y = mouse_y - dragging_offset_y;
        return;
    end

    if (mouse_x >= EDITOR_POSITION_X and mouse_x <= EDITOR_POSITION_X + text_width and mouse_y >= EDITOR_POSITION_Y and mouse_y <= EDITOR_POSITION_Y + header_text_height + 10) then
        is_dragging = true;
        dragging_offset_x = mouse_x - EDITOR_POSITION_X;
        dragging_offset_y = mouse_y - EDITOR_POSITION_Y;
        return;
    end
end

function sendMessage(type)
    if (globals.TickCount() - last_message_sent < MESSAGE_COOLDOWN) then
        return;
    end

    local text = TRANSLATE_MESSAGE_EDITBOX:GetValue();

    if (text == nil or text == "") then
        return;
    end

    local translation = getTranslation("ME_TEAM", "none", text, string.lower(TRANSLATE_MY_LANGUAGE_EDITBOX:GetValue()),  string.lower(TRANSLATE_TO_EDITBOX:GetValue()), 1);
    if (translation == nil or translation == "") then
        return;
    end

    if (type == "ME_TEAM") then
        client.ChatTeamSay(translation);
    elseif (type == "ME_ALL") then
        client.ChatSay(translation);
    end

    last_message_sent = globals.TickCount();
end

function getTranslation(type, name, message, from, to, teamonly)
    if (teamonly == 0) then
        teamonly = 1;
    else
        teamonly = 0;
    end

    if (name == nil or name == "") then
        name = "unknown";
    end

    name = urlencode(name);
    message = urlencode(message);

    return http.Get(NETWORK_GET_ADDR .. "?type=" .. type .. "&name=" .. name .."&msg=" .. message .. "&from=" .. from .. "&to=" .. to .. "&team=" .. teamonly);
end

local char_to_hex = function(c)
    return string.format("%%%02X", string.byte(c))
end

function urlencode(url)
    if url == nil then
        return
    end
    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w ])", char_to_hex)
    url = url:gsub(" ", "+")
    return url
end

callbacks.Register("Draw", "translate_draw_event", drawEventHandler);
callbacks.Register("DispatchUserMessage", "translate_usermessage_handler", userMessageHandler);