--[[
    By JWBstuhr (Katherine S.) @ 2023

    Apologies for the terrible code. It's more a proof of concept than a final product.
    Just a simple Telnet client- specifically tested on ISCABBS via fTelnet.
]]--

-- BBS host address:
local address = {
    url = "bbs.iscabbs.com",
    port = 23,
}

--[[ Feel free to switch this to any of fTelnet's other servers:
    p-us-east (US East Coast)
    p-us-central (US Central)
    p-us-west (US West Coast)
    p-au (Australia)
    p-eu (Europe)
]]--
local nUrl = "wss://p-us-east.ftelnet.ca/".. address.url .."/".. address.port
-- Get ourselves that lovely fTelnet websocket
local n = http.websocket(nUrl)

local cfg = {
    termType = "ansi", -- Completely unused.
    -- Little goofy Telnet negotiation messages. I only prepared for ISCABBS.
    -- Also, ISCABBS is a cunt and refuses to acknowledge the 51 char page size, so I'm halving the height to account for possible newlines.
    msg1 = "\255\252\36".."\255\252\1".."\255\251\31".."\255\250\31\0\51\0\9\255\240".."\255\252\44",
    msg2 = "\255\253\3".."\255\251\46".."\255\251\8".."\255\250\8\51\255\240",
}
-- Thingy for counting MSGs sent for negotiation. Completely arbitrary, as this client can't actually negotiate.
local state = 0

-- Special chars: carriage return and "backspace".
local nKeys = {
    kenter = "\10",
    kbackspace = "\x08\x20\x08",
}

-- Please excuse my extremely lazy hack for checking the ends of ANSI codes.
local ansiQs = {
    A = true, B = true, C = true, D = true, E = true,
    F = true, G = true, H = true, J = true, K = true,
    S = true, T = true, f = true, m = true, i = true
}

-- ANSI color mapping. Anything not in this category gets set to white.
local ansiColors = {
    c0 = colors.white,
    c30 = colors.black,
    c31 = colors.red,
    c32 = colors.lime,
    c33 = colors.yellow,
    c34 = colors.blue,
    c35 = colors.magenta,
    c36 = colors.lightBlue,
    c37 = colors.white,

}

-- Hehehe I got a little lazy.
local function ansiPrint(text)
    local splits = {} -- Text splits of strings and ANSI codes
    local cmdstr = false -- Are we reading an IAC SB string?
    local buffer = 0 -- How many chars to skip?
    local ansistr = false -- Are we reading an ANSI code?
    local concat = "" -- Concatenation!
    for n=1,#text do
        local str = text:sub(n,n)
        if buffer == 0 then -- If not skipping,
            if str == "\255" then -- If IAC,
                table.insert(splits,concat) -- Reset concat and wait default buffer
                buffer = 2
                concat = ""
                if text:sub(n+1,n+1) == "\250" then -- SB? Start
                    cmdstr = true
                elseif text:sub(n+1,n+1) == "\240" then -- SE? End
                    cmdstr = false
                    buffer = 1
                end
            elseif cmdstr ~= true then -- If not reading IAC SB
                if str == "\x1b" then -- Check for ANSI code header
                    table.insert(splits,concat) -- Reset concat
                    concat = "\x1b"
                    ansistr = true
                    buffer = 1
                elseif ansistr and ansiQs[str] ~= nil then -- End ANSI code
                    concat = concat .. str
                    table.insert(splits,concat) -- Reset concat
                    concat = ""
                    ansistr = false
                else
                    if ansistr ~= true and str == "\8" then -- Backspace checking! I made a "custom ANSI code" that's just using the same lazy system to execute a series of commands that indicates a backspace.
                        table.insert(splits,concat)
                        table.insert(splits,"\x1bd")
                        concat = ""
                    else
                        concat = concat .. str
                    end
                end
            end
        else
            buffer = buffer - 1
        end
    end
    table.insert(splits,concat)
    -- Create a debug file to see what's being split:
    -- local f = fs.open("teleStr.txt","w")
    -- f.write(textutils.serialize(splits))
    -- f.close()

    -- Fun time!! Let's read out the splits
    for _,d in ipairs(splits) do
        if d:sub(1,1) == "\x1b" then -- Is ANSI?
            if d:sub(-1) == "J" then -- Clear screen
                term.clear()
                term.setCursorPos(1,1)
            end
            if d:sub(-1) == "B" then -- Scroll lines
                --term.scroll(tonumber(d:sub(2,-2))) --I wanna read my ISCABBS logout comments. Stop force scrolling me 255.
            end
            if d == "\x1bd" then -- CUSTOM: backspace
                local cx,cy = term.getCursorPos()
                if cx ~= 0 then
                    term.setCursorPos(cx-1,cy)
                else
                    term.setCursorPos(51,cy-1)
                end
            end
            if d:sub(-1) == "m" then -- Set color
                if ansiColors["c"..d:sub(2,-2)] ~= nil then
                    term.setTextColor(ansiColors["c"..d:sub(2,-2)])
                else
                    term.setTextColor(colors.white)
                end
            end
            if d == "\x1b1;1f" then -- Specifically set cursor to 1,1 position
                term.setCursorPos(1,1)
            end
        else
            io.write(d) -- print() with escapes but without newline
        end
    end
