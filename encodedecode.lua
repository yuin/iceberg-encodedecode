local ibs = require("icebergsupport")
local script_path = ibs.join_path(ibs.CONFIG_DIR, "luamodule")
local icon_app = ibs.join_path(script_path, "encodedecode", "app.png")
local icon_data = ibs.join_path(script_path, "encodedecode", "data.png")

local url = require("socket.url")
local mime = require("mime")

local function utf8char_to_unicode(ch)
  local byte = string.byte
  if #ch == 1 then
    return byte(ch)
  else
    ch1 = byte(ch:sub(1,1))
    if ibs.band(ch1, 0xf0) == 0xf0 then
      ch1 = ibs.band(0x07, ch1)
      ch2 = byte(ch:sub(2,2))
      ch3 = byte(ch:sub(3,3))
      ch4 = byte(ch:sub(4,4))
      return ibs.bor(ibs.blshift(ch1, 18), ibs.blshift(ibs.band(0x3f, ch2), 12), ibs.blshift(ibs.band(0x3f, ch3), 6), ibs.band(0x3f, ch4))
    elseif ibs.band(ch1, 0xe0) == 0xe0 then
      ch1 = ibs.band(0x0f, ch1)
      ch2 = byte(ch:sub(2,2))
      ch3 = byte(ch:sub(3,3))
      return ibs.bor(ibs.blshift(ch1, 12), ibs.blshift(ibs.band(0x3f, ch2), 6), ibs.band(0x3f, ch3))
    elseif ibs.band(ch1, 0xc0) == 0xc0 then
      ch1 = ibs.band(0x1f, ch1)
      ch2 = byte(ch:sub(2,2))
      return ibs.bor(ibs.blshift(ch1, 6), ibs.band(0x3f, ch2))
    end
  end
  return 0
end

local function unicodechar_to_utf8(number) 
  local char = string.char
  if number >= 0x10000 then
    c1 = ibs.bor(0x80, ibs.band(number, 0x3f))
    c2 = ibs.bor(0x80, ibs.band(ibs.brshift(number, 6), 0x3f))
    c3 = ibs.bor(0x80, ibs.band(ibs.brshift(number, 12), 0x3f))
    c4 = ibs.bor(0xf0, ibs.band(ibs.brshift(number, 18), 0x07))
    return char(c4, c3, c2, c1)
  elseif number >= 0x0800 then
    c1 = ibs.bor(0x80, ibs.band(number, 0x3f))
    c2 = ibs.bor(0x80, ibs.band(ibs.brshift(number, 6), 0x3f))
    c3 = ibs.bor(0xe0, ibs.band(ibs.brshift(number, 12), 0x0f))
    return char(c3, c2, c1)
  elseif number >= 0x0080 then
    c1 = ibs.bor(0x80, ibs.band(number, 0x3f))
    c2 = ibs.bor(0xc0, ibs.band(ibs.brshift(number, 6), 0x1f))
    return char(c2, c1)
  else
    return char(number)
  end
end

