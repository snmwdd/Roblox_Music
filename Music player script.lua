local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

local LOCAL = Players.LocalPlayer
if not LOCAL then error("Music: LocalPlayer not available") end

local GENV = _G
if type(GENV.__OpaiMusicSUNCStop) == "function" then
    pcall(GENV.__OpaiMusicSUNCStop)
end

local ACCENT = Color3.fromRGB(255, 180, 170)
local GREEN = Color3.fromRGB(153, 237, 50)
local BG = Color3.fromRGB(30, 30, 30)
local SURFACE = Color3.fromRGB(45, 45, 45)
local MUTED = Color3.fromRGB(145, 145, 145)
local WHITE = Color3.fromRGB(237, 237, 237)
local BAD = Color3.fromRGB(245, 125, 131)
local REQUEST = (type(request) == "function" and request)
    or (type(http_request) == "function" and http_request)
    or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
local FILE_ASSET = (type(getcustomasset) == "function" and getcustomasset)
    or (type(getsynasset) == "function" and getsynasset)

local ROOT = "OpaiMusicSUNC"
local CONFIG_PATH = ROOT .. "/settings.json"
local DEFAULT_PATH = "OpaiMusicSUNC_settings.json"
local STORAGE_OK = type(writefile) == "function" and type(readfile) == "function"
    and type(isfile) == "function"
local ROOT_OK = false
if STORAGE_OK and type(makefolder) == "function" then
    pcall(function()
        if type(isfolder) == "function" and isfolder(ROOT) then
            ROOT_OK = true
        else
            makefolder(ROOT)
            ROOT_OK = true
        end
    end)
end
if not ROOT_OK then CONFIG_PATH = DEFAULT_PATH end

local function tryRead(path)
    if not STORAGE_OK then return nil end
    local ok, data = pcall(function()
        if isfile(path) then return readfile(path) end
    end)
    return ok and data or nil
end
local function saveText(path, data)
    if not STORAGE_OK then return false end
    local ok = pcall(writefile, path, data)
    return ok
end
local function decodeJSON(data)
    if type(data) ~= "string" or data == "" then return nil end
    local ok, obj = pcall(function() return HttpService:JSONDecode(data) end)
    return ok and obj or nil
end
local function clean(s, max)
    s = tostring(s or ""):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
    local limit = max or 300
    local valid,count = pcall(utf8.len, s)
    if not valid or not count then return (s:gsub("[\128-\255]", "?")):sub(1, limit) end
    local ok, cut = pcall(utf8.offset, s, limit + 1)
    if ok then return cut and s:sub(1, cut - 1) or s end
    -- Malformed external metadata must not break the render loop.
    return (s:gsub("[\128-\255]", "?")):sub(1, limit)
end
local function clamp(n, lo, hi)
    return math.max(lo, math.min(hi, n))