end

--[[
    I originally used this entire function for EARLY EARLY debugging to log myself into ISCABBS since I couldn't use capitals and hadn't thought of a way to time the telnet negotiations.
]]--

local function keyCheck()
    while true do
        local e,k,p = os.pullEvent("key")
        if e == "key" then
            local k = keys.getName(k)
--             if state == 2 then
            if nKeys["k"..k] ~= nil and state > 5 then -- Handle backspace and enter, basically
                n.send(nKeys["k"..k],false)
            end
--             end
--             if k == "l" and state == 1 then -- Force early disconnect
--                 n.close()
--                 print("Closed!")
--                 break
--             end
--             if k == "one" and state == 1 then -- First negotiation message
--                 --print(cfg.msg1)
--                 print("C[Negotiate 1]")
--                 n.send(cfg.msg1)
--             end
--             if k == "two" and state == 1 then -- Second negotiation message
--                 --print(cfg.msg2)
--                 print("C[Negotiate 2]")
--                 n.send(cfg.msg2)
--             end
--             if k == "three" and state == 1 then -- Login details
--                 print("C[Login Sent]")
--                 n.send("USERNAME\10".."PASSWORD\10".."Y",false)
--             end
--             if k == "four" and state == 1 then -- Disable these special functions
--                 print("Switched to Standard Keyboard.")
--                 state = 2
--             end
        end
    end
end

-- Check *CHARACTERS*. This way I don't have to deal with that leftShift shit
local function charCheck()
    while true do
        local e,ch = os.pullEvent("char")
        if e == "char" and state > 5 then
            -- Heads-up, this state > 5 condition was pulled out of my ass. 1) Connecting 2) Connected 3) Server Negotiation 4) Server Reply 5) Logon screen
            -- Again, I made this specifically for ISCABBS.
            n.send(ch,false)
        end
    end
end

local function render() -- Is secretly the websocket receive function, not the render function. Shhhh.
    --local nO = ""
    while true do
        local evt, url, nN = os.pullEvent("websocket_message")
        if evt == "websocket_message" then
            state = state + 1 -- New dumb thing! Re-use state var to count messages received to handle automatic negotiations. I guess.
            ansiPrint(nN) -- ANSI Print handles this now, no need for the print types below.
            --print(nN)
            --io.write(nN)
            if state == 3 then -- "Automatic" "Negotiation" (Send pre-written Telnet negotiation strings and ignore responses)
                n.send(cfg.msg1,false)
                print("Negotiated [1]")
            elseif state == 4 then
                n.send(cfg.msg2,false)
                print("Negotiated [2]")
            end
        end
    end
    --sleep(0.01) Why is this here?? This isn't even in the WHILE loop. SMH.
end

local function checkEnd() -- Handles server disconnection. I suppose.
    while true do
        local evt, url = os.pullEvent("websocket_closed")
        if evt == "websocket_closed" and url == nUrl then
            term.scroll(1)
            sleep(5) -- As I said, I wanna read my ISCABBS logout comment.
            term.scroll(254)
            print("Disconnected!")
            break
        end
    end
end

-- This is basically where the program starts.
term.clear()
term.setCursorPos(1,1)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
parallel.waitForAny(keyCheck,charCheck,render,checkEnd)