local htmlentities1 = {
[' '] = '&nbsp;' ,
['¡'] = '&iexcl;' ,
['¢'] = '&cent;' ,
['£'] = '&pound;' ,
['¤'] = '&curren;' ,
['¥'] = '&yen;' ,
['¦'] = '&brvbar;' ,
['§'] = '&sect;' ,
['¨'] = '&uml;' ,
['©'] = '&copy;' ,
['ª'] = '&ordf;' ,
['«'] = '&laquo;' ,
['¬'] = '&not;' ,
['­'] = '&shy;' ,
['®'] = '&reg;' ,
['¯'] = '&macr;' ,
['°'] = '&deg;' ,
['±'] = '&plusmn;' ,
['²'] = '&sup2;' ,
['³'] = '&sup3;' ,
['´'] = '&acute;' ,
['µ'] = '&micro;' ,
['¶'] = '&para;' ,
['·'] = '&middot;' ,
['¸'] = '&cedil;' ,
['¹'] = '&sup1;' ,
['º'] = '&ordm;' ,
['»'] = '&raquo;' ,
['¼'] = '&frac14;' ,
['½'] = '&frac12;' ,
['¾'] = '&frac34;' ,
['¿'] = '&iquest;' ,
['À'] = '&Agrave;' ,
['Á'] = '&Aacute;' ,
['Â'] = '&Acirc;' ,
['Ã'] = '&Atilde;' ,
['Ä'] = '&Auml;' ,
['Å'] = '&Aring;' ,
['Æ'] = '&AElig;' ,
['Ç'] = '&Ccedil;' ,
['È'] = '&Egrave;' ,
['É'] = '&Eacute;' ,
['Ê'] = '&Ecirc;' ,
['Ë'] = '&Euml;' ,
['Ì'] = '&Igrave;' ,
['Í'] = '&Iacute;' ,
['Î'] = '&Icirc;' ,
['Ï'] = '&Iuml;' ,
['Ð'] = '&ETH;' ,
['Ñ'] = '&Ntilde;' ,
['Ò'] = '&Ograve;' ,
['Ó'] = '&Oacute;' ,
['Ô'] = '&Ocirc;' ,
['Õ'] = '&Otilde;' ,
['Ö'] = '&Ouml;' ,
['×'] = '&times;' ,
['Ø'] = '&Oslash;' ,
['Ù'] = '&Ugrave;' ,
['Ú'] = '&Uacute;' ,
['Û'] = '&Ucirc;' ,
['Ü'] = '&Uuml;' ,
['Ý'] = '&Yacute;' ,
['Þ'] = '&THORN;' ,
['ß'] = '&szlig;' ,
['à'] = '&agrave;' ,
['á'] = '&aacute;' ,
['â'] = '&acirc;' ,
['ã'] = '&atilde;' ,
['ä'] = '&auml;' ,
['å'] = '&aring;' ,
['æ'] = '&aelig;' ,
['ç'] = '&ccedil;' ,
['è'] = '&egrave;' ,
['é'] = '&eacute;' ,
['ê'] = '&ecirc;' ,
['ë'] = '&euml;' ,
['ì'] = '&igrave;' ,
['í'] = '&iacute;' ,
['î'] = '&icirc;' ,
['ï'] = '&iuml;' ,
['ð'] = '&eth;' ,
['ñ'] = '&ntilde;' ,
['ò'] = '&ograve;' ,
['ó'] = '&oacute;' ,
['ô'] = '&ocirc;' ,
['õ'] = '&otilde;' ,
['ö'] = '&ouml;' ,
['÷'] = '&divide;' ,
['ø'] = '&oslash;' ,
['ù'] = '&ugrave;' ,
['ú'] = '&uacute;' ,
['û'] = '&ucirc;' ,
['ü'] = '&uuml;' ,
['ý'] = '&yacute;' ,
['þ'] = '&thorn;' ,
['ÿ'] = '&yuml;' ,
['"'] = '&quot;' ,
["'"] = '&#39;' ,
['<'] = '&lt;' ,
['>'] = '&gt;' ,
['&'] = '&amp;'
}

local htmlentities2 = {}
for k, v in pairs(htmlentities1) do
  htmlentities2[v] = k
end

local function html_entity_escape(text) 
  return ibs.regex_gsub(".", Regex.NONE, text, function(re)
    local v = re:group(0)
    if htmlentities1[v] ~= nil then
      return htmlentities1[v]
    elseif #v == 1 then
      return v
    else
      return "&#" .. utf8char_to_unicode(v) .. ";"
    end
  end)
end

local function html_entity_unescape(text)
  local ret = ibs.regex_gsub("&([^#][^;]+);", Regex.NONE, text, function(re)
    return htmlentities2["&" .. re:_1() .. ";"]
  end)
  ret = ibs.regex_gsub("&#(\\d+);", Regex.NONE, ret, function(re)
    return unicodechar_to_utf8(tonumber(re:_1()))
  end)
  return ret
end

local candidates = {}
commands["encode"] = { 
  path = function(args) 
    local index = ibs.selected_index()
    if index > 0 then
      local value = candidates[index]
      ibs.set_clipboard(value.value)
    end
    candidates = {}
  end, 
  completion = function(values)
    candidates = {}
    local text = table.concat(values, " ")
    if text == nil or text == "" then
      return candidates
    end
    table.insert(candidates, {value=url.escape(text), description="URL encoded", always_match=true, icon=icon_data})
    table.insert(candidates, {value=mime.b64(text), description="Base64 encoded", always_match=true, icon=icon_data})
    table.insert(candidates, {value=html_entity_escape(text), description="HTML entity escaped", always_match=true, icon=icon_data})
    return candidates
  end,
  description = "encode given text into multiple formats",
  icon=icon_app,
  history=false
}

commands["decode"] = { 
  path = function(args) 
    local index = ibs.selected_index()
    if index > 0 then
      local value = candidates[index]
      ibs.set_clipboard(value.value)
    end
    candidates = {}
  end, 
  completion = function(values)
    candidates = {}
    local text = table.concat(values, " ")
    if text == nil or text == "" then
      return candidates
    end
    table.insert(candidates, {value=url.unescape(text), description="as URL encoded", always_match=true, icon=icon_data})
    table.insert(candidates, {value=mime.unb64(text), description="as Base64 encoded", always_match=true, icon=icon_data})
    table.insert(candidates, {value=html_entity_unescape(text), description="as HTML entity escaped", always_match=true, icon=icon_data})
    return candidates
  end,
  description = "decode given text to original text",
  icon=icon_app,
  history=false
}