end
local function clock(secs)
    secs = math.max(0, math.floor(tonumber(secs) or 0))
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end
local function tween(object, properties, seconds)
    local t = TweenService:Create(object, TweenInfo.new(seconds or .18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
    t:Play()
    return t
end
local function rounded(object, radius)
    local x = Instance.new("UICorner")
    x.CornerRadius = UDim.new(0, radius or 12)
    x.Parent = object
    return x
end
local function stroke(object, color, opacity)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(83, 88, 95)
    s.Transparency = opacity or .65
    s.Thickness = 1
    s.Parent = object
    return s
end
local function frame(parent, pos, size, color, radius)
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.BackgroundColor3 = color or SURFACE
    f.Position = pos
    f.Size = size
    f.Parent = parent
    if radius then rounded(f, radius) end
    return f
end
local UI = {fonts = {}, textNodes = setmetatable({}, {__mode = "k"}),
    panelBaseScale = 1, panelEpoch = 0, fps = 60}
local function applyFont(label)
    local hasCJK = false
    pcall(function()
        for _, cp in utf8.codes(label.Text) do
            if cp >= 0x2E80 then hasCJK = true; break end
        end
    end)
    label.FontFace = (hasCJK and UI.fonts.cjk or UI.fonts.latin) or Font.fromEnum(Enum.Font.ArialBold)
end
local function bindFont(label)
    UI.textNodes[label] = true
    applyFont(label)
    label:GetPropertyChangedSignal("Text"):Connect(function() applyFont(label) end)
end
local function text(parent, value, pos, size, fontSize, color, bold)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Position = pos
    t.Size = size
    t.Font = Enum.Font.ArialBold
    t.Text = value or ""
    t.TextSize = fontSize or 13
    t.TextColor3 = color or WHITE
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextYAlignment = Enum.TextYAlignment.Center
    t.TextTruncate = Enum.TextTruncate.AtEnd
    t.Parent = parent
    bindFont(t)
    return t
end
local function button(parent, value, pos, size, color, fg)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.BorderSizePixel = 0
    b.BackgroundColor3 = color or SURFACE
    b.Position = pos
    b.Size = size
    b.Font = Enum.Font.ArialBold
    b.TextSize = 13
    b.Text = value
    b.TextColor3 = fg or WHITE
    b.Parent = parent
    bindFont(b)
    rounded(b, 9)
    local spring = Instance.new("UIScale")
    spring.Name="OpaiButtonMotion"
    spring.Parent=b
    b.MouseEnter:Connect(function()
        tween(b, {BackgroundTransparency = .12}, .13)
        tween(spring, {Scale=1.035}, .18)
    end)
    b.MouseLeave:Connect(function()
        tween(b, {BackgroundTransparency = 0}, .18)
        tween(spring, {Scale=1}, .18)
    end)
    b.Activated:Connect(function()
        tween(spring, {Scale=.91}, .07)
        task.delay(.08, function() if b.Parent then tween(spring,{Scale=1.0},.24) end end)
    end)
    return b
end
local function textbox(parent, placeholder, pos, size, multiline)
    local b = Instance.new("TextBox")
    b.ClearTextOnFocus = false
    b.MultiLine = multiline == true
    b.TextWrapped = multiline == true
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    b.PlaceholderText = placeholder
    b.PlaceholderColor3 = MUTED
    b.Text = ""
    b.TextColor3 = WHITE
    b.Font = Enum.Font.ArialBold
    b.TextSize = 13
    b.BackgroundColor3 = SURFACE
    b.BorderSizePixel = 0
    b.Position = pos
    b.Size = size
    b.Parent = parent
    bindFont(b)
    rounded(b, 9)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 9)
    if multiline then pad.PaddingTop = UDim.new(0, 10) end
    pad.Parent = b
    return b
end

local stored = decodeJSON(tryRead(CONFIG_PATH)) or {}
UI.favorites=type(stored.favorites)=="table" and stored.favorites or {}
local queue = {}
if type(stored.queue) == "table" then
    for _, v in ipairs(stored.queue) do
        if #queue >= 60 then break end
        if type(v) == "table" and type(v.kind) == "string" and type(v.value) == "string" then
            table.insert(queue, {
                kind = v.kind, value = v.value, title = clean(v.title, 80),
                artist = clean(v.artist, 60), source = clean(v.source, 20),
                lyricId = clean(v.lyricId, 128), lyrics = type(v.lyrics) == "string" and v.lyrics or "",
                translation = type(v.translation)=="string" and v.translation or "",
                yrc = type(v.yrc)=="string" and v.yrc or "",
                picId = clean(v.picId,4096), cover = clean(v.cover,4096),
                metadataCover=clean(v.metadataCover,4096),customCover=v.customCover==true,
            })
        end
    end
end
local volume = clamp(tonumber(stored.volume) or .45, 0, 1)
local hudSettings = type(stored.hud) == "table" and stored.hud or {}
local function hudEnabled(key, default)
    if type(hudSettings[key]) == "boolean" then return hudSettings[key] end
    return default
end
local lyricDistance = clamp(tonumber(hudSettings.distance) or 10, 3, 40)
local repeatOne = stored.repeatOne == true
local gdSource = (stored.gdSource == "joox" or stored.gdSource == "bilibili") and stored.gdSource or "netease"
local index = tonumber(stored.index) or 0
if index < 1 or index > #queue then index = 0 end
local alive = true
local sound = nil
local generation = 0
local currentLyrics = {}
local currentTranslations = {}
local mode = "queue"
local searchResults = {}
local panelVisible = false
local busy = false
local status = "输入音频地址，或搜索 GD 音乐台"
local statusColor = MUTED
local lastStatusAt = 0
local connections = {}

local function persist()
    local shallow = {}
    for _, song in ipairs(queue) do
        table.insert(shallow, {
            kind = song.kind, value = song.value, title = song.title,
            artist = song.artist, source = song.source,
            lyricId = song.lyricId, lyrics = song.lyrics, translation = song.translation, yrc = song.yrc,
            picId = song.picId, cover = song.cover, metadataCover=song.metadataCover,customCover=song.customCover,
        })
    end
    local ok, body = pcall(function()
        return HttpService:JSONEncode({queue = shallow, volume = volume,
            repeatOne = repeatOne, gdSource = gdSource, index = index, hud = hudSettings, favorites=UI.favorites})
    end)
    if ok then saveText(CONFIG_PATH, body) end
end

-- Media addresses may be protocol-relative, or an image URL stored as pic_id.
-- Keep IDs intact; a track ID is never substituted for a missing picture ID.
local function mediaURL(value)
    local value=clean(value,4096):gsub("&amp;","&"):gsub("\\/","/")
    if value:sub(1,2)=="//" then value="https:"..value end
    if value:match("^http://") then value="https://"..value:sub(8) end
    return value
end
local function httpGet(url)
    if not REQUEST then return nil,"当前环境没有网络请求接口" end
    url=mediaURL(url)
    for redirects=0,3 do
        if not url:match("^https://[%w%._%-]+") then return nil,"下载地址必须是 HTTPS" end
        local ok,response=pcall(REQUEST,{Url=url,Method="GET",Headers={
            ["User-Agent"]="InfiniteSkidded-Music/3.0",["Accept"]="*/*"}})
        if not ok then return nil,"网络请求失败："..clean(response,110) end
        if type(response)~="table" then return nil,"网络请求没有返回响应" end
        local code=tonumber(response.StatusCode or response.Status or 0) or 0
        local headers=response.Headers or response.headers or {}
        if code>=200 and code<300 then return response.Body or response.body,nil,headers,code end
        local location=headers.Location or headers.location
        if (code==301 or code==302 or code==303 or code==307 or code==308) and type(location)=="string" and redirects<3 then
            if location:sub(1,2)=="//" then url=mediaURL(location)
            elseif location:sub(1,1)=="/" then url=(url:match("^(https://[^/]+)") or "")..location
            elseif location:match("^https?://") then url=mediaURL(location)
            else
                local directory=(url:match("^(.-)[?#]") or url):match("^(.*)/")
                if not directory then return nil,"无效的图片跳转地址",headers,code end
                url=directory.."/"..location
            end
        else
            return nil,"HTTP "..code,headers,code
        end
    end
    return nil,"跳转次数过多"
end

local function gdAPI(parameters)
    local items = {}
    for k, v in pairs(parameters) do
        table.insert(items, tostring(k) .. "=" .. HttpService:UrlEncode(tostring(v)))
    end
    table.sort(items)
    local raw, err = httpGet("https://music-api.gdstudio.xyz/api.php?" .. table.concat(items, "&"))
    if not raw then return nil, err end
    local data = decodeJSON(raw)
    if type(data) ~= "table" then return nil, "音乐服务返回了无效 JSON" end
    return data
end
local function audioExtension(url, headers, preferred)
    local ext = tostring(preferred or ""):lower()
    if ext == "mp3" or ext == "wav" or ext == "ogg" then return ext end
    local cleanURL = tostring(url):lower():match("^[^?#]+") or tostring(url):lower()
    local ending = cleanURL:match("%.([%a%d]+)$")
    if ending == "mp3" or ending == "wav" or ending == "ogg" then return ending end
    local mime = tostring(headers["Content-Type"] or headers["content-type"] or ""):lower()
    if mime:find("ogg", 1, true) then return "ogg" end
    if mime:find("wav", 1, true) then return "wav" end
    return "mp3"
end
local function keyFor(input)
    local h = 5381
    for n = 1, #input do
        h = (h * 33 + string.byte(input, n)) % 4294967296
    end
    return string.format("%08x", h)
end
local function convertToSoundId(song)
    if song.kind == "asset" then
        local assetId = tostring(song.value):match("(%d+)")
        if not assetId then return nil, "无效 Roblox Sound ID" end
        return "rbxassetid://" .. assetId
    elseif song.kind == "file" then
        if not FILE_ASSET or not STORAGE_OK then return nil, "缺少 getcustomasset 或文件系统接口" end
        if not isfile(song.value) then return nil, "找不到本地音频文件：" .. song.value end
        local ok, id = pcall(FILE_ASSET, song.value)
        if ok then return id end
        return nil, "getcustomasset 未能加载该文件"
    elseif song.kind == "url" or song.kind == "gd" then
        if not FILE_ASSET or not STORAGE_OK then return nil, "下载音频需要 writefile、isfile、getcustomasset" end
        local url = song.value
        local preferred = ""
        if song.kind == "gd" then
            local data, err = gdAPI({types = "url", source = song.source or gdSource, id = song.value, br = 320})
            if not data then return nil, err end
            url = tostring(data.url or "")
            preferred = tostring(data.type or "")
            if url == "" then return nil, "当前音源没有可播放的文件（可能需要版权授权）" end
            if preferred == "flac" or preferred == "aac" or preferred == "m4a" then
                return nil, "当前 SUNC 播放器不支持 " .. preferred .. "；请更换 MP3/OGG/WAV 音源"
            end
        end
        url=mediaURL(url)
        if not tostring(url):match("^https://") then return nil, "音频源必须是 HTTPS 直链" end
        local basename = (ROOT_OK and (ROOT .. "/") or "OpaiMusic_") .. keyFor(url)
        local location = nil
        for _, extension in ipairs({"mp3", "ogg", "wav"}) do
            if isfile(basename .. "." .. extension) then
                location = basename .. "." .. extension
                break
            end
        end
        if not location then
            local raw, err, headers, code = httpGet(url)
            if not raw and code==404 and song.kind=="gd" then
                local fresh=gdAPI({types="url",source=song.source or gdSource,id=song.value,br=320})
                local freshURL=type(fresh)=="table" and mediaURL(fresh.url or "") or ""
                if freshURL~="" and freshURL~=url then
                    url=freshURL;preferred=tostring(fresh.type or preferred)
                    raw,err,headers=httpGet(url)
                end
            end
            if not raw then return nil, err end
            if type(raw) ~= "string" or #raw == 0 then return nil, "收到空音频文件" end
            if #raw > 28 * 1024 * 1024 then return nil, "文件超过 28 MB 限制，改用本地文件导入" end
            local prefix=raw:sub(1,200):lower():gsub("^%s+","")
            if prefix:sub(1,1)=="<" or prefix:sub(1,1)=="{" then return nil,"音频地址返回了网页或错误信息，请重新搜索曲目" end
            if raw:sub(1,4)=="fLaC" or raw:sub(5,8)=="ftyp" then return nil,"当前音源返回 FLAC/M4A，当前本地播放器需要 MP3、OGG 或 WAV" end
            local suffix = audioExtension(url, headers or {}, preferred)
            location = basename .. "." .. suffix
            if not saveText(location, raw) then return nil, "无法保存音频文件到执行器目录" end
        end
        local ok, id = pcall(FILE_ASSET, location)
        if not ok then return nil, "getcustomasset 无法读取下载的音频" end
        return id
    end
    return nil, "不支持的音源类型"
end

local function parseLyrics(raw)
    local result = {}
    for line in tostring(raw or ""):gmatch("[^\r\n]+") do
        local caption = line:gsub("%[%d+:%d+%.?%d*%]", "")
        caption = clean(caption, 150)
        if caption ~= "" then
            for mins, secs, fraction in line:gmatch("%[(%d+):(%d+)%.?(%d*)%]") do
                local ms = tonumber(fraction) or 0
                if #fraction == 1 then ms = ms / 10
                elseif #fraction == 2 then ms = ms / 100
                elseif #fraction > 2 then ms = ms / (10 ^ #fraction) end
                table.insert(result, {at = tonumber(mins) * 60 + tonumber(secs) + ms, text = caption})
            end
        end
    end
    table.sort(result, function(a, b) return a.at < b.at end)
    return result
end

-- NCM YRC word timing: [lineStartMs,lineDurationMs](startMs,durationMs,0)word...
-- Both absolute and line-relative word start formats are accepted.
local function parseYrc(raw)
    local result={}
    for line in tostring(raw or ""):gmatch("[^\r\n]+") do
        local ms,duration,body=line:match("^%[(%d+),(%d+)%](.*)$")
        if ms then
            local start=tonumber(ms)/1000
            local length=tonumber(duration)/1000
            local words={}
            local all={}
            for when,howLong,word in body:gmatch("%((%d+),(%d+),%d+%)([^%(]*)") do
                local w=tonumber(when)/1000
                if w < start-1 then w=w+start end
                local item={at=w,duration=tonumber(howLong)/1000,text=clean(word,140)}
                table.insert(words,item)
                table.insert(all,item.text)
            end
            local textValue=clean(table.concat(all,""),230)
            if #words>0 and textValue~="" then
                table.insert(result,{at=start,duration=length,text=textValue,words=words})
            end
        end
    end
    table.sort(result,function(a,b) return a.at<b.at end)
    return result
end
local function parseSongLyrics(song)
    local yrc=parseYrc(song.yrc or "")
    return #yrc>0 and yrc or parseLyrics(song.lyrics or "")
end
local function richEscape(value)
    return tostring(value or ""):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;")
end
local function wordMarkup(cue,pos)
    if not cue or not cue.words or #cue.words==0 then return nil end
    local result={}
    local active=0
    for i,word in ipairs(cue.words) do
        local color="#959595"
        if pos>=word.at then color="#FFFFFF" end
        if pos>=word.at and pos<word.at+math.max(word.duration,.12) then
            color="#FFA392";active=i
        end
        table.insert(result,'<font color="'..color..'">'..richEscape(word.text)..'</font>')
    end
    return table.concat(result),active
end
local function matchingTranslation(lines,pos)
    local found=""
    for _,line in ipairs(lines) do
        if line.at>pos+.08 then break end
        found=line.text
    end
    return found
end

local Widgets={}
-- OpaiBounce SUNC Edition: layout mapped to src/opai/MusicPanel.svelte and Island.svelte
-- Independent world/HUD visualizations are generated locally; no Java native bridges.
local gui = Instance.new("ScreenGui")
gui.Name = "InfiniteSkiddedMusic"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 9999
-- Use only the executor-provided GUI container; do not fall back to PlayerGui.
if type(gethui) ~= "function" then return end
local gethuiOK, HIDDEN = pcall(gethui)
if not gethuiOK or typeof(HIDDEN) ~= "Instance" then return end
local previous = HIDDEN:FindFirstChild("InfiniteSkiddedMusic")
if previous then pcall(function() previous:Destroy() end) end
gui.Parent = HIDDEN

local DARK = Color3.fromRGB(10, 10, 10)
local PANEL = Color3.fromRGB(30, 30, 30)
local SIDEBAR = Color3.fromRGB(36, 36, 36)
local FOOTER = Color3.fromRGB(25, 25, 25)
local TRACKACTIVE = Color3.fromRGB(120, 73, 63)
local STRIP = Color3.fromRGB(57, 57, 57)

-- Native geometry only: modifiers belong to the surface they shade.
-- Composited alpha approximates a Gaussian falloff outside the rounded edge.
local function shadowFor(target,pad,alpha)
    local native=nil
    local ok=pcall(function()
        native=Instance.new("UIShadow")
        native.Name="OpaiNativeShadow"
        native.Mode=Enum.ApplyShadowMode.Shape
        native.BlurRadius=UDim.new(0,10)
        native.Spread=UDim2.fromOffset(3,3)
        native.Offset=UDim2.fromOffset(0,1)
        native.Color=Color3.new(0,0,0)
        native.Transparency=.36
        native.ShowBehindParent=false
        native.Parent=target
    end)
    if ok then return {native} end
    if native then native:Destroy() end
    local strokes={}
    local radius=16
    local sigma=5.5
    local strength=.5
    for extent=radius,1,-1 do
        local inner=strength*math.exp(-((extent-1)^2)/(2*sigma*sigma))
        local outer=extent==radius and 0 or strength*math.exp(-(extent^2)/(2*sigma*sigma))
        local opacity=clamp((inner-outer)/math.max(.001,1-outer),0,1)
        local line=Instance.new("UIStroke")
        line.Name="OpaiShadow_"..extent
        line.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        line.Color=Color3.new(0,0,0)
        line.Thickness=extent
        line.Transparency=1-opacity
        line.LineJoinMode=Enum.LineJoinMode.Round
        pcall(function() line.BorderStrokePosition=Enum.BorderStrokePosition.Outer end)
        pcall(function() line.ZIndex=-extent end)
        line.Parent=target
        strokes[#strokes+1]=line
    end
    return strokes
end

-- Original watermark is one low-profile horizontal capsule, not a tall two-row widget.
Widgets.island = frame(gui, UDim2.new(.5,-253,0,12), UDim2.fromOffset(506,43), DARK,23)
Widgets.island.AnchorPoint=Vector2.new(.5,0)
Widgets.island.Position=UDim2.new(.5,0,0,12)
Widgets.islandShadow,Widgets.islandShadowScale=shadowFor(Widgets.island,32,.55)
Widgets.island.ZIndex=20

Widgets.islandScale=Instance.new("UIScale")
Widgets.islandScale.Parent=Widgets.island
local function scaleIsland()
    if UI.editor then UI.editor.apply("island");return end
    local camera=workspace.CurrentCamera
    Widgets.islandScale.Scale=math.min(1,((camera and camera.ViewportSize.X) or 900)/700)

end
scaleIsland()
if workspace.CurrentCamera then table.insert(connections,workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(scaleIsland)) end
Widgets.island.Active = true
Widgets.island.BackgroundTransparency = .31
Widgets.islandLogo = text(Widgets.island,"◉",UDim2.fromOffset(14,0),UDim2.fromOffset(23,43),23,ACCENT,true)
-- Small native geometric icons; no sprite PNG, cached bitmap, or private font.
local Asset={icons=true}
local MUSIC_SPRITES={play=1,pause=2}
local function paintIcon(root,kind,color)
    for _,child in ipairs(root:GetChildren()) do child:Destroy() end
    root:SetAttribute("IconKind",kind)
    root:SetAttribute("IconTint",color)
    local function rect(x,y,w,h,r)
        local part=frame(root,UDim2.fromScale(x/24,y/24),UDim2.fromScale(w/24,h/24),color,r and r*root.Size.X.Offset/24)
        return part
    end
    local function line(x1,y1,x2,y2,width)
        local dx,dy=x2-x1,y2-y1
        local shape=rect((x1+x2)/2,(y1+y2)/2,math.sqrt(dx*dx+dy*dy),width or 1.8,.9)
        shape.AnchorPoint=Vector2.new(.5,.5)
        shape.Rotation=math.deg(math.atan2(dy,dx))
        return shape
    end
    local function arc(cx,cy,r,start,finish,width)
        local steps=math.max(6,math.ceil(math.abs(finish-start)/15))
        for i=1,steps do
            local a=math.rad(start+(finish-start)*(i-1)/steps)
            local b=math.rad(start+(finish-start)*i/steps)
            line(cx+math.cos(a)*r,cy+math.sin(a)*r,cx+math.cos(b)*r,cy+math.sin(b)*r,width)
        end
    end
    local function triangle(x,flip)
        for row=0,15 do
            local y=4+row
            local width=math.max(.8,12*(1-math.abs(y-11.5)/8))
            rect(flip and x+12-width or x,y,width,1.3)
        end
    end
    if kind=="dropdown" then line(5,9,12,16,1.8);line(12,16,19,9,1.8)
    elseif kind=="scale" then
        line(5,19,19,5,1.8);line(11,5,19,5,1.8);line(19,5,19,13,1.8);line(5,11,5,19,1.8);line(5,19,13,19,1.8)
    elseif kind=="rotate" then arc(12,12,7,-25,270,1.8);line(18,4,20,9,1.8);line(20,9,15,8,1.8)
    elseif kind=="play" then triangle(6,false)
    elseif kind=="pause" then rect(6,4,4,16,1);rect(14,4,4,16,1)
    elseif kind=="next" then triangle(4,false);rect(18,4,2,16,.5)
    elseif kind=="previous" then triangle(7,true);rect(4,4,2,16,.5)
    elseif kind=="note" then
        line(10,6,10,17,2);line(19,4,19,15,2);line(10,6,19,4,2.8)
        rect(4,15,7,5,3);rect(13,13,7,5,3)
    elseif kind=="search" then arc(10,10,6,0,360,1.8);line(14.5,14.5,20,20,2)
    elseif kind=="close" then line(6,6,18,18,1.8);line(18,6,6,18,1.8)
    elseif kind=="back" then line(14,5,7,12,2);line(7,12,14,19,2)
    elseif kind=="home" then line(3,11,12,4,1.8);line(12,4,21,11,1.8);line(6,9,6,20,1.8);line(18,9,18,20,1.8);line(6,20,18,20,1.8)
    elseif kind=="user" then rect(8,3,8,8,4);rect(4,14,16,8,4)
    elseif kind=="playlist" then for i=0,2 do rect(4,5+i*6,2,2,1);line(9,6+i*6,21,6+i*6,1.6) end
    elseif kind=="repeat" then
        line(6,6,19,6,1.8);line(19,6,16,3,1.8);line(19,6,16,9,1.8)
        line(18,18,5,18,1.8);line(5,18,8,15,1.8);line(5,18,8,21,1.8)
        arc(7,12,6,90,230,1.8);arc(17,12,6,-90,50,1.8)
    elseif kind=="volume" then
        rect(3,9,4,6,1);line(7,9,12,5,2);line(12,5,12,19,2);line(12,19,7,15,2)
        arc(12,12,6,-55,55,1.7);arc(12,12,9,-55,55,1.7)
    elseif kind=="gear" then
        arc(12,12,6,0,360,1.8);arc(12,12,2,0,360,1.5)
        for i=0,7 do local a=math.rad(i*45);line(12+math.cos(a)*6,12+math.sin(a)*6,12+math.cos(a)*9,12+math.sin(a)*9,2.6) end
    elseif kind=="heart" then
        arc(8,9,4,180,360,1.8);arc(16,9,4,180,360,1.8)
        line(4,9,12,20,1.8);line(20,9,12,20,1.8)
    elseif kind=="logo" then
        arc(12,12,9,0,360,2.2);arc(12,12,4,0,360,1.8)
        for i=0,2 do local a=math.rad(i*120-90);line(12+math.cos(a)*4,12+math.sin(a)*4,12+math.cos(a+.65)*9,12+math.sin(a+.65)*9,1.8) end
    else line(5,12,19,12,1.8) end
end
UI.setIcon=function(root,kind)
    if root:GetAttribute("IconKind")==kind then return end
    paintIcon(root,kind,root:GetAttribute("IconTint") or WHITE)
end
UI.tintIcon=function(root,color)
    paintIcon(root,root:GetAttribute("IconKind") or "note",color)
end
local function musicIcon(parent,kind,pos,size,tint)
    local root=frame(parent,pos,UDim2.fromOffset(size,size),WHITE)
    root.Name="VectorIcon_"..kind
    root.BackgroundTransparency=1
    paintIcon(root,kind,tint or WHITE)
    return root
end

Widgets.islandLogo.Visible=false
Widgets.island.Size=UDim2.fromOffset(430,46)
Widgets.islandInk=frame(Widgets.island,UDim2.fromOffset(18,0),UDim2.new(1,-36,1,0),DARK)
Widgets.islandInk.BackgroundTransparency=1
Widgets.islandInk.ClipsDescendants=true
local islandLayout=Instance.new("UIListLayout")
islandLayout.FillDirection=Enum.FillDirection.Horizontal
islandLayout.VerticalAlignment=Enum.VerticalAlignment.Center
islandLayout.SortOrder=Enum.SortOrder.LayoutOrder
islandLayout.Padding=UDim.new(0,7)
islandLayout.Parent=Widgets.islandInk
local function islandPart(value,size,color,width)
    local label=text(Widgets.islandInk,value,UDim2.new(),UDim2.fromOffset(width or 0,46),size,color,true)
    label.LayoutOrder=#Widgets.islandInk:GetChildren()
    return label
end
local function islandIcon(kind,color)
    local icon=musicIcon(Widgets.islandInk,kind,UDim2.new(),24,color)
    icon.LayoutOrder=#Widgets.islandInk:GetChildren()
    return icon
end
local logo=musicIcon(Widgets.islandInk,"logo",UDim2.new(),24,ACCENT)
logo.LayoutOrder=0
Widgets.islandLogo.Visible=false

Widgets.islandTitle=islandPart("Infinite Skidded",16,ACCENT,150)
Widgets.islandDot1=islandPart("·",16,WHITE,6)
Widgets.islandUserIcon=islandIcon("user",WHITE)
Widgets.islandUser=islandPart(clean(LOCAL.DisplayName,32),16,WHITE,96)
Widgets.islandDot2=islandPart("·",16,WHITE,6)
Widgets.islandNoteImage=islandIcon("note",GREEN)
Widgets.islandAction=islandPart("♫",19,GREEN,24)
Widgets.islandSub=islandPart("-- ms to Roblox",16,WHITE,180)
Widgets.islandFps=islandPart("·  60 fps",16,WHITE,80)
Widgets.islandProgress=frame(Widgets.island,UDim2.new(),UDim2.new(),GREEN)
Widgets.islandProgress.Visible=false
Widgets.islandFill=frame(Widgets.islandProgress,UDim2.new(),UDim2.new(),GREEN)

-- Source MusicPanel uses a light dim overlay, not a scene-wide BlurEffect.
Widgets.dim=frame(gui,UDim2.new(),UDim2.fromScale(1,1),Color3.new(0,0,0))
Widgets.dim.ZIndex=8
Widgets.dim.BackgroundTransparency=1
Widgets.dim.Visible=false
local panel = frame(gui, UDim2.fromScale(.5,.55), UDim2.fromOffset(906,566), PANEL,8)
panel.Name="MusicPanel"
panel.AnchorPoint=Vector2.new(.5,.5)
panel.ZIndex=10
Widgets.panelShadow,Widgets.panelShadowScale=shadowFor(panel,32,.55)
panel.ClipsDescendants=false
Widgets.panelScale=Instance.new("UIScale")
Widgets.panelScale.Parent=panel
local function scalePanel()
    if UI.layoutPanel then UI.layoutPanel() end
end

-- MusicPanel.svelte: sidebar + workspace + 76px transport + 20px credits.
local function scrollingSurface(parent,pos,size,color)
    local surface=Instance.new("ScrollingFrame")
    surface.BorderSizePixel=0
    surface.Position=pos;surface.Size=size;surface.BackgroundColor3=color
    surface.ScrollBarThickness=3
    surface.CanvasSize=UDim2.fromOffset(0,500)
    surface.Parent=parent
    return surface
end
local side=frame(panel,UDim2.new(),UDim2.fromOffset(240,564),SIDEBAR)
side.Name="Sidebar"
local top=frame(panel,UDim2.fromOffset(240,0),UDim2.fromOffset(800,38),PANEL)
local title=text(top,"Tritium Music",UDim2.fromOffset(12,0),UDim2.fromOffset(180,38),12,MUTED)
local lyricLine=text(top,"",UDim2.fromOffset(210,0),UDim2.fromOffset(400,38),12,MUTED)
lyricLine.TextXAlignment=Enum.TextXAlignment.Right
local minimize=button(top,"",UDim2.fromOffset(760,4),UDim2.fromOffset(30,30),PANEL,WHITE)
musicIcon(minimize,"close",UDim2.fromOffset(6,6),18,WHITE)
UI.settingsButton=button(top,"",UDim2.fromOffset(724,4),UDim2.fromOffset(30,30),PANEL,MUTED)
musicIcon(UI.settingsButton,"gear",UDim2.fromOffset(6,6),18,MUTED)

Widgets.searchBox=textbox(side,"搜索歌曲、歌手或专辑",UDim2.fromOffset(16,20),UDim2.fromOffset(208,36))
Widgets.searchBox.TextSize=12
Widgets.searchBox.BackgroundColor3=SIDEBAR
stroke(Widgets.searchBox,Color3.fromRGB(90,90,90),.25)
Widgets.searchButton=button(side,"",UDim2.fromOffset(188,23),UDim2.fromOffset(30,30),SIDEBAR,WHITE)
musicIcon(Widgets.searchButton,"search",UDim2.fromOffset(6,6),18,WHITE)
Widgets.sideTitle=text(side,"Tritium Music",UDim2.fromOffset(20,72),UDim2.fromOffset(200,20),14,MUTED)
Widgets.queueTab=button(side,"       主页",UDim2.fromOffset(12,104),UDim2.fromOffset(216,38),SIDEBAR,WHITE)
Widgets.queueTab.TextXAlignment=Enum.TextXAlignment.Left
musicIcon(Widgets.queueTab,"home",UDim2.fromOffset(12,10),18,WHITE)
UI.favoriteTab=button(side,"       本地收藏",UDim2.fromOffset(12,146),UDim2.fromOffset(216,38),SIDEBAR,WHITE)
UI.favoriteTab.TextXAlignment=Enum.TextXAlignment.Left
musicIcon(UI.favoriteTab,"heart",UDim2.fromOffset(12,10),18,WHITE)
UI.queueLabel=text(side,"播放列表",UDim2.fromOffset(20,203),UDim2.fromOffset(200,20),12,MUTED)
UI.queueNav=button(side,"       当前播放队列",UDim2.fromOffset(12,233),UDim2.fromOffset(216,38),SIDEBAR,WHITE)
UI.queueNav.TextXAlignment=Enum.TextXAlignment.Left
musicIcon(UI.queueNav,"playlist",UDim2.fromOffset(12,10),18,WHITE)
Widgets.resultTab=button(side,"       搜索结果",UDim2.fromOffset(12,275),UDim2.fromOffset(216,38),SIDEBAR,WHITE)
Widgets.resultTab.TextXAlignment=Enum.TextXAlignment.Left
musicIcon(Widgets.resultTab,"search",UDim2.fromOffset(12,10),18,WHITE)
UI.navLabels={}
local function navLabel(control,label)
    control.Text=""
    local node=text(control,label,UDim2.fromOffset(44,0),UDim2.new(1,-54,1,0),13,WHITE)
    UI.navLabels[control]=node
end
navLabel(Widgets.queueTab,"主页")
navLabel(UI.favoriteTab,"本地收藏")
navLabel(UI.queueNav,"当前播放队列")
navLabel(Widgets.resultTab,"搜索结果")
Widgets.sideBottom=text(side,"GD 音乐台",UDim2.fromOffset(48,516),UDim2.fromOffset(174,32),13,WHITE)
UI.profileIcon=musicIcon(side,"user",UDim2.fromOffset(18,520),24,MUTED)

Widgets.hero=frame(panel,UDim2.fromOffset(268,50),UDim2.fromOffset(744,210),PANEL)
Widgets.heroCover=frame(Widgets.hero,UDim2.new(),UDim2.fromOffset(210,210),Color3.fromRGB(50,39,46),9)
Widgets.heroGradient=Instance.new("UIGradient")
Widgets.heroGradient.Color=ColorSequence.new(Color3.fromRGB(87,55,71),Color3.fromRGB(30,49,56))
Widgets.heroGradient.Rotation=145
Widgets.heroGradient.Parent=Widgets.heroCover
Widgets.heroSymbol=text(Widgets.heroCover,"♫",UDim2.new(),UDim2.fromScale(1,1),64,ACCENT,true)
Widgets.heroSymbol.TextXAlignment=Enum.TextXAlignment.Center
local heading=text(Widgets.hero,"我的音乐",UDim2.fromOffset(236,26),UDim2.fromOffset(480,42),28,WHITE)
Widgets.heroSubtitle=text(Widgets.hero,"搜索并选择一首歌曲开始播放",UDim2.fromOffset(236,75),UDim2.fromOffset(480,20),12,MUTED)
Widgets.heroMeta=text(Widgets.hero,"GD 音乐台",UDim2.fromOffset(236,112),UDim2.fromOffset(480,24),14,WHITE)
Widgets.heroPlay=button(Widgets.hero,"      播放全部",UDim2.fromOffset(236,158),UDim2.fromOffset(120,36),ACCENT,Color3.fromRGB(57,16,12))
musicIcon(Widgets.heroPlay,"play",UDim2.fromOffset(12,10),16,Color3.fromRGB(57,16,12))
local list=Instance.new("ScrollingFrame")
list.Name="Songs"
list.BorderSizePixel=0
list.BackgroundTransparency=1
list.ScrollBarThickness=3
list.ScrollBarImageColor3=Color3.fromRGB(90,85,84)
list.CanvasSize=UDim2.new()
list.Position=UDim2.fromOffset(268,290)
list.Size=UDim2.fromOffset(744,240)
list.Parent=panel
Widgets.listLayout=Instance.new("UIListLayout")
Widgets.listLayout.Padding=UDim.new(0,3)
Widgets.listLayout.SortOrder=Enum.SortOrder.LayoutOrder
Widgets.listLayout.Parent=list
Widgets.statusLabel=text(panel,"",UDim2.fromOffset(268,536),UDim2.fromOffset(744,20),11,MUTED)

Widgets.footer=frame(panel,UDim2.fromOffset(0,564),UDim2.fromOffset(1040,76),FOOTER)
Widgets.credits=frame(panel,UDim2.fromOffset(0,640),UDim2.fromOffset(1040,20),FOOTER)
Widgets.creditText=text(Widgets.credits,"GD 音乐台 · CC BY-NC 4.0 · 仅供非商业学习 / OpaiBounce · GPL-3.0",UDim2.fromOffset(22,0),UDim2.new(1,-44,1,0),9,MUTED)
Widgets.creditText.TextXAlignment=Enum.TextXAlignment.Right
local album=frame(Widgets.footer,UDim2.fromOffset(22,14),UDim2.fromOffset(48,48),Color3.fromRGB(48,48,48),5)
Widgets.albumText=text(album,"♫",UDim2.new(),UDim2.fromScale(1,1),24,ACCENT,true)
Widgets.albumText.TextXAlignment=Enum.TextXAlignment.Center
Widgets.trackName=text(Widgets.footer,"尚未播放",UDim2.fromOffset(80,19),UDim2.fromOffset(195,20),13,WHITE)
Widgets.trackArtist=text(Widgets.footer,"Tritium Music",UDim2.fromOffset(80,44),UDim2.fromOffset(195,16),11,MUTED)
UI.transport=frame(Widgets.footer,UDim2.fromOffset(320,0),UDim2.fromOffset(420,76),FOOTER)
local function transportButton(kind,x)
    local control=button(UI.transport,"",UDim2.fromOffset(x,4),UDim2.fromOffset(32,32),FOOTER,WHITE)
    local icon=musicIcon(control,kind,UDim2.fromOffset(6,6),20,WHITE)
    return control,icon
end
Widgets.previous=transportButton("previous",92)
Widgets.playButton,Widgets.playIcon=transportButton("play",144)
Widgets.nextButton=transportButton("next",196)
Widgets.loopButton,Widgets.loopIcon=transportButton("repeat",248)
Widgets.seekBack=frame(UI.transport,UDim2.fromOffset(40,51),UDim2.fromOffset(280,3),Color3.fromRGB(78,78,78),2)
Widgets.seekFill=frame(Widgets.seekBack,UDim2.new(),UDim2.fromScale(0,1),Color3.fromRGB(221,221,221),2)
Widgets.seekButton=button(Widgets.seekBack,"",UDim2.fromOffset(0,-9),UDim2.new(1,0,0,22),WHITE)
Widgets.seekButton.BackgroundTransparency=1
Widgets.elapsedLabel=text(UI.transport,"0:00",UDim2.fromOffset(0,42),UDim2.fromOffset(32,20),10,MUTED)
Widgets.elapsedLabel.TextXAlignment=Enum.TextXAlignment.Center
Widgets.durationLabel=text(UI.transport,"—:—",UDim2.fromOffset(328,42),UDim2.fromOffset(32,20),10,MUTED)
Widgets.durationLabel.TextXAlignment=Enum.TextXAlignment.Center
UI.volume=frame(Widgets.footer,UDim2.fromOffset(822,0),UDim2.fromOffset(196,76),FOOTER)
musicIcon(UI.volume,"volume",UDim2.fromOffset(0,29),19,MUTED)
Widgets.volBar=frame(UI.volume,UDim2.fromOffset(28,37),UDim2.fromOffset(95,3),Color3.fromRGB(76,76,76),2)
Widgets.volFill=frame(Widgets.volBar,UDim2.new(),UDim2.fromScale(volume,1),WHITE,2)
Widgets.volHit=button(Widgets.volBar,"",UDim2.fromOffset(0,-11),UDim2.new(1,0,0,26),WHITE)
Widgets.volHit.BackgroundTransparency=1
Widgets.volLabel=text(UI.volume,"45%",UDim2.fromOffset(132,24),UDim2.fromOffset(46,26),11,MUTED)

-- Available local-player features live in settings, leaving the source sidebar clean.
UI.settings=scrollingSurface(panel,UDim2.fromOffset(240,38),UDim2.fromOffset(800,526),PANEL)
UI.settings.Name="MusicSettings"
UI.settings.ZIndex=12
UI.settings.Visible=false
text(UI.settings,"音乐设置",UDim2.fromOffset(28,22),UDim2.fromOffset(620,40),24,WHITE)
text(UI.settings,"音源、封面与歌词",UDim2.fromOffset(28,69),UDim2.fromOffset(620,24),13,MUTED)
Widgets.sourceButton=button(UI.settings,"来源：网易云",UDim2.fromOffset(28,112),UDim2.fromOffset(260,38),STRIP,WHITE)
musicIcon(Widgets.sourceButton,"dropdown",UDim2.new(1,-30,.5,-8),16,WHITE)
Widgets.addButton=button(UI.settings,"添加音频 / Roblox Audio ID",UDim2.fromOffset(28,162),UDim2.fromOffset(310,38),STRIP,WHITE)
Widgets.lyricButton=button(UI.settings,"导入 LRC / YRC 歌词",UDim2.fromOffset(28,212),UDim2.fromOffset(310,38),STRIP,WHITE)
Widgets.coverButton=button(UI.settings,"设置当前歌曲封面",UDim2.fromOffset(28,262),UDim2.fromOffset(310,38),STRIP,WHITE)
UI.retryCoverButton=button(UI.settings,"重试封面",UDim2.fromOffset(242,262),UDim2.fromOffset(96,38),STRIP,WHITE)
Widgets.removeButton=button(UI.settings,"清空播放队列",UDim2.fromOffset(28,312),UDim2.fromOffset(310,38),STRIP,BAD)
UI.coverStatusLabel=text(UI.settings,"封面：尚未选择歌曲",UDim2.fromOffset(28,365),UDim2.fromOffset(700,54),12,MUTED)
UI.coverStatusLabel.TextWrapped=true
UI.coverStatusLabel.TextTruncate=Enum.TextTruncate.None
UI.backButton=button(UI.settings,"返回播放器",UDim2.fromOffset(28,432),UDim2.fromOffset(160,36),STRIP,WHITE)
UI.importOverlay=frame(panel,UDim2.fromOffset(240,38),UDim2.fromOffset(800,526),PANEL)
UI.importOverlay.ZIndex=13
UI.importOverlay.Visible=false
text(UI.importOverlay,"添加音频",UDim2.fromOffset(28,22),UDim2.fromOffset(620,40),24,WHITE)
text(UI.importOverlay,"输入 Roblox Audio ID、HTTPS 音频地址或本地音频路径",UDim2.fromOffset(28,82),UDim2.fromOffset(650,40),13,MUTED)
UI.importBox=textbox(UI.importOverlay,"歌曲名 | 音频地址（也可以只填地址）",UDim2.fromOffset(28,144),UDim2.fromOffset(690,44))
UI.importConfirm=button(UI.importOverlay,"添加并播放",UDim2.fromOffset(28,214),UDim2.fromOffset(168,38),ACCENT,Color3.fromRGB(57,16,12))
UI.importCancel=button(UI.importOverlay,"返回",UDim2.fromOffset(208,214),UDim2.fromOffset(120,38),STRIP,WHITE)

UI.layoutPanel=function()
    local cam=workspace.CurrentCamera
    local vp=cam and cam.ViewportSize or Vector2.new(1280,800)
    local w=clamp(vp.X-24,540,1240)
    local h=clamp(vp.Y-72,500,820)
    local narrow=w<900
    local compact=w<620
    local sidebar=compact and 135 or narrow and 180 or 240
    local inset=narrow and 14 or 28
    local workspaceWidth=w-sidebar
    local contentWidth=workspaceWidth-inset*2
    local contentHeight=h-96
    local cover=compact and 0 or narrow and 140 or 210
    local heroHeight=compact and 146 or cover
    local heroX=cover>0 and cover+(narrow and 16 or 26) or 0
    panel.Size=UDim2.fromOffset(w,h)
    UI.panelBaseScale=math.max(.1,math.min(1,(vp.X-24)/w,(vp.Y-72)/h))
    Widgets.panelScale.Scale=UI.panelBaseScale
    side.Size=UDim2.fromOffset(sidebar,contentHeight)
    top.Position=UDim2.fromOffset(sidebar,0);top.Size=UDim2.fromOffset(workspaceWidth,38)
    title.Visible=not compact
    minimize.Position=UDim2.fromOffset(workspaceWidth-40,4)
    UI.settingsButton.Position=UDim2.fromOffset(workspaceWidth-76,4)
    lyricLine.Position=UDim2.fromOffset(compact and 12 or math.min(150,workspaceWidth*.3),0)
    lyricLine.Size=UDim2.fromOffset(math.max(0,workspaceWidth-(compact and 100 or 240)),38)
    Widgets.searchBox.Size=UDim2.fromOffset(sidebar-32,36)
    Widgets.searchButton.Position=UDim2.fromOffset(sidebar-46,23)
    Widgets.searchBox.Size=UDim2.fromOffset(sidebar-48,36)
    for _,nav in ipairs({Widgets.queueTab,UI.favoriteTab,UI.queueNav,Widgets.resultTab}) do nav.Size=UDim2.fromOffset(sidebar-24,38) end
    Widgets.sideBottom.Position=UDim2.fromOffset(48,contentHeight-44)
    Widgets.sideBottom.Size=UDim2.fromOffset(sidebar-60,32)
    UI.profileIcon.Position=UDim2.fromOffset(18,contentHeight-40)
    Widgets.sideTitle.Size=UDim2.fromOffset(sidebar-36,20)
    UI.queueLabel.Size=UDim2.fromOffset(sidebar-36,20)
    Widgets.hero.Position=UDim2.fromOffset(sidebar+inset,50)
    Widgets.hero.Size=UDim2.fromOffset(contentWidth,heroHeight)
    Widgets.heroCover.Visible=cover>0;Widgets.heroCover.Size=UDim2.fromOffset(math.max(1,cover),math.max(1,cover))
    heading.Position=UDim2.fromOffset(heroX,compact and 4 or 12)
    heading.Size=UDim2.fromOffset(math.max(1,contentWidth-heroX),40)
    heading.TextSize=narrow and 22 or 28
    Widgets.heroSubtitle.Position=UDim2.fromOffset(heroX,54)
    Widgets.heroSubtitle.Size=UDim2.fromOffset(math.max(1,contentWidth-heroX),20)
    Widgets.heroMeta.Position=UDim2.fromOffset(heroX,narrow and 80 or 100)
    Widgets.heroMeta.Size=UDim2.fromOffset(math.max(1,contentWidth-heroX),24)
    Widgets.heroPlay.Position=UDim2.fromOffset(heroX,heroHeight-36)
    list.Position=UDim2.fromOffset(sidebar+inset,50+heroHeight+30)
    list.Size=UDim2.fromOffset(contentWidth,math.max(80,contentHeight-heroHeight-116))
    Widgets.statusLabel.Position=UDim2.fromOffset(sidebar+inset,contentHeight-26)
    Widgets.statusLabel.Size=UDim2.fromOffset(contentWidth,20)
    Widgets.footer.Position=UDim2.fromOffset(0,contentHeight);Widgets.footer.Size=UDim2.fromOffset(w,76)
    Widgets.credits.Position=UDim2.fromOffset(0,h-20);Widgets.credits.Size=UDim2.fromOffset(w,20)
    album.Visible=not compact
    Widgets.trackName.Position=UDim2.fromOffset(compact and 12 or 80,19)
    Widgets.trackArtist.Position=UDim2.fromOffset(compact and 12 or 80,44)
    local nowWidth=compact and 100 or narrow and 170 or math.min(280,w*.28)
    Widgets.trackName.Size=UDim2.fromOffset(math.max(30,nowWidth-(compact and 12 or 80)),20)
    Widgets.trackArtist.Size=UDim2.fromOffset(math.max(30,nowWidth-(compact and 12 or 80)),16)
    local volumeWidth=compact and 0 or narrow and 150 or 200
    local transportWidth=math.max(160,w-nowWidth-volumeWidth-40)
    UI.transport.Position=UDim2.fromOffset(nowWidth+12,0);UI.transport.Size=UDim2.fromOffset(transportWidth,76)
    for i,control in ipairs({Widgets.previous,Widgets.playButton,Widgets.nextButton,Widgets.loopButton}) do
        control.Position=UDim2.fromOffset(transportWidth/2-94+(i-1)*52,4)
    end
    Widgets.seekBack.Size=UDim2.fromOffset(math.max(60,transportWidth-80),3)
    Widgets.durationLabel.Position=UDim2.fromOffset(transportWidth-32,42)
    UI.volume.Visible=not compact;UI.volume.Position=UDim2.fromOffset(w-volumeWidth+4,0)
    Widgets.volBar.Size=UDim2.fromOffset(narrow and 60 or 95,3)
    Widgets.volLabel.Position=UDim2.fromOffset(narrow and 98 or 132,24)
    for _,overlay in ipairs({UI.settings,UI.importOverlay}) do
        overlay.Position=UDim2.fromOffset(sidebar,38);overlay.Size=UDim2.fromOffset(workspaceWidth,contentHeight-38)
    end
    UI.importBox.Size=UDim2.fromOffset(math.max(100,workspaceWidth-56),44)
    UI.coverStatusLabel.Size=UDim2.fromOffset(math.max(100,workspaceWidth-56),54)
    local settingWidth=math.max(100,math.min(310,workspaceWidth-56))
    for _,control in ipairs({Widgets.sourceButton,Widgets.addButton,Widgets.lyricButton,Widgets.coverButton,Widgets.removeButton}) do control.Size=UDim2.fromOffset(settingWidth,38) end
    Widgets.coverButton.Size=UDim2.fromOffset(settingWidth-106,38)
    UI.retryCoverButton.Position=UDim2.fromOffset(28+settingWidth-96,262)
    if Widgets.hudTop then
        Widgets.hudTop.Position=UDim2.fromOffset(28,362)
        Widgets.hudTop.Size=UDim2.fromOffset(settingWidth,38)
        UI.coverStatusLabel.Position=UDim2.fromOffset(28,465)
        UI.hudEditButton.Position=UDim2.fromOffset(28,412)
        UI.hudEditButton.Size=UDim2.fromOffset(settingWidth,38)
        UI.backButton.Position=UDim2.fromOffset(28,530)
        UI.settings.CanvasSize=UDim2.fromOffset(0,582)
    end
    for _,overlay in ipairs({Widgets.lyricOverlay,Widgets.coverOverlay}) do
        if overlay then
            overlay.Position=UDim2.fromOffset(sidebar,0)
            local scale=overlay:FindFirstChild("OverlayFit")
            if not scale then scale=Instance.new("UIScale");scale.Name="OverlayFit";scale.Parent=overlay end
            scale.Scale=math.min(workspaceWidth/668,contentHeight/470,1)
        end
    end
    if UI.reflowRows then UI.reflowRows() end
end
UI.layoutPanel()

-- MusicHud.svelte geometry at CSS pixel scale: 230 x 56, 48 px artwork.
Widgets.infoHud=frame(gui,UDim2.new(0,24,.22,0),UDim2.fromOffset(230,56),Color3.fromRGB(8,8,8),10.5)
Widgets.infoHud.Name="MusicInfo"
Widgets.infoHud.BackgroundTransparency=.13
Widgets.infoHud.ZIndex=3
Widgets.infoHud.Active=true
Widgets.infoShadow,Widgets.infoShadowScale=shadowFor(Widgets.infoHud,32,.55)
Widgets.infoBackdrop=Instance.new("ImageLabel")
Widgets.infoBackdrop.Name="AlbumArtworkBackdrop"
Widgets.infoBackdrop.Position=UDim2.new()
Widgets.infoBackdrop.Size=UDim2.fromScale(1,1)
rounded(Widgets.infoBackdrop,10.5)
Widgets.infoBackdrop.BackgroundTransparency=1
Widgets.infoBackdrop.ImageTransparency=.3
Widgets.infoBackdrop.ScaleType=Enum.ScaleType.Crop
Widgets.infoBackdrop.Visible=false
-- Clip enlarged art in a rounded surface, leaving the sibling shadow unclipped.
Widgets.infoClip=frame(Widgets.infoHud,UDim2.new(),UDim2.fromScale(1,1),Color3.new(0,0,0),10.5)
Widgets.infoClip.BackgroundTransparency=1
Widgets.infoClip.ClipsDescendants=true
Widgets.infoBackdrop.Parent=Widgets.infoClip
Widgets.infoShade=frame(Widgets.infoClip,UDim2.new(),UDim2.fromScale(1,1),Color3.new(0,0,0),10.5)
Widgets.infoShade.BackgroundTransparency=.53
Widgets.infoShade.ZIndex=2
Widgets.infoCover=frame(Widgets.infoHud,UDim2.fromOffset(5,4),UDim2.fromOffset(48,48),Color3.fromRGB(29,29,29),6)
Widgets.infoCover.ZIndex=3
Widgets.infoNote=text(Widgets.infoCover,"♫",UDim2.new(),UDim2.fromScale(1,1),24,ACCENT,true)
Widgets.infoNote.TextXAlignment=Enum.TextXAlignment.Center
Widgets.infoNote.ZIndex=4
Widgets.infoSong=text(Widgets.infoHud,"Tritium Music",UDim2.fromOffset(58,4),UDim2.fromOffset(167,17),12,WHITE,true)
Widgets.infoArtist=text(Widgets.infoHud,"歌曲信息预览",UDim2.fromOffset(58,21),UDim2.fromOffset(167,13),9,Color3.fromRGB(193,193,193),true)
Widgets.infoBar=frame(Widgets.infoHud,UDim2.fromOffset(58,35),UDim2.fromOffset(167,3.5),WHITE,2)
Widgets.infoBar.BackgroundTransparency=.67
Widgets.infoBar.ClipsDescendants=true
Widgets.infoFill=frame(Widgets.infoBar,UDim2.new(),UDim2.fromScale(0,1),Color3.fromRGB(228,228,228),2)
Widgets.infoTime=text(Widgets.infoHud,"0:00",UDim2.fromOffset(58,41.5),UDim2.fromOffset(60,10),7.5,Color3.fromRGB(170,170,170),true)
Widgets.infoDuration=text(Widgets.infoHud,"—:—",UDim2.fromOffset(165,41.5),UDim2.fromOffset(60,10),7.5,Color3.fromRGB(170,170,170),true)
for _,node in ipairs({Widgets.infoSong,Widgets.infoArtist,Widgets.infoBar,Widgets.infoTime,Widgets.infoDuration}) do node.ZIndex=3 end

local function coverImage(parent)
    local img=Instance.new("ImageLabel")
    img.BackgroundTransparency=1
    img.Size=UDim2.fromScale(1,1)
    img.Image=""
    img.ScaleType=Enum.ScaleType.Crop
    img.Visible=false
    img.Parent=parent
    rounded(img,6)
    img.ZIndex=5
    return img
end
Widgets.heroCoverImage=coverImage(Widgets.heroCover)
Widgets.albumImage=coverImage(album)
Widgets.infoCoverImage=coverImage(Widgets.infoCover)
Widgets.infoDuration.TextXAlignment=Enum.TextXAlignment.Right

-- One clipped, moving stack: no resetting all row positions on every cue.
Widgets.lyricsHud=frame(gui,UDim2.new(1,-474,.29,0),UDim2.fromOffset(450,120),Color3.new(0,0,0))
Widgets.lyricsHud.Name="MusicLyrics"
Widgets.lyricsHud.BackgroundTransparency=1
Widgets.lyricsHud.ClipsDescendants=true
Widgets.lyricsHud.Active=true
Widgets.lyricRows={}
local function lyricRow(index)
    local row=frame(Widgets.lyricsHud,UDim2.new(),UDim2.fromOffset(450,30),Color3.new(0,0,0))
    row.BackgroundTransparency=1
    local label=text(row,"",UDim2.new(),UDim2.fromOffset(450,18),14,WHITE,true)
    label.TextXAlignment=Enum.TextXAlignment.Right
    label.TextStrokeTransparency=.65
    local translation=text(row,"",UDim2.fromOffset(0,18),UDim2.fromOffset(450,12),9,WHITE,true)
    translation.TextXAlignment=Enum.TextXAlignment.Right
    translation.TextStrokeTransparency=.75
    return {root=row,label=label,translation=translation,index=index}
end
Widgets.lyricsCurrent=text(Widgets.lyricsHud,"",UDim2.new(),UDim2.new(),14)
Widgets.lyricsCurrent.Visible=false
local function updateLyricsScroller(cueIndex,pos)
    local first,last=math.max(1,cueIndex-2),math.min(#currentLyrics,math.max(1,cueIndex)+2)
    local effectiveIndex=math.max(1,cueIndex)
    for index,row in pairs(Widgets.lyricRows) do
        if index<first or index>last or row.cue~=currentLyrics[index] then
            row.root:Destroy();Widgets.lyricRows[index]=nil
        end
    end
    for index=first,last do
        local cue=currentLyrics[index]
        local row=Widgets.lyricRows[index]
        local created=not row
        if created then row=lyricRow(index);row.cue=cue;Widgets.lyricRows[index]=row end
        local delta=index-effectiveIndex
        local targetY=48+delta*38
        local transparency=delta==0 and 0 or math.abs(delta)==1 and .65 or .92
        -- Edge fade follows the source 15%/88% mask without covering the game scene.
        if targetY<0 or targetY>106 then transparency=math.max(transparency,.94) end
        local target=UDim2.fromOffset(0,targetY)
        if created then
            row.root.Position=target
            row.label.TextTransparency=transparency
            row.translation.TextTransparency=transparency
        elseif row.targetY~=targetY then
            tween(row.root,{Position=target},.33)
            tween(row.label,{TextTransparency=transparency},.33)
            tween(row.translation,{TextTransparency=transparency},.33)
        end
        row.targetY=targetY
        row.label.RichText=false
        row.label.Text=cue.text
        row.translation.Text=matchingTranslation(currentTranslations,cue.at)
        if index==cueIndex then Widgets.lyricsCurrent=row.label end
    end
    if #currentLyrics==0 then
        if not Widgets.lyricPlaceholder then Widgets.lyricPlaceholder=lyricRow(0) end
        Widgets.lyricPlaceholder.root.Visible=true
        Widgets.lyricPlaceholder.root.Position=UDim2.fromOffset(0,48)
        Widgets.lyricPlaceholder.label.Text=queue[index] and queue[index].title or (UI.editor and UI.editor.enabled and "歌词预览 · Infinite Skidded" or "")
    elseif Widgets.lyricPlaceholder then Widgets.lyricPlaceholder.root.Visible=false end
end

-- Original HUD is 32 actual PCM bands. Roblox provides PlaybackLoudness, not FFT.
-- We preserve its flat 32-band silhouette but DO NOT mislabel it as frequency analysis.
Widgets.spectrumHud=frame(gui,UDim2.new(0,32,.7,0),UDim2.fromOffset(480,70),Color3.new(0,0,0),0)
Widgets.spectrumHud.BackgroundTransparency=1
Widgets.spectrumHud.Active=true
local bars={}
for i=1,32 do
    local b=frame(Widgets.spectrumHud,UDim2.fromOffset((i-1)*15,69),UDim2.fromOffset(11,1),Color3.fromRGB(182,182,182),2)
    b.BackgroundTransparency=.37
    bars[i]=b
end

-- Port of music/src/opai/music/DangoLyrics.java, which was adapted from
-- Sorihiko/DangoMusic. Each lyric cue gets its own *fixed world position*,
-- character glyphs, word timing, pop/wiggle and 300/400ms fade envelopes.
-- World labels use the same executor GUI container.
local worldScenes={}
local worldLastIndex=-1
local worldLastPosition=-1
local worldRandom=Random.new()
local lyricSpread=clamp(tonumber(hudSettings.spread) or 30,0,60)
local lyricScale=clamp(tonumber(hudSettings.scale) or 1,.5,3)
local function codeChars(str)
    local out={}
    local ok=pcall(function()
        for _,cp in utf8.codes(str) do out[#out+1]=utf8.char(cp) end
    end)
    if not ok then for i=1,#str do out[#out+1]=str:sub(i,i) end end
    return out
end
local function isCJK(ch)
    local ok,c=pcall(utf8.codepoint,ch)
    return ok and c>=0x2e80
end
local function cueTiming(cue,nextCue,characters)
    local times={}
    if cue.words and #cue.words>0 then
        for _,word in ipairs(cue.words) do
            local t=math.max(0,(tonumber(word.at) or cue.at)-cue.at)
            for _=1,#codeChars(word.text or "") do times[#times+1]=t end
        end
        if #times==#characters then return times end
    end
    -- Dango fallback: Latin words and CJK pairs appear as rhythmic groups.
    local group,current,tokens,cjk,wasCJK={},-1,0,0,false
    for i,ch in ipairs(characters) do
        if ch:match("^%s+$") then
            group[i]=math.max(0,current);current=-1;cjk=0
        else
            local chinese=isCJK(ch)
            if current<0 or chinese~=wasCJK or (chinese and cjk>=2) then
                current=tokens;tokens=tokens+1;cjk=0
            end
            group[i]=current
            if chinese then cjk=cjk+1 end
            wasCJK=chinese
        end
    end
    local length=(nextCue and nextCue.at or cue.at+5)-cue.at
    local span=math.min(math.max(.3,length)*.75,tokens*.33)
    for i=1,#characters do times[i]=span*(group[i] or 0)/math.max(1,tokens) end
    return times
end
local function sceneRelease(scene)
    if scene.billboard then pcall(function() scene.billboard:Destroy() end) end
    if scene.anchor then pcall(function() scene.anchor:Destroy() end) end
end
local function sceneRetire(now)
    for _,scene in ipairs(worldScenes) do
        if not scene.fadeAt then scene.fadeAt=now end
    end
end
local function clearWorldScenes()
    for _,scene in ipairs(worldScenes) do sceneRelease(scene) end
    worldScenes={}
    worldLastIndex=-1
    worldLastPosition=-1
end
local function sceneSpawn(cue,nextCue)
    local cam=workspace.CurrentCamera
    if not cam or not cue or not cue.text or cue.text=="" then return end
    local chars=codeChars(cue.text)
    if #chars>240 then while #chars>240 do table.remove(chars) end end
    if #chars==0 then return end
    local anchor=Instance.new("Part")
    anchor.Name="OpaiDango3D_LocalAnchor"
    anchor.Size=Vector3.new(.15,.15,.15)
    anchor.Anchored=true
    anchor.CanCollide=false
    anchor.CanTouch=false
    anchor.CanQuery=false
    anchor.Transparency=1
    local theta=math.rad(worldRandom:NextNumber(-lyricSpread,lyricSpread))
    local pitch=math.rad(-3-worldRandom:NextNumber(0,10))
    local pos=cam.CFrame*(CFrame.Angles(pitch,theta,0))
    anchor.CFrame=CFrame.new(cam.CFrame.Position+pos.LookVector*lyricDistance)
    anchor.Parent=workspace
    local billboard=Instance.new("BillboardGui")
    billboard.Name="OpaiDango3D_WorldText"
    billboard.Adornee=anchor
    billboard.Size=UDim2.fromOffset(640,185)
    billboard.AlwaysOnTop=false
    billboard.LightInfluence=0
    billboard.MaxDistance=90
    billboard.Parent=HIDDEN
    -- This is the *original* Dango wrap metric: CJK advance 9, Latin advance 6, width 200.
    local glyphRows={{}}
    local width=0
    for _,ch in ipairs(chars) do
        local advance=isCJK(ch) and 9 or 6
        if width+advance>200 then glyphRows[#glyphRows+1]={};width=0 end
        local row=glyphRows[#glyphRows]
        row[#row+1]={ch=ch,advance=advance}
        width=width+advance
    end
    local n=0
    local timings=cueTiming(cue,nextCue,chars)
    local glyphs={}
    local maxHeight=math.max(1,#glyphRows)*39
    for rowIndex,row in ipairs(glyphRows) do
        local rowWidth=0
        for _,g in ipairs(row) do rowWidth=rowWidth+g.advance*3 end
        local x=(640-rowWidth)/2
        for _,g in ipairs(row) do
            n=n+1
            local label=Instance.new("TextLabel")
            label.Name="Glyph"..n
            label.BackgroundTransparency=1
            label.Size=UDim2.fromOffset(g.advance*3+6,42)
            label.Position=UDim2.fromOffset(x, (185-maxHeight)/2+(rowIndex-1)*39)
            label.Font=Enum.Font.ArialBold
            label.TextSize=29
            label.Text=g.ch
            label.TextColor3=WHITE
            label.TextTransparency=1
            label.TextStrokeColor3=Color3.new(0,0,0)
            label.TextStrokeTransparency=1
            label.TextXAlignment=Enum.TextXAlignment.Center
            label.Parent=billboard
            bindFont(label)
            glyphs[#glyphs+1]={label=label,x=x,y=label.Position.Y.Offset,at=timings[n] or 0}
            x=x+g.advance*3
        end
    end
    local now=os.clock()
    worldScenes[#worldScenes+1]={anchor=anchor,billboard=billboard,glyphs=glyphs,cue=cue,born=now}
    while #worldScenes>4 do sceneRelease(table.remove(worldScenes,1)) end
end
local function renderWorldScenes(pos,playing,cueIndex)
    local now=os.clock()
    local enabled=hudEnabled("world",false) and playing and #currentLyrics>0
    if not enabled then
        if worldLastIndex~=-1 then sceneRetire(now) end
        worldLastIndex=-1
    elseif cueIndex~=worldLastIndex or (worldLastPosition>=0 and math.abs(pos-worldLastPosition)>1.8) then
        if worldLastIndex~=-1 then sceneRetire(now) end
        worldLastIndex=cueIndex
        sceneSpawn(currentLyrics[cueIndex],currentLyrics[cueIndex+1])
    end
    worldLastPosition=pos
    local cam=workspace.CurrentCamera
    for i=#worldScenes,1,-1 do
        local scene=worldScenes[i]
        if scene.fadeAt and now-scene.fadeAt>=.4 then
            sceneRelease(scene);table.remove(worldScenes,i)
        else
            local alpha=scene.fadeAt and clamp(1-(now-scene.fadeAt)/.4,0,1)
                or clamp((now-scene.born)/.3,0,1)
            if scene.fadeAt then
                scene.anchor.Position=scene.anchor.Position+Vector3.new(0,.4/25,0)
            end
            if cam then
                local offset=scene.anchor.Position-cam.CFrame.Position
                local d=offset.Magnitude
                if d>.0001 and d<lyricDistance*.6 then
                    scene.anchor.Position=cam.CFrame.Position+offset.Unit*(lyricDistance*.6)
                end
            end
            local elapsed=math.max(0,pos-scene.cue.at)
            for j,g in ipairs(scene.glyphs) do
                local t=(elapsed-g.at)/.16
                local reveal=hudEnabled("wordPop",true) and clamp(t*3,0,1) or clamp(t,0,1)
                local pop=hudEnabled("wordPop",true) and 1+.55*math.max(0,1-clamp(t,0,1))^2 or 1
                local wiggle=hudEnabled("wiggle",true)
                local phase=math.floor(now*8)
                local dx=wiggle and math.sin(j*53.7+phase*19.3)*.6 or 0
                local dy=wiggle and math.cos(j*23.3+phase*7.1)*.6 or 0
                local lbl=g.label
                lbl.TextTransparency=1-reveal*alpha
                lbl.TextStrokeTransparency=1-reveal*alpha*.75
                lbl.TextSize=math.floor(29*lyricScale*pop+.5)
                lbl.Position=UDim2.fromOffset(g.x+dx,g.y+dy)
            end
        end
    end
end

-- Controls are collected on the sidebar. All display modes are independent.
Widgets.toggleWindow=frame(gui,UDim2.new(.5,-248,0,61),UDim2.fromOffset(496,35),FOOTER,8)
Widgets.toggleWindow.Visible=false
Widgets.toggleWindow.ZIndex=30
Widgets.hudButtons={}
local function hudButton(label,x,w)
    local b=button(Widgets.toggleWindow,label,UDim2.fromOffset(x,2),UDim2.fromOffset(w,31),STRIP,WHITE)
    b.TextSize=11
    table.insert(Widgets.hudButtons,b)
    return b
end
Widgets.hudInfoToggle=hudButton("歌曲HUD",3,87)
Widgets.hudLyricsToggle=hudButton("歌词HUD",94,87)
Widgets.hudSpectrumToggle=hudButton("音量条",185,83)
Widgets.worldToggle=hudButton("Dango3D",272,92)
Widgets.islandLyricsToggle=hudButton("岛歌词",368,120)
Widgets.hudTop=button(UI.settings,"HUD / 3D 显示设置",UDim2.fromOffset(28,362),UDim2.fromOffset(260,38),STRIP,WHITE)
UI.hudEditButton=button(UI.settings,"HUD 编辑",UDim2.fromOffset(28,412),UDim2.fromOffset(260,38),STRIP,WHITE)
Widgets.worldOptions=frame(gui,UDim2.new(.5,-280,0,101),UDim2.fromOffset(560,36),FOOTER,8)
Widgets.worldOptions.Visible=false
Widgets.worldOptions.ZIndex=30
Widgets.worldDistanceDown=button(Widgets.worldOptions,"距离 −",UDim2.fromOffset(4,3),UDim2.fromOffset(91,30),STRIP,WHITE)
Widgets.worldDistanceUp=button(Widgets.worldOptions,"距离 +",UDim2.fromOffset(98,3),UDim2.fromOffset(85,30),STRIP,WHITE)
Widgets.worldScaleDown=button(Widgets.worldOptions,"缩小",UDim2.fromOffset(186,3),UDim2.fromOffset(65,30),STRIP,WHITE)
Widgets.worldScaleUp=button(Widgets.worldOptions,"放大",UDim2.fromOffset(254,3),UDim2.fromOffset(65,30),STRIP,WHITE)
Widgets.worldSpread=button(Widgets.worldOptions,"扩散",UDim2.fromOffset(323,3),UDim2.fromOffset(72,30),STRIP,WHITE)
Widgets.worldPop=button(Widgets.worldOptions,"弹跳",UDim2.fromOffset(399,3),UDim2.fromOffset(71,30),STRIP,WHITE)
Widgets.worldWiggle=button(Widgets.worldOptions,"抖动",UDim2.fromOffset(474,3),UDim2.fromOffset(80,30),STRIP,WHITE)


Widgets.lyricOverlay=frame(panel,UDim2.fromOffset(238,0),UDim2.fromOffset(668,470),Color3.fromRGB(27,27,27),0)
Widgets.lyricOverlay.ZIndex=13
Widgets.lyricOverlay.Visible=false
Widgets.lyricsTitle=text(Widgets.lyricOverlay,"导入当前歌曲歌词（LRC 时间戳）",UDim2.fromOffset(30,20),UDim2.fromOffset(565,36),19,WHITE,true)
Widgets.lyricsTitle.ZIndex=14
Widgets.lyricInput=textbox(Widgets.lyricOverlay,"[00:10.00]第一句歌词\n[00:14.50]第二句歌词",UDim2.fromOffset(30,69),UDim2.fromOffset(607,299),true)
Widgets.lyricInput.ZIndex=14
Widgets.lyricSave=button(Widgets.lyricOverlay,"保存歌词",UDim2.fromOffset(33,384),UDim2.fromOffset(195,43),ACCENT,Color3.fromRGB(51,20,15))
Widgets.lyricSave.ZIndex=14
Widgets.lyricCancel=button(Widgets.lyricOverlay,"返回",UDim2.fromOffset(239,384),UDim2.fromOffset(166,43),STRIP,WHITE)
Widgets.lyricCancel.ZIndex=14
Widgets.coverOverlay=frame(panel,UDim2.fromOffset(238,0),UDim2.fromOffset(668,470),Color3.fromRGB(27,27,27),0)
Widgets.coverOverlay.ZIndex=13
Widgets.coverOverlay.Visible=false
Widgets.coverTitle=text(Widgets.coverOverlay,"设置专辑封面",UDim2.fromOffset(28,24),UDim2.fromOffset(550,38),23,WHITE,true)
Widgets.coverTitle.ZIndex=14
Widgets.coverHelp=text(Widgets.coverOverlay,"填写 PNG/JPEG 图片的 HTTPS 地址，或 Roblox 图片资源 ID；留空可清除。加载结果显示在音乐设置中。",UDim2.fromOffset(28,80),UDim2.fromOffset(600,55),12,MUTED,false)
Widgets.coverHelp.ZIndex=14
Widgets.coverInput=textbox(Widgets.coverOverlay,"https://example.com/cover.png 或 rbxassetid://图片ID",UDim2.fromOffset(28,150),UDim2.fromOffset(606,44))
Widgets.coverInput.ZIndex=14
Widgets.coverSave=button(Widgets.coverOverlay,"保存并加载封面",UDim2.fromOffset(28,232),UDim2.fromOffset(200,42),ACCENT,Color3.fromRGB(48,17,10))
Widgets.coverSave.ZIndex=14
Widgets.coverCancel=button(Widgets.coverOverlay,"返回",UDim2.fromOffset(242,232),UDim2.fromOffset(140,42),STRIP,WHITE)
Widgets.coverCancel.ZIndex=14

-- Keep the original public variable contract for the existing playback engine.
local function setStatus(message, color)
    status = clean(message, 160)
    statusColor = color or MUTED
    Widgets.statusLabel.Text = status
    Widgets.statusLabel.TextColor3 = statusColor
    lastStatusAt = os.clock()
end
local function currentSong()
    return queue[index]
end
local currentLrcLine
local lastIslandTargetWidth=0
local function layoutIsland()
    if not alive then return end
    local ink=Widgets.islandInk
    local width=0
    local count=0
    for _,node in ipairs(ink:GetChildren()) do
        if node:IsA("GuiObject") and node.Visible then
            width=width+node.Size.X.Offset;count=count+1
        end
    end
    local desired=math.max(150,math.min(800,width+math.max(0,count-1)*7+36))
    if math.abs(desired-lastIslandTargetWidth)>.5 then
        lastIslandTargetWidth=desired
        tween(Widgets.island,{Size=UDim2.fromOffset(desired,46)},.26)
    end
end
local function measureIslandText(node)
    local value,face=node.Text,node.FontFace
    local ticket=(node:GetAttribute("MeasureTicket") or 0)+1
    node:SetAttribute("MeasureTicket",ticket)
    task.spawn(function()
        local params=Instance.new("GetTextBoundsParams")
        params.Text=value;params.Font=face;params.Size=node.TextSize;params.Width=100000
        local ok,bounds=pcall(function() return game:GetService("TextService"):GetTextBoundsAsync(params) end)
        params:Destroy()
        if not alive or not node.Parent or node:GetAttribute("MeasureTicket")~=ticket then return end
        if not ok then
            bounds=game:GetService("TextService"):GetTextSize(value,node.TextSize,Enum.Font.ArialBold,Vector2.new(100000,1000))
        end
        local maximum=node==Widgets.islandTitle and 260 or node==Widgets.islandUser and 130 or node==Widgets.islandSub and 420 or 160
        node.Size=UDim2.fromOffset(math.min(maximum,math.ceil(bounds.X)),46)
        layoutIsland()
    end)
end
for _,node in ipairs(Widgets.islandInk:GetChildren()) do
    if node:IsA("TextLabel") and node~=Widgets.islandAction and node~=Widgets.islandLogo then
        table.insert(connections,node:GetPropertyChangedSignal("Text"):Connect(function() measureIslandText(node) end))
        table.insert(connections,node:GetPropertyChangedSignal("FontFace"):Connect(function() measureIslandText(node) end))
        measureIslandText(node)
    end
end
local function updateIsland()
    if not alive then return end
    local song=currentSong()
    local hasTrack=song~=nil and sound~=nil
    Widgets.islandNoteImage.Visible=hasTrack and Asset.icons~=nil
    Widgets.islandAction.Visible=not hasTrack or Asset.icons==nil
    Widgets.islandAction.Text=hasTrack and "♫" or "↔"
    Widgets.islandFps.Visible=not hasTrack
    Widgets.islandFps.Text="·  "..math.floor(UI.fps+.5).." fps"
    if hasTrack then
        local words=hudEnabled("islandLyrics",true) and currentLrcLine and currentLrcLine(sound.TimePosition) or ""
        Widgets.islandSub.Text=words~="" and words or song.title
        Widgets.islandSub.TextColor3=WHITE
    else
        local ping="--"
        pcall(function() ping=tostring(math.floor(LOCAL:GetNetworkPing()*1000+.5)) end)
        Widgets.islandSub.Text=ping.." ms to Roblox"
        Widgets.islandSub.TextColor3=WHITE
    end
    Widgets.islandUser.Text=clean(LOCAL.DisplayName,32)
    layoutIsland()
end

local function updateControls()
    local song = currentSong()
    Widgets.trackName.Text = song and clean(song.title, 75) or "还没有播放歌曲"
    Widgets.trackArtist.Text = song and clean(song.artist, 80) or "Tritium Music"
    Widgets.heroMeta.Text = ({netease="网易云音乐",joox="JOOX",bilibili="bilibili"})[gdSource] or "GD 音乐台"
    Widgets.playButton.Text = Asset.icons and "" or (sound and sound.IsPlaying and "❚❚" or "▶")
    if Widgets.playIcon then
        local playing=sound and sound.IsPlaying
        local slot=MUSIC_SPRITES[playing and "pause" or "play"]
        UI.setIcon(Widgets.playIcon,playing and "pause" or "play")
    end
    Widgets.loopButton.Text = Asset.icons and "" or (repeatOne and "↻₁" or "↻")
    if Widgets.loopIcon then UI.tintIcon(Widgets.loopIcon,repeatOne and ACCENT or MUTED) end
    Widgets.loopButton.TextColor3 = repeatOne and ACCENT or MUTED
    Widgets.volLabel.Text = tostring(math.floor(volume * 100 + .5)) .. "%"
    Widgets.volFill.Size = UDim2.fromScale(volume, 1)
    updateIsland()
end
currentLrcLine = function(pos)
    local found = ""
    local lo, hi = 1, #currentLyrics
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        if currentLyrics[mid].at <= pos then
            found = currentLyrics[mid].text
            lo = mid + 1
        else hi = mid - 1 end
    end
    return found
end

local function appendSong(song)
    if #queue >= 60 then setStatus("播放列表最多 60 首", BAD); return nil end
    table.insert(queue, song)
    persist()
    return #queue
end

local refreshList
local ensureGDLyrics
-- Read local MP3 ID3v2.3/2.4 APIC artwork when present; no external metadata service.
local function embeddedMp3Artwork(path)
    if not STORAGE_OK or not isfile(path) then return nil end
    local ok,data=pcall(readfile,path)
    if not ok or type(data)~="string" or data:sub(1,3)~="ID3" or #data<10 then return nil end
    local v=data:byte(4)
    if v~=3 and v~=4 then return nil end
    local function syncsafe(at)
        local a,b,c,d=data:byte(at,at+3)
        if not d then return nil end
        return a*2097152+b*16384+c*128+d
    end
    local limit=math.min(#data,10+math.min(syncsafe(7) or 0,4*1024*1024))
    local idx=11
    while idx+10<limit do
        local id=data:sub(idx,idx+3)
        if not id:match("^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$") then break end
        local a,b,c,d=data:byte(idx+4,idx+7)
        local length=v==4 and (a*2097152+b*16384+c*128+d) or (a*16777216+b*65536+c*256+d)
        if length<=0 or idx+10+length>limit+1 then break end
        if id=="APIC" then
            local body=data:sub(idx+10,idx+9+length)
            local p=body:find(string.char(137).."PNG"..string.char(13,10,26,10),1,true)
            local ext=p and "png" or nil
            if not p then p=body:find(string.char(255,216,255),1,true);ext=p and "jpg" or nil end
            if p then
                local bytes=body:sub(p)
                local target=(ROOT_OK and ROOT.."/" or "OpaiMusic_").."id3cover_"..keyFor(path).."."..ext
                if saveText(target,bytes) then return target end
            end
        end
        idx=idx+10+length
    end
    return nil
end
-- Cover state is separate from audio loading. A usable SoundId does not imply
-- that the image request, file format, asset import, and texture preload succeeded.
UI.coverEpoch=0
UI.coverCache={}
UI.coverState="empty"
UI.coverMessage="尚未选择歌曲"
local function coverStatus(state,message)
    UI.coverState=state
    UI.coverMessage=message
    UI.coverStatusLabel.Text="封面："..message
    UI.coverStatusLabel.TextColor3=state=="failed" and BAD or MUTED
end
local function resetCover(message)
    UI.coverEpoch=UI.coverEpoch+1
    if UI.coverPending then UI.coverPending.cancel() end
    for _,image in ipairs({Widgets.heroCoverImage,Widgets.albumImage,Widgets.infoCoverImage,Widgets.infoBackdrop}) do
        image.Visible=false;image.Image=""
    end
    Widgets.heroSymbol.Visible=true;Widgets.albumText.Visible=true;Widgets.infoNote.Visible=true
    coverStatus("empty",message or "未设置")
end
UI.resetCover=resetCover
for _,pair in ipairs({{Widgets.heroCoverImage,Widgets.heroSymbol},{Widgets.albumImage,Widgets.albumText},{Widgets.infoCoverImage,Widgets.infoNote}}) do
    local image,placeholder=pair[1],pair[2]
    local function updatePlaceholder()
        placeholder.Visible=not (image.Visible and image.Image~="" and image.IsLoaded)
    end
    table.insert(connections,image:GetPropertyChangedSignal("IsLoaded"):Connect(updatePlaceholder))
    table.insert(connections,image:GetPropertyChangedSignal("Visible"):Connect(updatePlaceholder))
end
local function coverURI(song)
    local uri=mediaURL(song.cover or "")
    if uri:match("^%d+$") then uri="rbxassetid://"..uri end
    return uri
end
local function repairCoverMetadata(song)
    if song.kind~="gd" or not REQUEST then return false end
    local items=gdAPI({types="search",source=song.source or gdSource,name=song.title or "",count=20,pages=1})
    if type(items)~="table" then return false end
    for _,item in ipairs(items) do
        if type(item)=="table" and tostring(item.id)==song.value and (not item.source or item.source==(song.source or gdSource)) then
            song.picId=clean(item.pic_id or item.picId or "",4096)
            local cover=item.cover or item.cover_url or item.pic_url or (type(item.al)=="table" and item.al.picUrl) or ""
            song.metadataCover=type(cover)=="string" and clean(cover,4096) or ""
            return true
        end
    end
    return false
end
local function automaticCoverURI(song,refresh)
    if refresh then repairCoverMetadata(song) end
    local direct=mediaURL(song.metadataCover or "")
    if direct:match("^https://") then return direct end
    local pic=mediaURL(song.picId or "")
    if pic:match("^https://") then return pic end
    if pic=="" or (pic==song.value and not refresh) then
        if not refresh then
            repairCoverMetadata(song)
            direct=mediaURL(song.metadataCover or "")
            if direct:match("^https://") then return direct end
            pic=mediaURL(song.picId or "")
        end
        if pic:match("^https://") then return pic end
        if pic=="" then return nil,"曲目缺少专辑图 ID；请重新搜索该曲目或手动设置封面" end
    end
    local data,err=gdAPI({types="pic",source=song.source or gdSource,id=pic,size=300})
    if not data then return nil,err end
    local uri=type(data)=="table" and (data.url or data.pic or (type(data.data)=="table" and data.data.url)) or nil
    if type(uri)~="string" or uri=="" then return nil,"音乐源没有返回封面地址" end
    return mediaURL(uri)
end

local function imageFormat(raw)
    if type(raw)~="string" then return nil end
    if raw:sub(1,8)==string.char(137).."PNG"..string.char(13,10,26,10) then return "png" end
    if raw:sub(1,3)==string.char(255,216,255) then return "jpg" end
    if raw:sub(1,4)=="RIFF" and raw:sub(9,12)=="WEBP" then return "webp" end
    return nil
end
-- Bind the real display controls before deciding whether a texture loaded.
-- A hidden probe can be unloaded by the renderer even after preloading succeeds.
local function loadCoverTexture(asset,cacheKey,song,current,fail)
    if UI.coverPending then UI.coverPending.cancel() end
    local images={Widgets.infoCoverImage,Widgets.heroCoverImage,Widgets.albumImage}
    local pending={connections={},done=false,fetchStatus="未返回"}
    UI.coverPending=pending
    local function cleanup()
        for _,connection in ipairs(pending.connections) do connection:Disconnect() end
        pending.connections={}
        if UI.coverPending==pending then UI.coverPending=nil end
    end
    pending.cancel=function()
        pending.done=true
        cleanup()
    end
    local function anyLoaded()
        for _,image in ipairs(images) do
            if image.Parent and image.Image==asset and image.IsLoaded then return true end
        end
        return false
    end
    local function canShow()
        local playerVisible=panel.Visible and not UI.settings.Visible and not UI.importOverlay.Visible
            and not Widgets.lyricOverlay.Visible and not Widgets.coverOverlay.Visible
        for _,image in ipairs(images) do
            local eligible=image==Widgets.infoCoverImage and not panel.Visible or image~=Widgets.infoCoverImage and playerVisible
            if eligible then
                local node=image
                local shown=true
                while node and node~=gui do
                    if node:IsA("GuiObject") and not node.Visible then shown=false;break end
                    node=node.Parent
                end
                if shown then return true end
            end
        end
        return false
    end
    local timeout
    local function check()
        if pending.done then return end
        if not current() then pending.cancel();return end
        if not anyLoaded() then
            if pending.waitingForDisplay and canShow() then
                pending.waitingForDisplay=false
                coverStatus("loading","正在等待图片控件显示…")
                task.delay(12,timeout)
            end
            return
        end
        pending.done=true
        cleanup()
        UI.coverCache[cacheKey]=asset
        Widgets.heroSymbol.Visible=not Widgets.heroCoverImage.IsLoaded
        Widgets.albumText.Visible=not Widgets.albumImage.IsLoaded
        Widgets.infoNote.Visible=not Widgets.infoCoverImage.IsLoaded
        Widgets.infoBackdrop.Image=asset;Widgets.infoBackdrop.Visible=true;Widgets.infoBackdrop.ImageTransparency=.45
        if UI.rows then
            for _,row in ipairs(UI.rows) do
                if row.song==song and row.art.Parent then
                    row.art.Image=asset;row.art.Visible=true;row.note.Visible=false
                end
            end
        end
        coverStatus("ready","已加载")
    end
    for _,image in ipairs(images) do
        table.insert(pending.connections,image:GetPropertyChangedSignal("IsLoaded"):Connect(check))
    end
    -- Leave the placeholder underneath the texture until the renderer confirms it.
    for _,image in ipairs(images) do
        image.Image=asset
        image.ImageTransparency=0
        image.Visible=true
        image.ZIndex=5
    end
    check()
    if pending.done then return end
    table.insert(pending.connections,RunService.RenderStepped:Connect(check))
    task.spawn(function()
        local ok,err=pcall(function()
            game:GetService("ContentProvider"):PreloadAsync(images,function(_,status)
                pending.fetchStatus=tostring(status)
                -- Fetch status is diagnostic; the actual image controls decide.
            end)
        end)
        if not ok then pending.fetchStatus=clean(err,160) end
        check()
    end)
    timeout=function()
        if pending.done then return end
        check()
        if pending.done then return end
        if not canShow() then
            -- Keep the listeners. Opening the player/HUD can now render the image.
            coverStatus("pending","图片已缓存，等待播放器或 HUD 显示")
            pending.waitingForDisplay=true
            return
        end
        pending.done=true
        cleanup()
        for _,image in ipairs(images) do if image.Image==asset then image.Visible=false end end
        fail("图片已下载，但实际图片控件等待 12 秒仍未载入（预载状态："..pending.fetchStatus.."）")
    end
    task.delay(12,timeout)
end

local function resolveCover(song,job)
    if UI.coverPending then UI.coverPending.cancel() end
    UI.coverEpoch=UI.coverEpoch+1
    local ticket=UI.coverEpoch
    local function current()
        return alive and generation==job and UI.coverEpoch==ticket and currentSong()==song
    end
    local function fail(reason)
        if current() then coverStatus("failed",reason) end
    end
    coverStatus("loading","正在加载…")
    task.spawn(function()
        local uri=coverURI(song)
        local asset=nil
        local cacheKey=song.kind..":"..tostring(song.source or "")..":"..song.value..":"..uri
        if UI.coverCache[cacheKey] then asset=UI.coverCache[cacheKey] end
        if not asset and uri=="" and song.kind=="file" and song.value:lower():match("%.mp3$") then
            if FILE_ASSET and STORAGE_OK then
                local path=embeddedMp3Artwork(song.value)
                if path then
                    local ok,result=pcall(FILE_ASSET,path)
                    if ok then asset=result else fail("本地内嵌封面导入失败");return end
                end
            end
        end
        if not current() then return end
        if not asset and uri=="" and song.kind=="gd" then
            local resolved,err=automaticCoverURI(song,false)
            if not current() then return end
            if not resolved then fail("封面元数据："..tostring(err));return end
            uri=resolved
        end
        if not asset and uri=="" then
            if current() then coverStatus("empty",song.kind=="file" and "文件未包含可读取的封面，可在设置中手动添加" or "曲目未提供封面，可在设置中手动添加") end
            return
        end
        if not asset and (uri:match("^rbxassetid://%d+$") or uri:match("^rbxthumb://")) then
            asset=uri
        elseif not asset then
            if not uri:match("^https://[%w%._%-]+") then fail("封面地址不是有效的 HTTPS 或 Roblox 图片资源");return end
            if not FILE_ASSET or not STORAGE_OK then fail("此环境不能把外部图片导入为纹理；可以填写 Roblox 图片资源 ID");return end
            local basename=(ROOT_OK and ROOT.."/" or "OpaiMusic_").."cover_v3_"..keyFor(uri)
            local path=nil
            for _,ext in ipairs({"png","jpg","webp"}) do
                local candidate=basename.."."..ext
                local cached=tryRead(candidate)
                if cached and imageFormat(cached)==ext then path=candidate;break end
            end
            if not path then
                if not REQUEST then fail("尚无封面缓存，当前环境缺少网络请求接口");return end
                local bytes,err,headers,code=httpGet(uri)
                if not current() then return end
                -- A 404 may be an expired automatic image URL. Reacquire metadata
                -- once, matching the exact track ID; never retry access denials.
                if not bytes and code==404 and song.kind=="gd" and not song.customCover then
                    local fresh=automaticCoverURI(song,true)
                    if not current() then return end
                    if fresh and fresh~=uri then
                        uri=fresh
                        basename=(ROOT_OK and ROOT.."/" or "OpaiMusic_").."cover_v3_"..keyFor(uri)
                        bytes,err=httpGet(uri)
                    end
                end
                if not current() then return end
                if not bytes then fail("下载失败："..tostring(err).."；可重新搜索该曲目或设置自定义封面");return end
                if #bytes>6*1024*1024 then fail("图片超过 6 MB，请换用较小封面");return end
                local ext=imageFormat(bytes)
                if not ext then fail("地址返回的不是 PNG、JPEG 或 WebP 图片，可能返回了网页或错误信息");return end
                path=basename.."."..ext
                if not saveText(path,bytes) then fail("封面缓存写入失败");return end
            end
            local ok,result=pcall(FILE_ASSET,path)
            if not ok or type(result)~="string" or result=="" then fail("图片文件无法导入为纹理");return end
            asset=result
        end
        if not current() then return end
        loadCoverTexture(asset,cacheKey,song,current,fail)
    end)
end

UI.retryCoverButton.MouseButton1Click:Connect(function()
    local song=currentSong()
    if not song then coverStatus("empty","尚未选择歌曲");return end
    resetCover("正在重试")
    resolveCover(song,generation)
end)
local function nextSong(delta)
    if #queue == 0 then return end
    local target = index + delta
    if target < 1 then target = #queue end
    if target > #queue then target = 1 end
    -- playAt is declared below; this function is assigned after its declaration.
    return target
end
local playAt
playAt = function(target)
    local song = queue[target]
    if not song then setStatus("请先添加歌曲", BAD); return end
    generation = generation + 1
    local myGeneration = generation
    if sound then pcall(function() sound:Stop(); sound:Destroy() end) end
    sound = nil
    index = target
    clearWorldScenes()
    resetCover("正在准备当前曲目")
    resolveCover(song,myGeneration)
    currentLyrics = parseSongLyrics(song)
    currentTranslations = parseLyrics(song.translation or "")
    updateControls()
    refreshList()
    persist()
    if ensureGDLyrics then ensureGDLyrics(song) end
    setStatus("正在准备音频：" .. song.title, ACCENT)
    task.spawn(function()
        local ok, result, err = pcall(convertToSoundId, song)
        if not alive or myGeneration ~= generation then return end
        if not ok then setStatus("加载失败：" .. clean(result, 100), BAD); return end
        if not result then setStatus(err or "音源无法播放", BAD); return end
        local s = Instance.new("Sound")
        s.Name = "OpaiMusicSUNC_Audio"
        s.Volume = volume
        s.Looped = repeatOne
        s.SoundId = result
        s.Parent = SoundService
        sound = s
        table.insert(connections, s.Ended:Connect(function()
            if not alive or sound ~= s or repeatOne then return end
            task.defer(function()
                if alive and sound == s then
                    if index < #queue then playAt(index + 1)
                    else updateControls(); setStatus("播放列表已结束") end
                end
            end)
        end))
        local successPlay, why = pcall(function() s:Play() end)
        if not successPlay then
            setStatus("Sound 播放失败：" .. clean(why, 90), BAD)
        else
            setStatus("已发送播放指令 · 等待音频载入", ACCENT)
            task.delay(12, function()
                if alive and sound == s and not s.IsLoaded then
                    setStatus("音频没有载入：可能不支持此格式或执行器自定义音频", BAD)
                end
            end)
        end
        updateControls()
    end)
end
local function togglePlay()
    if not sound then
        playAt(index > 0 and index or 1)
        return
    end
    if sound.IsPlaying then sound:Pause()
    else sound:Resume() end
    updateControls()
end
local function moveSong(delta)
    local target = nextSong(delta)
    if target then playAt(target) end
end

UI.favoriteKey=function(song) return song.kind..":"..(song.source or "")..":"..song.value end
UI.items=function()
    if mode=="results" then return searchResults end
    if mode=="favorites" then
        local items={}
        for _,song in pairs(UI.favorites) do
            if type(song)=="table" and type(song.kind)=="string" and type(song.value)=="string" then items[#items+1]=song end
        end
        table.sort(items,function(a,b) return (a.title or "")<(b.title or "") end)
        return items
    end
    return queue
end
local function updateRowColors()
    for _,tab in ipairs({Widgets.queueTab,Widgets.resultTab,UI.favoriteTab}) do tab.BackgroundColor3=SIDEBAR;tab.TextColor3=WHITE;if UI.navLabels[tab] then UI.navLabels[tab].TextColor3=WHITE end end
    local chosen=mode=="results" and Widgets.resultTab or mode=="favorites" and UI.favoriteTab or Widgets.queueTab
    chosen.BackgroundColor3=Color3.fromRGB(47,46,46)
    chosen.TextColor3=ACCENT
    if UI.navLabels[chosen] then UI.navLabels[chosen].TextColor3=ACCENT end
end
UI.reflowRows=function()
    local width=list.Size.X.Offset-4
    for _,row in ipairs(UI.rows or {}) do
        row.root.Size=UDim2.fromOffset(width,56)
        row.hit.Size=UDim2.new(1,-42,1,0)
        row.title.Size=UDim2.fromOffset(math.max(20,width-205),20)
        row.artist.Size=UDim2.fromOffset(math.max(20,width-205),16)
        row.time.Position=UDim2.fromOffset(width-100,18)
        row.favorite.Position=UDim2.fromOffset(width-38,10)
    end
end
refreshList=function()
    for _,child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    UI.rows={}
    local items=UI.items()
    updateRowColors()
    for i,song in ipairs(items) do
        local selected=currentSong() and UI.favoriteKey(currentSong())==UI.favoriteKey(song)
        local item=frame(list,UDim2.new(),UDim2.fromOffset(700,56),selected and TRACKACTIVE or i%2==1 and Color3.fromRGB(32,32,32) or PANEL,5)
        item.LayoutOrder=i
        local hit=button(item,"",UDim2.new(),UDim2.new(1,-42,1,0),selected and TRACKACTIVE or item.BackgroundColor3,WHITE)
        hit.BackgroundTransparency=1
        text(hit,tostring(i),UDim2.fromOffset(8,0),UDim2.fromOffset(22,56),12,MUTED).TextXAlignment=Enum.TextXAlignment.Right
        local cover=frame(hit,UDim2.fromOffset(42,7),UDim2.fromOffset(42,42),Color3.fromRGB(52,52,52),4)
        local note=text(cover,"♫",UDim2.new(),UDim2.fromScale(1,1),20,MUTED,true)
        note.TextXAlignment=Enum.TextXAlignment.Center
        local art=coverImage(cover)
        art.ZIndex=3
        if selected and UI.coverState=="ready" then art.Image=Widgets.infoCoverImage.Image;art.Visible=true;note.Visible=false end
        local name=text(hit,song.title or "未命名",UDim2.fromOffset(96,7),UDim2.fromOffset(440,20),14,WHITE)
        local artist=text(hit,song.artist or "",UDim2.fromOffset(96,32),UDim2.fromOffset(440,16),12,selected and Color3.fromRGB(227,204,198) or MUTED)
        local time=text(item,song.duration and clock(song.duration) or "—:—",UDim2.fromOffset(600,18),UDim2.fromOffset(48,20),12,MUTED)
        local key=UI.favoriteKey(song)
        local favorite=button(item,"",UDim2.fromOffset(662,10),UDim2.fromOffset(32,36),item.BackgroundColor3,UI.favorites[key] and ACCENT or MUTED)
        favorite.BackgroundTransparency=1;favorite.TextSize=20
        musicIcon(favorite,"heart",UDim2.fromOffset(6,8),20,UI.favorites[key] and ACCENT or MUTED)
        favorite.MouseButton1Click:Connect(function()
            if UI.favorites[key] then UI.favorites[key]=nil else UI.favorites[key]=song end
            persist();refreshList()
        end)
        hit.MouseButton1Click:Connect(function()
            if mode=="queue" then playAt(i)
            else local at=appendSong(song);if at then playAt(at) end end
        end)
        UI.rows[#UI.rows+1]={root=item,hit=hit,title=name,artist=artist,time=time,favorite=favorite,art=art,note=note,song=song}
    end
    list.CanvasSize=UDim2.fromOffset(0,math.max(0,#items*59-3))
    heading.Text=mode=="results" and "搜索结果" or mode=="favorites" and "本地收藏" or "我的音乐"
    Widgets.heroSubtitle.Text=#items.." 首歌曲"..(mode=="favorites" and " · 保存在本机" or "")
    if #items==0 then
        text(list,mode=="favorites" and "还没有收藏歌曲，点击歌曲旁的爱心添加" or mode=="results" and "搜索并选择一首歌曲开始播放" or "播放列表为空，搜索音乐或在设置中添加音频",UDim2.fromOffset(8,16),UDim2.new(1,-20,0,52),13,MUTED)
    end
    UI.reflowRows()
end

local function detectSong(value)
    value = clean(value, 1800)
    if value == "" then return nil end
    local song = {title = "", artist = "本地音源", source = "", lyricId = "", lyrics = ""}
    -- Optional manual naming format: "My Song | https://example.org/audio.mp3"
    local manual, rest = value:match("^(.-)%s+|%s+(.+)$")
    if manual and rest then song.title = clean(manual, 75); value = rest end
    if value:match("^https://") then
        song.kind = "url"
        song.value = value
        song.title = song.title ~= "" and song.title or clean(value:match("/([^/?#]+)") or "网络音频", 65)
        song.artist = "HTTPS 音频直链"
    elseif value:match("^rbxassetid://%d+$") or value:match("^%d+$") then
        song.kind = "asset"
        song.value = value
        song.title = song.title ~= "" and song.title or "Roblox Audio " .. (value:match("%d+") or "")
        song.artist = "Roblox 音频资源"
    elseif value:lower():match("%.mp3$") or value:lower():match("%.ogg$") or value:lower():match("%.wav$") then
        song.kind = "file"
        song.value = value
        song.title = song.title ~= "" and song.title or clean(value:match("([^/\\]+)$") or "本地歌曲", 75)
    else
        return nil
    end
    return song
end

local function addFromInput()
    local song = detectSong(Widgets.searchBox.Text)
    if not song then
        setStatus("请输入 HTTPS 音频直链、rbxassetid://数字 或本地 MP3/OGG/WAV 文件路径", BAD)
        return
    end
    local at = appendSong(song)
    if at then
        Widgets.searchBox.Text = ""
        mode = "queue"
        refreshList()
        setStatus("已添加：" .. song.title, ACCENT)
        playAt(at)
    end
end
local function searchGD()
    local query = clean(Widgets.searchBox.Text, 130)
    if query == "" then setStatus("请输入要搜索的歌名", BAD); return end
    if not REQUEST then setStatus("此执行器不支持 HTTP request", BAD); return end
    if busy then return end
    busy = true
    setStatus("正在搜索 GD 音乐台 · " .. gdSource, ACCENT)
    task.spawn(function()
        local data, err = gdAPI({types = "search", source = gdSource, name = query, count = 20, pages = 1})
        if not alive then return end
        busy = false
        if not data then setStatus(err, BAD); return end
        searchResults = {}
        for _, item in ipairs(data) do
            if type(item) == "table" and item.id then
                local artists = item.artist
                if type(artists) == "table" then artists = table.concat(artists, ", ") end
                table.insert(searchResults, {
                    kind = "gd", value = tostring(item.id),
                    title = clean(item.name or "未命名", 75),
                    artist = clean(artists or "未知歌手", 75),
                    source = clean(item.source or gdSource, 20),
                    lyricId = clean(item.lyric_id or item.id, 128), lyrics = "", translation="", yrc="",
                    picId=clean(item.pic_id or item.picId or "",4096),customCover=false,
                    cover="",metadataCover=clean(item.cover or item.cover_url or item.pic_url or (type(item.al)=="table" and item.al.picUrl) or "",4096),
                })
            end
        end
        mode = "results"
        refreshList()
        setStatus("搜索到 " .. #searchResults .. " 首曲目（可播放性由音源权限决定）", ACCENT)
    end)
end
ensureGDLyrics = function(song)
    if not song or song.kind ~= "gd" or song.lyrics ~= "" then return end
    local sourceIndex = index
    task.spawn(function()
        local data = gdAPI({types = "lyric", source = song.source, id = song.lyricId ~= "" and song.lyricId or song.value})
        if not alive or index ~= sourceIndex or queue[index] ~= song then return end
        if type(data)=="table" then
            local lr=type(data.lyric)=="table" and data.lyric.lyric or data.lyric
            local tr=type(data.tlyric)=="table" and data.tlyric.lyric or data.tlyric
            local yr=type(data.yrc)=="table" and data.yrc.lyric or data.yrc
            if type(lr)=="string" then song.lyrics=string.sub(lr,1,90000) end
            if type(tr)=="string" then song.translation=string.sub(tr,1,90000) end
            if type(yr)=="string" then song.yrc=string.sub(yr,1,90000) end
            currentLyrics=parseSongLyrics(song)
            currentTranslations=parseLyrics(song.translation or "")
            clearWorldScenes()
            persist()
        end
    end)
end

local function draggable(handle, object, clickCallback, companion)
    local tracking, touchInput, origin, original, moved = false, nil, nil, nil, false
    table.insert(connections, handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        tracking, touchInput, origin, original, moved = true, input, input.Position, object.Position, false
    end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if not tracking then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input ~= touchInput then return end
        local delta = input.Position - origin
        if delta.Magnitude > 7 then moved = true end
        if moved then
            local pos = UDim2.new(original.X.Scale, original.X.Offset + delta.X, original.Y.Scale, original.Y.Offset + delta.Y)
            object.Position = pos
            local camera=workspace.CurrentCamera
            if camera then
                local vp=camera.ViewportSize
                local at,size=object.AbsolutePosition,object.AbsoluteSize
                local dx=clamp(at.X,4,math.max(4,vp.X-size.X-4))-at.X
                local dy=clamp(at.Y,4,math.max(4,vp.Y-size.Y-4))-at.Y
                object.Position=UDim2.new(pos.X.Scale,pos.X.Offset+dx,pos.Y.Scale,pos.Y.Offset+dy)
            end
            if companion then companion.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + 4) end
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if not tracking or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input ~= touchInput) then return end
        tracking = false
        if not moved and clickCallback then clickCallback() end
    end))
end

local function syncHudVisibility()
    local hasTrack=(UI.editor and UI.editor.enabled) or (currentSong()~=nil and sound~=nil)
    Widgets.infoHud.Visible=(UI.editor and UI.editor.enabled) or (hasTrack and hudEnabled("info",true))
    Widgets.lyricsHud.Visible=(UI.editor and UI.editor.enabled) or (hasTrack and hudEnabled("lyrics",true))
    Widgets.spectrumHud.Visible=(UI.editor and UI.editor.enabled) or (hasTrack and hudEnabled("spectrum",true))
end
local function setPanelVisible(show)
    UI.panelEpoch=UI.panelEpoch+1
    local ticket=UI.panelEpoch
    panelVisible=show
    -- Cancel the old transition before beginning the new one.
    if UI.panelTween then UI.panelTween:Cancel() end
    if UI.dimTween then UI.dimTween:Cancel() end
    if show then
        if not panel.Visible then Widgets.panelScale.Scale=UI.panelBaseScale*.96 end
        panel.Visible=true
        Widgets.dim.Visible=true
        UI.panelTween=tween(Widgets.panelScale,{Scale=UI.panelBaseScale},.25)
        UI.dimTween=tween(Widgets.dim,{BackgroundTransparency=.87},.2)
    elseif panel.Visible then
        UI.panelTween=tween(Widgets.panelScale,{Scale=UI.panelBaseScale*.96},.18)
        UI.dimTween=tween(Widgets.dim,{BackgroundTransparency=1},.18)
        task.delay(.19,function()
            if alive and UI.panelEpoch==ticket and not panelVisible then
                panel.Visible=false
                Widgets.dim.Visible=false
                Widgets.panelScale.Scale=UI.panelBaseScale
            end
        end)
    else
        Widgets.dim.Visible=false
        Widgets.panelScale.Scale=UI.panelBaseScale
    end
    Widgets.toggleWindow.Visible=false
    Widgets.worldOptions.Visible=false
    syncHudVisibility()
end

minimize.MouseButton1Click:Connect(function() setPanelVisible(false) end)

Widgets.hudTop.MouseButton1Click:Connect(function()
    Widgets.toggleWindow.Visible=not Widgets.toggleWindow.Visible
    Widgets.worldOptions.Visible=Widgets.toggleWindow.Visible
end)
local function updateHudButtons()
    Widgets.hudInfoToggle.Text = (hudEnabled("info",true) and "✓ " or "○ ") .. "歌曲HUD"
    Widgets.hudLyricsToggle.Text = (hudEnabled("lyrics",true) and "✓ " or "○ ") .. "歌词HUD"
    Widgets.hudSpectrumToggle.Text = (hudEnabled("spectrum",true) and "✓ " or "○ ") .. "音量条"
    Widgets.worldToggle.Text = (hudEnabled("world",false) and "✓ " or "○ ") .. "Dango3D"
    Widgets.islandLyricsToggle.Text = (hudEnabled("islandLyrics",true) and "✓ " or "○ ") .. "岛歌词"
    Widgets.infoHud.Visible=currentSong()~=nil and sound~=nil and hudEnabled("info",true)
    Widgets.lyricsHud.Visible=currentSong()~=nil and sound~=nil and hudEnabled("lyrics",true)
    Widgets.spectrumHud.Visible=currentSong()~=nil and sound~=nil and hudEnabled("spectrum",true)
end
for _,setting in ipairs({{Widgets.hudInfoToggle,"info"},{Widgets.hudLyricsToggle,"lyrics"},{Widgets.hudSpectrumToggle,"spectrum"},{Widgets.worldToggle,"world"},{Widgets.islandLyricsToggle,"islandLyrics"}}) do
    setting[1].MouseButton1Click:Connect(function()
        hudSettings[setting[2]]=not hudEnabled(setting[2],setting[2]~="world")
        updateHudButtons();persist()
    end)
end
updateHudButtons()
local function updateWorldKnobs()
    Widgets.worldDistanceDown.Text="距离 − "..math.floor(lyricDistance)
    Widgets.worldScaleUp.Text=string.format("放大 %.1f",lyricScale)
    Widgets.worldSpread.Text="扩散 "..math.floor(lyricSpread)
    Widgets.worldPop.Text=(hudEnabled("wordPop",true) and "✓ " or "○ ").."弹跳"
    Widgets.worldWiggle.Text=(hudEnabled("wiggle",true) and "✓ " or "○ ").."抖动"
end
for _,entry in ipairs({
    {Widgets.worldDistanceDown,function() lyricDistance=clamp(lyricDistance-2,3,40);hudSettings.distance=lyricDistance end},
    {Widgets.worldDistanceUp,function() lyricDistance=clamp(lyricDistance+2,3,40);hudSettings.distance=lyricDistance end},
    {Widgets.worldScaleDown,function() lyricScale=clamp(lyricScale-.2,.5,3);hudSettings.scale=lyricScale end},
    {Widgets.worldScaleUp,function() lyricScale=clamp(lyricScale+.2,.5,3);hudSettings.scale=lyricScale end},
    {Widgets.worldSpread,function() lyricSpread=lyricSpread>=60 and 0 or lyricSpread+15;hudSettings.spread=lyricSpread end},
    {Widgets.worldPop,function() hudSettings.wordPop=not hudEnabled("wordPop",true) end},
    {Widgets.worldWiggle,function() hudSettings.wiggle=not hudEnabled("wiggle",true) end}
}) do
    entry[1].MouseButton1Click:Connect(function() entry[2]();updateWorldKnobs();persist() end)
end
updateWorldKnobs()
Widgets.heroPlay.MouseButton1Click:Connect(function()
    local items=UI.items()
    if #items==0 then setStatus("先搜索音乐或在设置中添加音频",BAD);return end
    if mode=="queue" then playAt(1)
    else local at=appendSong(items[1]);if at then playAt(at) end end
end)

-- HUD editor owns all HUD transforms. Normal playback never starts a HUD drag.
local Editor={enabled=false,selected=nil,pointer=nil,entries={}}
UI.editor=Editor
hudSettings.transforms=type(hudSettings.transforms)=="table" and hudSettings.transforms or {}
local function finite(value,default,lo,hi)
    local n=tonumber(value)
    if not n or n~=n or n==math.huge or n==-math.huge then return default end
    return clamp(n,lo,hi)
end
local function viewport()
    local cam=workspace.CurrentCamera
    local vp=cam and cam.ViewportSize or Vector2.new(1280,800)
    return Vector2.new(math.max(1,vp.X),math.max(1,vp.Y))
end
local function point(input) return Vector2.new(input.Position.X,input.Position.Y) end
local function primary(input)
    return input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch
end
local function samePointer(input,owner,ending)
    if owner.UserInputType==Enum.UserInputType.Touch then return input==owner end
    return input.UserInputType==(ending and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseMovement)
end
local function saveEditor()
    for name,entry in pairs(Editor.entries) do
        local t=entry.transform
        hudSettings.transforms[name]={x=t.x,y=t.y,scale=t.scale,rotation=((t.rotation+180)%360)-180}
    end
    persist()
end
local overlay=frame(gui,UDim2.new(),UDim2.fromScale(1,1),BG)
overlay.Name="HudEditorOverlay"
overlay.BackgroundTransparency=1
overlay.ZIndex=100
overlay.Visible=false
local toolbar=frame(overlay,UDim2.new(),UDim2.fromOffset(96,42),Color3.fromRGB(30,27,27),10)
toolbar.Name="SelectedHudTools"
toolbar.AnchorPoint=Vector2.new(.5,1)
toolbar.Visible=false
local scaleButton=button(toolbar,"",UDim2.fromOffset(5,4),UDim2.fromOffset(38,34),STRIP,WHITE)
scaleButton.Name="ScaleHandle"
musicIcon(scaleButton,"scale",UDim2.fromOffset(9,7),20,WHITE)
local rotateButton=button(toolbar,"",UDim2.fromOffset(53,4),UDim2.fromOffset(38,34),STRIP,WHITE)
rotateButton.Name="RotateHandle"
musicIcon(rotateButton,"rotate",UDim2.fromOffset(9,7),20,WHITE)
local bar=frame(overlay,UDim2.new(.5,0,1,-16),UDim2.fromOffset(420,72),Color3.fromRGB(25,23,23),10)
bar.Name="HudEditorActions"
bar.AnchorPoint=Vector2.new(.5,1)
local hint=text(bar,"点选 HUD 后拖动；按住按钮缩放或旋转",UDim2.fromOffset(12,5),UDim2.new(1,-24,0,24),12,MUTED)
local done=button(bar,"完成编辑",UDim2.fromOffset(12,34),UDim2.fromOffset(120,30),ACCENT,Color3.fromRGB(57,16,12))
local reset=button(bar,"重置选中 HUD",UDim2.fromOffset(144,34),UDim2.fromOffset(150,30),STRIP,WHITE)
Editor.scaleButton=scaleButton;Editor.rotateButton=rotateButton
Editor.doneButton=done;Editor.resetButton=reset;Editor.toolbar=toolbar
function Editor.updateTools()
    local vp=viewport()
    bar.Size=UDim2.fromOffset(math.min(420,vp.X-24),72)
    local entry=Editor.selected
    toolbar.Visible=Editor.enabled and entry~=nil
    if not toolbar.Visible then return end
    local t=entry.transform
    local size=entry.object.AbsoluteSize
    local angle=math.rad(t.rotation)
    local halfH=(math.abs(math.sin(angle))*size.X+math.abs(math.cos(angle))*size.Y)/2
    local cx,cy=entry.center and entry.center.X or t.x*vp.X,entry.center and entry.center.Y or t.y*vp.Y
    local y=cy-halfH-10
    if y<48 then y=cy+halfH+52 end
    toolbar.Position=UDim2.fromOffset(clamp(cx,54,math.max(54,vp.X-54)),clamp(y,48,math.max(48,vp.Y-92)))
end
function Editor.apply(name)
    local entry=Editor.entries[name]
    if not entry then return end
    local target,t=entry.object,entry.transform
    local vp=viewport()
    local w,h=math.max(1,target.Size.X.Offset),math.max(1,target.Size.Y.Offset)
    local base=name=="island" and math.min(1,vp.X/900) or math.min(1,(vp.X-24)/w,(vp.Y-24)/h)
    local a=math.rad(t.rotation)
    local rw=math.abs(math.cos(a))*w+math.abs(math.sin(a))*h
    local rh=math.abs(math.sin(a))*w+math.abs(math.cos(a))*h
    local actual=math.max(.05,math.min(base*t.scale,(vp.X-16)/math.max(1,rw),(vp.Y-16)/math.max(1,rh)))
    entry.scale.Scale=actual
    target.Rotation=t.rotation
    local halfW,halfH=rw*actual/2,rh*actual/2
    local x=clamp(t.x*vp.X,math.min(vp.X/2,halfW+8),math.max(vp.X/2,vp.X-halfW-8))
    local y=clamp(t.y*vp.Y,math.min(vp.Y/2,halfH+8),math.max(vp.Y/2,vp.Y-halfH-8))
    -- Keep requested normalized coordinates across viewport resizes. Pointer actions
    -- explicitly commit their clamped position before saving.
    target.Position=UDim2.fromScale(x/vp.X,y/vp.Y)
    entry.center=Vector2.new(x,y)
    Editor.updateTools()
end
function Editor.reflow()
    if Editor.pointer and Editor.finishPointer then Editor.finishPointer(nil) end
    for name in pairs(Editor.entries) do Editor.apply(name) end
end
function Editor.select(name)
    if not Editor.enabled then return end
    if Editor.selected then
        Editor.selected.outline.Enabled=false
        Editor.selected.object.ZIndex=Editor.selected.zIndex
    end
    Editor.selected=Editor.entries[name]
    if Editor.selected then
        Editor.selected.outline.Enabled=true
        Editor.selected.object.ZIndex=60
        hint.Text=Editor.selected.label.."：拖动位置 / 按住按钮缩放或旋转"
    end
    Editor.updateTools()
end
local function beginTransform(mode,entry,input)
    if not Editor.enabled or Editor.pointer or not primary(input) then return end
    Editor.select(entry.name)
    local p=point(input)
    local center=entry.center
    local offset=p-center
    Editor.pointer={mode=mode,entry=entry,owner=input,start=p,center=center,
        scale=entry.transform.scale,rotation=entry.transform.rotation,
        distance=math.max(8,offset.Magnitude),lastAngle=math.atan2(offset.Y,offset.X)}
end
local vp=viewport()
for _,item in ipairs({{"island","灵动岛",Widgets.island,Widgets.islandScale},
    {"info","歌曲 HUD",Widgets.infoHud},{"lyrics","歌词 HUD",Widgets.lyricsHud},
    {"spectrum","音量可视化",Widgets.spectrumHud}}) do
    local name,label,target,scale=item[1],item[2],item[3],item[4]
    if not scale then
        scale=target:FindFirstChild("ResponsiveHudScale")
        if not scale then scale=Instance.new("UIScale");scale.Name="ResponsiveHudScale";scale.Parent=target end
    end
    local at,size=target.AbsolutePosition,target.AbsoluteSize
    local defaults={x=(at.X+size.X/2)/vp.X,y=(at.Y+size.Y/2)/vp.Y,scale=1,rotation=0}
    local saved=type(hudSettings.transforms[name])=="table" and hudSettings.transforms[name] or {}
    local transform={x=finite(saved.x,defaults.x,0,1),y=finite(saved.y,defaults.y,0,1),
        scale=finite(saved.scale,1,.35,3),rotation=finite(saved.rotation,0,-3600,3600)}
    target.AnchorPoint=Vector2.new(.5,.5)
    local outline=Instance.new("UIStroke")
    outline.Name="HudEditorSelection"
    outline.Color=ACCENT;outline.Thickness=1.8;outline.Transparency=0
    outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    pcall(function() outline.BorderStrokePosition=Enum.BorderStrokePosition.Outer;outline.ZIndex=30 end)
    outline.Enabled=false;outline.Parent=target
    local entry={name=name,label=label,object=target,scale=scale,outline=outline,
        defaults=defaults,transform=transform,zIndex=target.ZIndex}
    Editor.entries[name]=entry
    table.insert(connections,target.InputBegan:Connect(function(input)
        if Editor.enabled then beginTransform("move",entry,input)
        elseif name=="island" and primary(input) and not Editor.pointer then
            Editor.pointer={mode="islandClick",owner=input,start=point(input),moved=false}
        end
    end))
    table.insert(connections,target:GetPropertyChangedSignal("Size"):Connect(function() Editor.apply(name) end))
end
table.insert(connections,scaleButton.InputBegan:Connect(function(input)
    if Editor.selected then beginTransform("scale",Editor.selected,input) end
end))
table.insert(connections,rotateButton.InputBegan:Connect(function(input)
    if Editor.selected then beginTransform("rotate",Editor.selected,input) end
end))
table.insert(connections,UserInputService.InputChanged:Connect(function(input)
    local drag=Editor.pointer
    if not drag or not samePointer(input,drag.owner,false) then return end
    local p=point(input)
    if drag.mode=="islandClick" then drag.moved=drag.moved or (p-drag.start).Magnitude>7;return end
    if not Editor.enabled then return end
    local entry=drag.entry
    local t=entry.transform
    local vp=viewport()
    if drag.mode=="move" then
        local delta=p-drag.start
        t.x=clamp((drag.center.X+delta.X)/vp.X,0,1)
        t.y=clamp((drag.center.Y+delta.Y)/vp.Y,0,1)
    elseif drag.mode=="scale" then
        t.scale=clamp(drag.scale*math.max(8,(p-drag.center).Magnitude)/drag.distance,.35,3)
    elseif drag.mode=="rotate" then
        local offset=p-drag.center
        local angle=math.atan2(offset.Y,offset.X)
        local delta=(angle-drag.lastAngle+math.pi)%(2*math.pi)-math.pi
        t.rotation=t.rotation+math.deg(delta)
        drag.lastAngle=angle
    end
    Editor.apply(entry.name)
end))
local function finishPointer(input)
    local drag=Editor.pointer
    if not drag or (input and not samePointer(input,drag.owner,true)) then return end
    Editor.pointer=nil
    if drag.mode=="islandClick" then
        if input and not drag.moved then setPanelVisible(not panelVisible) end
    else
        local vp=viewport()
        local center=drag.entry.center
        drag.entry.transform.x=center.X/vp.X;drag.entry.transform.y=center.Y/vp.Y
        saveEditor()
    end
end
table.insert(connections,UserInputService.InputEnded:Connect(finishPointer))
Editor.finishPointer=finishPointer
pcall(function() table.insert(connections,UserInputService.WindowFocusReleased:Connect(function() finishPointer(nil) end)) end)
function Editor.setEnabled(enabled)
    finishPointer(nil)
    if Editor.selected then
        Editor.selected.outline.Enabled=false;Editor.selected.object.ZIndex=Editor.selected.zIndex
    end
    Editor.selected=nil
    Editor.enabled=enabled
    overlay.Visible=enabled
    toolbar.Visible=false
    hint.Text="点选 HUD 后拖动；按住按钮缩放或旋转"
    if enabled then
        setPanelVisible(false)
        syncHudVisibility()
    else
        saveEditor()
        syncHudVisibility()
        setPanelVisible(true)
        UI.settings.Visible=true
    end
    Editor.reflow()
end
done.MouseButton1Click:Connect(function() Editor.setEnabled(false) end)
reset.MouseButton1Click:Connect(function()
    finishPointer(nil)
    local entry=Editor.selected
    if not entry then return end
    for key,value in pairs(entry.defaults) do entry.transform[key]=value end
    Editor.apply(entry.name);saveEditor()
end)
UI.hudEditButton.MouseButton1Click:Connect(function() Editor.setEnabled(true) end)
table.insert(connections,RunService.RenderStepped:Connect(function()
    if Editor.enabled then Editor.updateTools() end
end))
Editor.reflow()

draggable(title, panel)
Widgets.playButton.MouseButton1Click:Connect(togglePlay)
Widgets.previous.MouseButton1Click:Connect(function() moveSong(-1) end)
Widgets.nextButton.MouseButton1Click:Connect(function() moveSong(1) end)
Widgets.loopButton.MouseButton1Click:Connect(function()
    repeatOne = not repeatOne
    if sound then sound.Looped = repeatOne end
    persist(); updateControls()
end)
Widgets.searchButton.MouseButton1Click:Connect(searchGD)
Widgets.addButton.MouseButton1Click:Connect(function()
    UI.settings.Visible=false;UI.importOverlay.Visible=true
end)
UI.importConfirm.MouseButton1Click:Connect(function()
    local previous=Widgets.searchBox.Text
    Widgets.searchBox.Text=UI.importBox.Text
    if detectSong(Widgets.searchBox.Text) then
        addFromInput();UI.importOverlay.Visible=false;UI.importBox.Text=""
    else setStatus("请输入有效的音频地址、Roblox Audio ID 或本地路径",BAD) end
    Widgets.searchBox.Text=previous
end)
UI.importCancel.MouseButton1Click:Connect(function() UI.importOverlay.Visible=false end)
UI.settingsButton.MouseButton1Click:Connect(function() UI.settings.Visible=not UI.settings.Visible;UI.importOverlay.Visible=false end)
UI.backButton.MouseButton1Click:Connect(function() UI.settings.Visible=false end)
UI.favoriteTab.MouseButton1Click:Connect(function() mode="favorites";UI.settings.Visible=false;UI.importOverlay.Visible=false;refreshList() end)
UI.queueNav.MouseButton1Click:Connect(function() mode="queue";UI.settings.Visible=false;UI.importOverlay.Visible=false;refreshList() end)
Widgets.searchBox.FocusLost:Connect(function(enter)
    if enter then
        if detectSong(Widgets.searchBox.Text) then addFromInput() else searchGD() end
    end
end)
Widgets.sourceButton.MouseButton1Click:Connect(function()
    if gdSource == "netease" then gdSource = "joox"
    elseif gdSource == "joox" then gdSource = "bilibili"
    else gdSource = "netease" end
    Widgets.sourceButton.Text = "来源：" .. ({netease="网易云",joox="JOOX",bilibili="哔哩哔哩"})[gdSource]
    persist()
end)
Widgets.sourceButton.Text = "来源：" .. ({netease="网易云",joox="JOOX",bilibili="哔哩哔哩"})[gdSource]
Widgets.queueTab.MouseButton1Click:Connect(function() mode = "queue"; UI.settings.Visible=false;UI.importOverlay.Visible=false;refreshList() end)
Widgets.resultTab.MouseButton1Click:Connect(function() mode = "results"; UI.settings.Visible=false;UI.importOverlay.Visible=false;refreshList() end)
Widgets.removeButton.MouseButton1Click:Connect(function()
    generation = generation + 1
    if sound then pcall(function() sound:Stop(); sound:Destroy() end) end
    sound = nil
    queue = {}
    index = 0
    clearWorldScenes()
    currentLyrics = {}
    currentTranslations = {}
    resetCover("尚未选择歌曲")
    mode = "queue"
    refreshList(); persist(); updateControls(); setStatus("已清空播放列表")
end)
Widgets.lyricButton.MouseButton1Click:Connect(function()
    local song = currentSong()
    if not song then setStatus("先选择一首歌曲，再导入歌词", BAD); return end
    Widgets.lyricInput.Text = (song.yrc and song.yrc~="") and song.yrc or song.lyrics or ""
    Widgets.lyricOverlay.Visible = true
end)
Widgets.lyricCancel.MouseButton1Click:Connect(function() Widgets.lyricOverlay.Visible = false end)
Widgets.lyricSave.MouseButton1Click:Connect(function()
    local song = currentSong()
    if song then
        local raw=string.sub(Widgets.lyricInput.Text,1,90000)
        if raw:find("^%[%d+,%d+%]") then song.yrc=raw
        else song.lyrics=raw;song.yrc="" end
        currentLyrics=parseSongLyrics(song)
        currentTranslations=parseLyrics(song.translation or "")
        clearWorldScenes()
        persist()
        setStatus("LRC 歌词已保存：" .. #currentLyrics .. " 句", ACCENT)
    end
    Widgets.lyricOverlay.Visible = false
end)

Widgets.coverButton.MouseButton1Click:Connect(function()
    local s=currentSong()
    if not s then setStatus("先选择正在播放的歌曲",BAD);return end
    Widgets.coverInput.Text=s.cover or ""
    Widgets.lyricOverlay.Visible=false
    Widgets.coverOverlay.Visible=true
end)
Widgets.coverCancel.MouseButton1Click:Connect(function() Widgets.coverOverlay.Visible=false end)
Widgets.coverSave.MouseButton1Click:Connect(function()
    local s=currentSong()
    if not s then return end
    local uri=clean(Widgets.coverInput.Text,4096)
    if uri~="" and not (uri:match("^https?://[%w%._%-]+") or uri:match("^rbxassetid://%d+$") or uri:match("^rbxthumb://") or uri:match("^%d+$")) then
        setStatus("请输入图片 HTTPS 地址或 Roblox 图片资源 ID",BAD);return
    end
    s.cover=uri
    s.customCover=uri~=""
    resetCover(uri=="" and "已清除自定义封面" or "正在加载新封面")
    Widgets.coverOverlay.Visible=false
    if uri=="" then
        resetCover("已清除自定义封面")
    end
    if uri~="" then resolveCover(s,generation) end
    persist()
    setStatus(uri=="" and "已清除自定义封面" or "正在缓存专辑封面",ACCENT)
end)
local function slider(hit, fill, callback, onFinished)
    local dragging = false
    local owner = nil
    local function setAt(x)
        local fraction = clamp((x - hit.AbsolutePosition.X) / math.max(1, hit.AbsoluteSize.X), 0, 1)
        fill.Size = UDim2.fromScale(fraction, 1)
        callback(fraction)
    end
    table.insert(connections, hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then return end
            dragging = true; owner=input; setAt(input.Position.X)
        end
    end))
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and ((owner and owner.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement) or input==owner) then
            setAt(input.Position.X)
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and input==owner then
                dragging = false; owner=nil
                if onFinished then onFinished() end
            end
        end
    end))
end
slider(Widgets.seekButton, Widgets.seekFill, function(fraction)
    if not sound or sound.TimeLength <= 0 then return end
    sound.TimePosition = sound.TimeLength * fraction
end)
slider(Widgets.volHit, Widgets.volFill, function(fraction)
    volume = fraction
    if sound then sound.Volume = volume end
    Widgets.volLabel.Text = tostring(math.floor(volume * 100 + .5)) .. "%"
end, persist)

local t = 0
local lastLrc = ""
local lastPlayback = false
local fps = 60
local lastIslandIdleRefresh = 0
table.insert(connections, RunService.RenderStepped:Connect(function(dt)
    if not alive then return end
    fps = fps * .89 + (1 / math.max(dt, .001)) * .11
    UI.fps=fps
    t = t + dt
    if t < .04 then return end
    t = 0
    local playing = sound ~= nil and sound.IsPlaying
    syncHudVisibility()
    local duration = sound and sound.TimeLength or 0
    local pos = sound and sound.TimePosition or 0
    Widgets.seekFill.Size = UDim2.fromScale(duration > 0 and clamp(pos/duration, 0, 1) or 0, 1)
    Widgets.elapsedLabel.Text = clock(pos)
    Widgets.durationLabel.Text = clock(duration)
    Widgets.islandFill.Size = UDim2.fromScale(duration > 0 and clamp(pos/duration, 0, 1) or 0, 1)
    if playing ~= lastPlayback then lastPlayback = playing; updateControls() end
    if os.clock() - lastIslandIdleRefresh >= .45 then
        lastIslandIdleRefresh=os.clock()
        updateIsland()

    end
    local value = currentLrcLine(pos)
    if value ~= lastLrc then
        lastLrc = value
        lyricLine.Text = value ~= "" and ("♫  " .. value) or "♪  欢迎使用 Opai Music"
    end
    -- SUNC/Roblox lacks per-band FFT; bars follow the measured loudness envelope.
    local amplitude = playing and clamp((tonumber(sound.PlaybackLoudness) or 0) / 470, 0, 1) or 0
    for i,b in ipairs(bars) do
        local wave = .32 + .68 * math.abs(math.sin(os.clock()*4.3+i*.57))
        local target=(UI.editor and UI.editor.enabled and not playing) and (.12+.4*math.sin(i*.23)^2) or amplitude*wave
        local previous=b:GetAttribute("Envelope") or 0
        local envelope=previous+(target-previous)*(1-math.exp(-.04*(target>previous and 22 or 7)))
        b:SetAttribute("Envelope",envelope)
        local h=math.max(1,math.floor(68*envelope+.5))
        b.Size=UDim2.fromOffset(11,h)
        b.Position=UDim2.fromOffset((i-1)*15,70-h)
        b.BackgroundTransparency=.37
    end
    local cueIndex=0
    for i=1,#currentLyrics do
        if currentLyrics[i].at<=pos then cueIndex=i else break end
    end
    local lineNow=currentLyrics[cueIndex] and currentLyrics[cueIndex].text or ""
    local lineNext=currentLyrics[cueIndex+1] and currentLyrics[cueIndex+1].text or ""
    local nowCue=currentLyrics[cueIndex]
    local karaoke,wordIndex=wordMarkup(nowCue,pos)
    -- Original scroller rows (5 visible lines) with 330ms easing.
    updateLyricsScroller(cueIndex,pos)
    if nowCue and nowCue.words and #nowCue.words>0 then
        Widgets.lyricsCurrent.RichText=karaoke~=nil
        Widgets.lyricsCurrent.Text=karaoke or lineNow
    else
        Widgets.lyricsCurrent.RichText=false
    end
    Widgets.infoSong.Text=currentSong() and clean(currentSong().title,42) or "Tritium Music"
    Widgets.infoArtist.Text=currentSong() and clean(currentSong().artist,50) or "Opai HUD Preview"
    Widgets.infoFill.Size=UDim2.fromScale(duration>0 and clamp(pos/duration,0,1) or 0,1)
    Widgets.infoTime.Text=clock(pos)
    Widgets.infoDuration.Text=duration>0 and clock(duration) or "—:—"
    renderWorldScenes(pos,playing,cueIndex)
end))

local function stop()
    if not alive then return end
    alive = false
    if UI.coverPending then UI.coverPending.cancel() end
    generation = generation + 1
    if sound then pcall(function() sound:Stop(); sound:Destroy() end); sound = nil end
    if UI.cameraConnection then UI.cameraConnection:Disconnect() end
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    pcall(clearWorldScenes)

    if GENV.__OpaiMusicSUNCStop == stop then GENV.__OpaiMusicSUNCStop = nil end
end
GENV.__OpaiMusicSUNCStop = stop

UI.cameraConnection=nil
local function fitHuds()
    if UI.editor then UI.editor.reflow();return end
    local cam=workspace.CurrentCamera
    if not cam then return end
    local vp=cam.ViewportSize
    for _,widget in ipairs({Widgets.infoHud,Widgets.lyricsHud,Widgets.spectrumHud}) do
        local scale=widget:FindFirstChild("ResponsiveHudScale")
        if not scale then scale=Instance.new("UIScale");scale.Name="ResponsiveHudScale";scale.Parent=widget end
        scale.Scale=math.max(.05,math.min(1,(vp.X-24)/widget.Size.X.Offset,(vp.Y-24)/widget.Size.Y.Offset))
        local at,size=widget.AbsolutePosition,widget.AbsoluteSize
        local dx=clamp(at.X,12,math.max(12,vp.X-size.X-12))-at.X
        local dy=clamp(at.Y,12,math.max(12,vp.Y-size.Y-12))-at.Y
        local p=widget.Position
        widget.Position=UDim2.new(p.X.Scale,p.X.Offset+dx,p.Y.Scale,p.Y.Offset+dy)
    end
end
local function bindCamera()
    if UI.cameraConnection then UI.cameraConnection:Disconnect() end
    local cam=workspace.CurrentCamera
    if cam then UI.cameraConnection=cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() scaleIsland();scalePanel();fitHuds() end) end
    scaleIsland();scalePanel();fitHuds()
end
table.insert(connections,workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
bindCamera()
-- Optional original typefaces. Native FontFace support varies by file-asset provider;
-- a failed import keeps the visible Arial Bold fallback and the player functional.
task.spawn(function()
    if not FILE_ASSET or not STORAGE_OK then return end
    local source="https://raw.githubusercontent.com/snmwdd/OpaiBounce/6a6bc99a4f0bb96f0a05c5d34f278c3da067c475/public/fonts/"
    local folder=ROOT_OK and ROOT.."/" or "OpaiMusic_"
    for _,item in ipairs({{key="latin",file="GoogleSans-Bold.ttf"},{key="cjk",file="NotoSansSC-Bold.ttf"}}) do
        if not alive then return end
        local path=folder..item.file
        local bytes=tryRead(path)
        if not bytes and REQUEST then
            local body=httpGet(source..item.file)
            if body and #body<16*1024*1024 and (body:sub(1,4)==string.char(0,1,0,0) or body:sub(1,4)=="OTTO") then
                if saveText(path,body) then bytes=body end
            end
        end
        if bytes then
            local ok,face=pcall(function()
                local fontAsset=FILE_ASSET(path)
                local manifest=HttpService:JSONEncode({name="Opai "..item.key,faces={
                    {name="Regular",weight=400,style="normal",assetId=fontAsset},
                    {name="Bold",weight=700,style="normal",assetId=fontAsset}}})
                local familyPath=folder.."font_"..item.key..".json"
                assert(saveText(familyPath,manifest),"font manifest unavailable")
                local family=FILE_ASSET(familyPath)
                game:GetService("TextService"):GetFamilyInfoAsync(family)
                return Font.new(family,Enum.FontWeight.Bold,Enum.FontStyle.Normal)
            end)
            if ok and alive then
                UI.fonts[item.key]=face
                for label in pairs(UI.textNodes) do if label.Parent then pcall(applyFont,label) end end
            end
        end
    end
end)
updateControls()
refreshList()
setStatus(status)
setPanelVisible(false)
if index > 0 then
    -- Do not unexpectedly auto-start audio after rerun. Existing queue is displayed.
    currentLyrics = parseSongLyrics(queue[index])
    currentTranslations = parseLyrics(queue[index].translation or "")
    updateControls()
end
