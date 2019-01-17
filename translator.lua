-- Chat Translator by ShadyRetard

-- Network configuration (Don't touch if you don't know what you're doing)
local NETWORK_QUEUE_FILE_NAME = "network_queue.dat";
local NETWORK_OUTPUT_FILE_NAME = "network_output.dat";
local NETWORK_PREFIX = "TRANSLATOR";
local NETWORK_POST_ADDR = "http://shady-aimware-api.cf:8080/translate";
local SCRIPT_FILE_NAME = "translator.lua";
local SCRIPT_FILE_ADDR = "https://raw.githubusercontent.com/hyperthegreat/aw_translate/master/translator.lua";
local VERSION_FILE_ADDR = "https://raw.githubusercontent.com/hyperthegreat/aw_translate/master/version.txt";
local VERSION_NUMBER = "1.0.0";

local OUTPUT_READ_TIMEOUT = 30;
local MESSAGE_COOLDOWN = 30;

local OPEN_TRANSLATE_WINDOW_CB = gui.Checkbox(gui.Reference("MISC", "AUTOMATION", "Other"), "OPEN_TRANSLATE_WINDOW_CB", "Chat translator", false);
local TRANSLATE_WINDOW = gui.Window("TRANSLATE_WINDOW", "Chat Translator", 0, 0, 300, 500);

-- TRANSLATED MESSAGES
local POS_X_SLIDER = gui.Slider(TRANSLATE_WINDOW, "POS_X_SLIDER", "X Position", 0, 0, 3000);
local POS_Y_SLIDER = gui.Slider(TRANSLATE_WINDOW, "POS_Y_SLIDER", "Y Position", 0, 0, 3000);
local NUM_OF_MESSAGES_SLIDER = gui.Slider(TRANSLATE_WINDOW, "NUM_OF_MESSAGES_SLIDER", "# of shown messages", 10, 0, 50);

-- Other person's language
gui.Text(TRANSLATE_WINDOW, "Other person's language (ISO code): ");
local TRANSLATE_FROM_EDITBOX = gui.Editbox(TRANSLATE_WINDOW, "TRANSLATE_FROM_EDITBOX", "auto");

-- My language
gui.Text(TRANSLATE_WINDOW, "Your language (ISO code): ");
local TRANSLATE_MY_LANGUAGE_EDITBOX = gui.Editbox(TRANSLATE_WINDOW, "TRANSLATE_MY_LANGUAGE_EDITBOX", "en");

-- Translating own message
gui.Text(TRANSLATE_WINDOW, "Translate to language (ISO code): ");
local TRANSLATE_TO_EDITBOX = gui.Editbox(TRANSLATE_WINDOW, "TRANSLATE_TO_EDITBOX", "en");
gui.Text(TRANSLATE_WINDOW, "Your message: ");
local TRANSLATE_MESSAGE_EDITBOX = gui.Editbox(TRANSLATE_WINDOW, "TRANSLATE_MESSAGE_EDITBOX", "");

local last_output_read = globals.TickCount();
local last_message_sent = globals.TickCount();

-- Just open up the file in append mode, should create the file if it doesn't exist and won't override anything if it does
local network_queue_file = file.Open(NETWORK_QUEUE_FILE_NAME, "a");
if (network_queue_file ~= nil) then
    network_queue_file:Close();
end

local network_output_file = file.Open(NETWORK_OUTPUT_FILE_NAME, "a");
if (network_output_file ~= nil) then
    network_output_file:Close();
end

local messages_translated = {};
local text_width, text_height = 0, 0;
local show, pressed = false, true;
local version_check_sent = false;
local update_downloaded = false;

function gameEventHandler(event)
    if (update_downloaded) then
        return;
    end

    if (event:GetName() == "player_say") then
        local teamonly = event:GetInt('teamonly');
        local player_name = client.GetPlayerNameByUserID(event:GetInt('userid'));
        local text = event:GetString('text');

        writeToFile(NETWORK_QUEUE_FILE_NAME, "a", NETWORK_PREFIX .. " GET " .. NETWORK_POST_ADDR .. "?type=TRANSLATE&from=" .. string.lower(TRANSLATE_FROM_EDITBOX:GetValue()) .. "&to=" .. string.lower(TRANSLATE_MY_LANGUAGE_EDITBOX:GetValue()) .. "&team=" .. teamonly .. "&name=" .. player_name .. "&msg=" .. text .. "\n");
    end
end

function drawEventHandler()
    if (update_downloaded) then
        draw.Color(255, 0, 0, 255);
        draw.Text(0, 0, "[TRANSLATOR] An update has automatically been downloaded, please reload the translate script");
        return;
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

    if (version_check_sent == false) then
        version_check_sent = writeToFile(NETWORK_QUEUE_FILE_NAME, "a", NETWORK_PREFIX .. " GET " .. VERSION_FILE_ADDR);
    end

    if (globals.TickCount() - last_output_read > OUTPUT_READ_TIMEOUT) then
        last_output_read = globals.TickCount();
        local network_output_file = file.Open(NETWORK_OUTPUT_FILE_NAME, "r");
        local output = network_output_file:Read();
        network_output_file:Close();

        local lines_omitted = 0;
        local lines_to_keep = {};

        for line in string.gmatch(output, "([^\n]*)\n") do
            local words = {};
            for word in string.gmatch(line, "%S+") do
                table.insert(words, word)
            end

            local prefix = words[1];
            local status = words[2];
            local type = words[3];
            local response = "";
            for i = 4, #words do
                response = response .. " " .. words[i];
            end

            if (prefix ~= NETWORK_PREFIX) then
                table.insert(lines_to_keep, line);
            else
                lines_omitted = lines_omitted + 1;
                if (status == "SUCCESS") then
                    if (type == "ME_TEAM") then
                        client.ChatTeamSay(response);
                    elseif (type == "ME_ALL") then
                        client.ChatSay(response);
                    elseif (type == "TRANSLATE") then
                        table.insert(messages_translated, "[TRANSLATOR] " .. response .. "");
                    else
                        -- Version check
                        if (type ~= VERSION_NUMBER) then
                            writeToFile(NETWORK_QUEUE_FILE_NAME, "a", NETWORK_PREFIX .. " VERSION_UPDATE " .. SCRIPT_FILE_ADDR .. " " .. SCRIPT_FILE_NAME);
                            update_downloaded = true;
                        end
                    end
                end
            end
        end

        if (lines_omitted > 0) then
            -- Clear the file
            writeToFile(NETWORK_OUTPUT_FILE_NAME, "w", table.concat(lines_to_keep, "\n"));
        end
    end
    for i, msg in ipairs(messages_translated) do
        if (#messages_translated - i < NUM_OF_MESSAGES_SLIDER:GetValue()) then
            local w, h = draw.GetTextSize(msg);
            if (text_height == 0 or w > text_width) then
                text_width, text_height = draw.GetTextSize(msg);
            end
        end
    end

    draw.Color(0, 0, 0, 100);
    draw.FilledRect(POS_X_SLIDER:GetValue(), POS_Y_SLIDER:GetValue(), POS_X_SLIDER:GetValue() + text_width + 20, POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20)

    for i, msg in ipairs(messages_translated) do
        if (#messages_translated - i < NUM_OF_MESSAGES_SLIDER:GetValue()) then
            draw.Color(255, 255, 255, 255);
            draw.TextShadow(10 + POS_X_SLIDER:GetValue(), 10 + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + POS_Y_SLIDER:GetValue() - (#messages_translated - i) * text_height - 10, msg);
        end
    end

    local mouse_x, mouse_y = input.GetMousePos();

    local left_mouse_down = input.IsButtonDown(1);

    local LOAD_TEXT_W, LOAD_TEXT_H = draw.GetTextSize("TEAM MESSAGE");
    if (mouse_x > POS_X_SLIDER:GetValue() and mouse_x < POS_X_SLIDER:GetValue() + LOAD_TEXT_W + 10 and mouse_y > POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20 and mouse_y < POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 30 + LOAD_TEXT_H) then
        draw.Color(0, 0, 0, 200);
        if (left_mouse_down) then
            sendMessage("ME_TEAM");
            -- print
        end
    else
        draw.Color(0, 0, 0, 100);
    end

    draw.FilledRect(POS_X_SLIDER:GetValue(), POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20, POS_X_SLIDER:GetValue() + LOAD_TEXT_W + 10, POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 30 + LOAD_TEXT_H)
    draw.Color(255, 255, 255, 255);
    draw.Text(POS_X_SLIDER:GetValue() + 5, POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 25, "TEAM MESSAGE");

    local LOAD_TEXT_W2, LOAD_TEXT_H2 = draw.GetTextSize("GLOBAL MESSAGE");
    if (mouse_x > POS_X_SLIDER:GetValue() + LOAD_TEXT_W + 10 and mouse_x < POS_X_SLIDER:GetValue() + LOAD_TEXT_W + LOAD_TEXT_W2 + 20 and mouse_y > POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20 and mouse_y < POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 30 + LOAD_TEXT_H) then
        draw.Color(0, 0, 0, 200);
        if (left_mouse_down) then
            sendMessage("ME_ALL");
        end
    else
        draw.Color(0, 0, 0, 100);
    end

    draw.FilledRect(POS_X_SLIDER:GetValue() + LOAD_TEXT_W + 10, POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 20, POS_X_SLIDER:GetValue() + LOAD_TEXT_W + LOAD_TEXT_W2 + 20, POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 30 + LOAD_TEXT_H)
    draw.Color(255, 255, 255, 255);
    draw.Text(POS_X_SLIDER:GetValue() + LOAD_TEXT_W + 15, POS_Y_SLIDER:GetValue() + NUM_OF_MESSAGES_SLIDER:GetValue() * text_height + 25, "GLOBAL MESSAGE");
end

function sendMessage(type)
    if (globals.TickCount() - last_message_sent < MESSAGE_COOLDOWN) then
        return;
    end

    local text = TRANSLATE_MESSAGE_EDITBOX:GetValue();

    if (text == nil or text == "") then
        return;
    end

    local teamonly = 1;
    local player_name = "unnecessary";

    writeToFile(NETWORK_QUEUE_FILE_NAME, "a", NETWORK_PREFIX .. " GET " .. NETWORK_POST_ADDR .. "?type=" .. type .. "&from=" .. string.lower(TRANSLATE_MY_LANGUAGE_EDITBOX:GetValue()) .. "&to=" .. string.lower(TRANSLATE_TO_EDITBOX:GetValue()) .. "&team=" .. teamonly .. "&name=" .. player_name .. "&msg=" .. text .. "\n");
end

function writeToFile(fileName, mode, content)
    local write_file = file.Open(fileName, mode);
    if (write_file ~= nil) then
        write_file:Write(content);
        write_file:Close();
        return true;
    end

    return false;
end

client.AllowListener("player_say", true);
client.AllowListener("player_chat", true);

callbacks.Register("Draw", "translate_draw_event", drawEventHandler);
callbacks.Register("FireGameEvent", "translate_game_event", gameEventHandler);