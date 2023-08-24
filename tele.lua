local address = {
    url = "bbs.iscabbs.com",
    port = 23,
}

local nUrl = "wss://p-us-central.ftelnet.ca/".. address.url .."/".. address.port
local n = http.websocket(nUrl)

local cfg = {
    termType = "ansi",
    msg1 = "\255\252\36".."\255\252\1".."\255\251\31".."\255\250\31\0\51\0\9\255\240".."\255\252\44",
    msg2 = "\255\253\3".."\255\251\46".."\255\251\8".."\255\250\8\51\255\240",
}
local state = 1

local nKeys = {
    kenter = "\10",
    kbackspace = "\x08\x20\x08",
}

local ansiQs = {
    A = true, B = true, C = true, D = true, E = true,
    F = true, G = true, H = true, J = true, K = true,
    S = true, T = true, f = true, m = true, i = true
}

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

local function ansiPrint(text)
    local splits = {}
    local cmdstr = false
    local buffer = 0
    local ansistr = false
    local concat = ""
    for n=1,#text do
        local str = text:sub(n,n)
        if buffer == 0 then
            if str == "\255" then
                table.insert(splits,concat)
                buffer = 2
                concat = ""
                if text:sub(n+1,n+1) == "\250" then
                    cmdstr = true
                elseif text:sub(n+1,n+1) == "\240" then
                    cmdstr = false
                    buffer = 1
                end
            elseif cmdstr ~= true then
                if str == "\x1b" then
                    table.insert(splits,concat)
                    concat = "\x1b"
                    ansistr = true
                    buffer = 1
                elseif ansistr and ansiQs[str] ~= nil then
                    concat = concat .. str
                    table.insert(splits,concat)
                    concat = ""
                    ansistr = false
                else
                    if ansistr ~= true and str == "\8" then
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
    local f = fs.open("teleStr.txt","w")
    f.write(textutils.serialize(splits))
    f.close()

    for _,d in ipairs(splits) do
        if d:sub(1,1) == "\x1b" then
            if d:sub(-1) == "J" then
                term.clear()
                term.setCursorPos(1,1)
            end
            if d:sub(-1) == "B" then
                --term.scroll(tonumber(d:sub(2,-2))) --I wanna read my ISCABBS logout comments
            end
            if d == "\x1bd" then
                local cx,cy = term.getCursorPos()
                if cx ~= 0 then
                    term.setCursorPos(cx-1,cy)
                else
                    term.setCursorPos(51,cy-1)
                end
            end
            if d:sub(-1) == "m" then
                if ansiColors["c"..d:sub(2,-2)] ~= nil then
                    term.setTextColor(ansiColors["c"..d:sub(2,-2)])
                else
                    term.setTextColor(colors.white)
                end
            end
            if d == "\x1b1;1f" then
                term.setCursorPos(1,1)
            end
        else
            io.write(d)
        end
    end
end

local function keyCheck()
    while true do
        local e,k,p = os.pullEvent("key")
        if e == "key" then
            local k = keys.getName(k)
            if state == 2 then
                if nKeys["k"..k] ~= nil then
                    n.send(nKeys["k"..k],false)
                end
            end
            if k == "l" and state == 1 then
                n.close()
                print("Closed!")
                break
            end
            if k == "one" and state == 1 then
                --print(cfg.msg1)
                print("C[Negotiate 1]")
                n.send(cfg.msg1)
            end
            if k == "two" and state == 1 then
                --print(cfg.msg2)
                print("C[Negotiate 2]")
                n.send(cfg.msg2)
            end
            if k == "three" and state == 1 then
                print("C[Login Sent]")
                n.send("USERNAME\10".."PASSWORD\10".."Y",false)
            end
            if k == "four" and state == 1 then
                print("Switched to Standard Keyboard.")
                state = 2
            end
        end
    end
end

local function charCheck()
    while true do
        local e,ch = os.pullEvent("char")
        if e == "char" and state == 2 then
            n.send(ch,false)
        end
    end
end

local function render()
    --local nO = ""
    while true do
        local evt, url, nN = os.pullEvent("websocket_message")
        if evt == "websocket_message" then
            local f = fs.open("teleMsg.txt","r")
            local rF = f.readAll()
            f.close()
            local f = fs.open("teleMsg.txt","w")
            f.write(rF .. nN)
            f.close()
            ansiPrint(nN)
            --print(nN)
            --io.write(nN)
        end
    end
    sleep(0.01)
end

local function checkEnd()
    while true do
        local evt, url = os.pullEvent("websocket_closed")
        if evt == "websocket_closed" and url == nUrl then
            term.scroll(1)
            sleep(5)
            term.scroll(254)
            print("Disconnected!")
            break
        end
    end
end

term.clear()
term.setCursorPos(1,1)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
parallel.waitForAny(keyCheck,charCheck,render,checkEnd)
