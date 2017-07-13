-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Licensed to the public under the Apache License 2.0.

local wa = require "luci.tools.webadmin"
local nw = require "luci.model.network"
local ut = require "luci.util"
local nt = require "luci.sys".net
local fs = require "nixio.fs"

arg[1] = arg[1] or ""

m = Map("wireless", "",
	translate("The <em>Device Configuration</em> section covers physical settings of the radio " ..
		"hardware such as channel, transmit power or antenna selection which are shared among all " ..
		"defined wireless networks (if the radio hardware is multi-SSID capable). Per network settings " ..
		"like encryption or operation mode are grouped in the <em>Interface Configuration</em>."))

m:chain("network")
m:chain("firewall")
m.redirect = luci.dispatcher.build_url("sdc/network/wireless")

local ifsection

function m.on_commit(map)
	local wnet = nw:get_wifinet(arg[1])
	if ifsection and wnet then
		ifsection.section = wnet.sid
		m.title = luci.util.pcdata(wnet:get_i18n())
	end
end

nw.init(m.uci)

local wnet = nw:get_wifinet(arg[1])
local wdev = wnet and wnet:get_device()

-- redirect to overview page if network does not exist anymore (e.g. after a revert)
if not wnet or not wdev then
	luci.http.redirect(luci.dispatcher.build_url("sdc/network/wireless"))
	return
end

-- wireless toggle was requested, commit and reload page
function m.parse(map)
	if m:formvalue("cbid.wireless.%s.__toggle" % wdev:name()) then
		if wdev:get("disabled") == "1" or wnet:get("disabled") == "1" then
			wnet:set("disabled", nil)
		else
			wnet:set("disabled", "1")
		end
		wdev:set("disabled", nil)

		nw:commit("wireless")
		luci.sys.call("(env -i /bin/ubus call network reload) >/dev/null 2>/dev/null")

		luci.http.redirect(luci.dispatcher.build_url("sdc/network/wireless", arg[1]))
		return
	end
	Map.parse(map)
end

m.title = luci.util.pcdata(wnet:get_i18n())


local function txpower_list(iw)
	local list = iw.txpwrlist or { }
	local off  = tonumber(iw.txpower_offset) or 0
	local new  = { }
	local prev = -1
	local _, val
	for _, val in ipairs(list) do
		local dbm = val.dbm + off
		local mw  = math.floor(10 ^ (dbm / 10))
		if mw ~= prev then
			prev = mw
			new[#new+1] = {
				display_dbm = dbm,
				display_mw  = mw,
				driver_dbm  = val.dbm,
				driver_mw   = val.mw
			}
		end
	end
	return new
end

local function txpower_current(pwr, list)
	pwr = tonumber(pwr)
	if pwr ~= nil then
		local _, item
		for _, item in ipairs(list) do
			if item.driver_dbm >= pwr then
				return item.driver_dbm
			end
		end
	end
	return (list[#list] and list[#list].driver_dbm) or pwr or 0
end

local iw = luci.sys.wifi.getiwinfo(arg[1])
local hw_modes      = iw.hwmodelist or { }
local tx_power_list = txpower_list(iw)
local tx_power_cur  = txpower_current(wdev:get("txpower"), tx_power_list)

--[[
back = s:option(DummyValue, "_overview", translate("Overview"))
back.value = ""
back.titleref = luci.dispatcher.build_url("sdc", "network", "wireless")
]]

local hwtype = wdev:get("type")

-- NanoFoo
local nsantenna = wdev:get("antenna")

-- Check whether there are client interfaces on the same radio,
-- if yes, lock the channel choice as these stations will dicatate the freq
local found_sta = nil
local _, net
if wnet:mode() ~= "sta" then
	for _, net in ipairs(wdev:get_wifinets()) do
		if net:mode() == "sta" and net:get("disabled") ~= "1" then
			if not found_sta then
				found_sta = {}
				found_sta.channel = net:channel()
				found_sta.names = {}
			end
			found_sta.names[#found_sta.names+1] = net:shortname()
		end
	end
end

------------------- MAC80211 Device ------------------

if hwtype == "mac80211" then
	if #tx_power_list > 1 then
		tp = s:taboption("general", ListValue,
			"txpower", translate("Transmit Power"), "dBm")
		tp.rmempty = true
		tp.default = tx_power_cur
		function tp.cfgvalue(...)
			return txpower_current(Value.cfgvalue(...), tx_power_list)
		end

		for _, p in ipairs(tx_power_list) do
			tp:value(p.driver_dbm, "%i dBm (%i mW)"
				%{ p.display_dbm, p.display_mw })
		end
	end

	local cl = iw and iw.countrylist
	if cl and #cl > 0 then
		cc = s:taboption("advanced", ListValue, "country", translate("Country Code"), translate("Use ISO/IEC 3166 alpha2 country codes."))
		cc.default = tostring(iw and iw.country or "00")
		for _, c in ipairs(cl) do
			cc:value(c.alpha2, "%s - %s" %{ c.alpha2, c.name })
		end
	else
		s:taboption("advanced", Value, "country", translate("Country Code"), translate("Use ISO/IEC 3166 alpha2 country codes."))
	end

	s:taboption("advanced", Value, "distance", translate("Distance Optimization"),
		translate("Distance to farthest network member in meters."))

	-- external antenna profiles
	local eal = iw and iw.extant
	if eal and #eal > 0 then
		ea = s:taboption("advanced", ListValue, "extant", translate("Antenna Configuration"))
		for _, eap in ipairs(eal) do
			ea:value(eap.id, "%s (%s)" %{ eap.name, eap.description })
			if eap.selected then
				ea.default = eap.id
			end
		end
	end

	s:taboption("advanced", Value, "frag", translate("Fragmentation Threshold"))
	s:taboption("advanced", Value, "rts", translate("RTS/CTS Threshold"))
end


------------------- Madwifi Device ------------------

if hwtype == "atheros" then
	tp = s:taboption("general",
		(#tx_power_list > 0) and ListValue or Value,
		"txpower", translate("Transmit Power"), "dBm")

	tp.rmempty = true
	tp.default = tx_power_cur

	function tp.cfgvalue(...)
		return txpower_current(Value.cfgvalue(...), tx_power_list)
	end

	for _, p in ipairs(tx_power_list) do
		tp:value(p.driver_dbm, "%i dBm (%i mW)"
			%{ p.display_dbm, p.display_mw })
	end

	s:taboption("advanced", Flag, "diversity", translate("Diversity")).rmempty = false

	if not nsantenna then
		ant1 = s:taboption("advanced", ListValue, "txantenna", translate("Transmitter Antenna"))
		ant1.widget = "radio"
		ant1.orientation = "horizontal"
		ant1:depends("diversity", "")
		ant1:value("0", translate("auto"))
		ant1:value("1", translate("Antenna 1"))
		ant1:value("2", translate("Antenna 2"))

		ant2 = s:taboption("advanced", ListValue, "rxantenna", translate("Receiver Antenna"))
		ant2.widget = "radio"
		ant2.orientation = "horizontal"
		ant2:depends("diversity", "")
		ant2:value("0", translate("auto"))
		ant2:value("1", translate("Antenna 1"))
		ant2:value("2", translate("Antenna 2"))

	else -- NanoFoo
		local ant = s:taboption("advanced", ListValue, "antenna", translate("Transmitter Antenna"))
		ant:value("auto")
		ant:value("vertical")
		ant:value("horizontal")
		ant:value("external")
	end

	s:taboption("advanced", Value, "distance", translate("Distance Optimization"),
		translate("Distance to farthest network member in meters."))
	s:taboption("advanced", Value, "regdomain", translate("Regulatory Domain"))
	s:taboption("advanced", Value, "country", translate("Country Code"))
	s:taboption("advanced", Flag, "outdoor", translate("Outdoor Channels"))

	--s:option(Flag, "nosbeacon", translate("Disable HW-Beacon timer"))
end



------------------- Broadcom Device ------------------

if hwtype == "broadcom" then
	tp = s:taboption("general",
		(#tx_power_list > 0) and ListValue or Value,
		"txpower", translate("Transmit Power"), "dBm")

	tp.rmempty = true
	tp.default = tx_power_cur

	function tp.cfgvalue(...)
		return txpower_current(Value.cfgvalue(...), tx_power_list)
	end

	for _, p in ipairs(tx_power_list) do
		tp:value(p.driver_dbm, "%i dBm (%i mW)"
			%{ p.display_dbm, p.display_mw })
	end

	ant1 = s:taboption("advanced", ListValue, "txantenna", translate("Transmitter Antenna"))
	ant1.widget = "radio"
	ant1:depends("diversity", "")
	ant1:value("3", translate("auto"))
	ant1:value("0", translate("Antenna 1"))
	ant1:value("1", translate("Antenna 2"))

	ant2 = s:taboption("advanced", ListValue, "rxantenna", translate("Receiver Antenna"))
	ant2.widget = "radio"
	ant2:depends("diversity", "")
	ant2:value("3", translate("auto"))
	ant2:value("0", translate("Antenna 1"))
	ant2:value("1", translate("Antenna 2"))

	s:taboption("advanced", Flag, "frameburst", translate("Frame Bursting"))

	s:taboption("advanced", Value, "distance", translate("Distance Optimization"))
	--s:option(Value, "slottime", translate("Slot time"))

	s:taboption("advanced", Value, "country", translate("Country Code"))
	s:taboption("advanced", Value, "maxassoc", translate("Connection Limit"))
end


--------------------- HostAP Device ---------------------

if hwtype == "prism2" then
	s:taboption("advanced", Value, "txpower", translate("Transmit Power"), "att units").rmempty = true

	s:taboption("advanced", Flag, "diversity", translate("Diversity")).rmempty = false

	s:taboption("advanced", Value, "txantenna", translate("Transmitter Antenna"))
	s:taboption("advanced", Value, "rxantenna", translate("Receiver Antenna"))
end


----------------------- Interface -----------------------

s = m:section(NamedSection, wnet.sid, "wifi-iface", translate("Interface Configuration"))
ifsection = s
s.addremove = false
s.anonymous = true
s.defaults.device = wdev:name()

s:tab("general", translate("General Setup"))
s:tab("encryption", translate("Wireless Security"))
s:tab("macfilter", translate("MAC-Filter"))
s:tab("advanced", translate("Advanced Settings"))

mode = s:taboption("general", ListValue, "ssid", translate("<abbr title=\"Extended Service Set Identifier\">ESSID</abbr>"))
mode.override_values = true
--local _, net
--for _, net in ipairs(wdev:get_wifinets()) do
--	if net:mode() ~= "ap" then
---		mode:value(net:ssid(), translate(net:ssid()))
--	end
--end

function percent_wifi_signal(info)
	local qc = info.quality or 0
	local qm = info.quality_max or 0

	if info.bssid and qc > 0 and qm > 0 then
		return math.floor((100 / qm) * qc)
	else
		return 0
	end
end

function format_wifi_encryption(info)
	if info.wep == true then
		return "WEP"
	elseif info.wpa > 0 then
		return translatef("<abbr title='Pairwise: %s / Group: %s'>%s - %s</abbr>",
			table.concat(info.pair_ciphers, ", "),
			table.concat(info.group_ciphers, ", "),
			(info.wpa == 3) and translate("mixed WPA/WPA2")
				or (info.wpa == 2 and "WPA2" or "WPA"),
			table.concat(info.auth_suites, ", ")
		)
	elseif info.enabled then
		return "<em>%s</em>" % translate("unknown")
	else
		return "<em>%s</em>" % translate("open")
	end
end

function scanlist(times)
	local i, k, v
	local l = { }
	local s = { }

	for i = 1, times do
		for k, v in ipairs(iw.scanlist or { }) do
			if not s[v.bssid] then
				l[#l+1] = v
				s[v.bssid] = true
			end
		end
	end

	return l
end

local k, v

for k, v in ipairs(scanlist(3)) do
	mode:value(v.ssid, translate(v.ssid .. "   [ " .. percent_wifi_signal(v) .. "% ]"))
end

mode = s:taboption("general", ListValue, "mode", translate("Mode"))
mode.override_values = true
--mode:value("ap", translate("Access Point"))
mode:value("sta", translate("Client"))
--mode:value("adhoc", translate("Ad-Hoc"))

------------------- WiFI-Encryption -------------------

encr = s:taboption("encryption", ListValue, "encryption", translate("Encryption"))
encr.override_values = true
encr.override_depends = true
encr:depends({mode="ap"})
encr:depends({mode="sta"})
encr:depends({mode="adhoc"})
encr:depends({mode="ahdemo"})
encr:depends({mode="ap-wds"})
encr:depends({mode="sta-wds"})
encr:depends({mode="mesh"})

cipher = s:taboption("encryption", ListValue, "cipher", translate("Cipher"))
cipher:depends({encryption="wpa"})
cipher:depends({encryption="wpa2"})
cipher:depends({encryption="psk"})
cipher:depends({encryption="psk2"})
cipher:depends({encryption="wpa-mixed"})
cipher:depends({encryption="psk-mixed"})
cipher:value("auto", translate("auto"))
cipher:value("ccmp", translate("Force CCMP (AES)"))
cipher:value("tkip", translate("Force TKIP"))
cipher:value("tkip+ccmp", translate("Force TKIP and CCMP (AES)"))

function encr.cfgvalue(self, section)
	local v = tostring(ListValue.cfgvalue(self, section))
	if v == "wep" then
		return "wep-open"
	elseif v and v:match("%+") then
		return (v:gsub("%+.+$", ""))
	end
	return v
end

function encr.write(self, section, value)
	local e = tostring(encr:formvalue(section))
	local c = tostring(cipher:formvalue(section))
	if value == "wpa" or value == "wpa2"  then
		self.map.uci:delete("wireless", section, "key")
	end
	if e and (c == "tkip" or c == "ccmp" or c == "tkip+ccmp") then
		e = e .. "+" .. c
	end
	self.map:set(section, "encryption", e)
end

function cipher.cfgvalue(self, section)
	local v = tostring(ListValue.cfgvalue(encr, section))
	if v and v:match("%+") then
		v = v:gsub("^[^%+]+%+", "")
		if v == "aes" then v = "ccmp"
		elseif v == "tkip+aes" then v = "tkip+ccmp"
		elseif v == "aes+tkip" then v = "tkip+ccmp"
		elseif v == "ccmp+tkip" then v = "tkip+ccmp"
		end
	end
	return v
end

function cipher.write(self, section)
	return encr:write(section)
end


encr:value("none", "No Encryption")
encr:value("wep-open",   translate("WEP Open System"), {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"}, {mode="ahdemo"}, {mode="wds"})
encr:value("wep-shared", translate("WEP Shared Key"),  {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"}, {mode="adhoc"}, {mode="ahdemo"}, {mode="wds"})

if hwtype == "atheros" or hwtype == "mac80211" or hwtype == "prism2" then
	local supplicant = fs.access("/usr/sbin/wpa_supplicant")
	local hostapd = fs.access("/usr/sbin/hostapd")

	-- Probe EAP support
	local has_ap_eap  = (os.execute("hostapd -veap >/dev/null 2>/dev/null") == 0)
	local has_sta_eap = (os.execute("wpa_supplicant -veap >/dev/null 2>/dev/null") == 0)

	if hostapd and supplicant then
		encr:value("psk", "WPA-PSK", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
		encr:value("psk2", "WPA2-PSK", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
		encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
		if has_ap_eap and has_sta_eap then
			encr:value("wpa", "WPA-EAP", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
			encr:value("wpa2", "WPA2-EAP", {mode="ap"}, {mode="sta"}, {mode="ap-wds"}, {mode="sta-wds"})
		end
	elseif hostapd and not supplicant then
		encr:value("psk", "WPA-PSK", {mode="ap"}, {mode="ap-wds"})
		encr:value("psk2", "WPA2-PSK", {mode="ap"}, {mode="ap-wds"})
		encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode", {mode="ap"}, {mode="ap-wds"})
		if has_ap_eap then
			encr:value("wpa", "WPA-EAP", {mode="ap"}, {mode="ap-wds"})
			encr:value("wpa2", "WPA2-EAP", {mode="ap"}, {mode="ap-wds"})
		end
		encr.description = translate(
			"WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..
			"and ad-hoc mode) to be installed."
		)
	elseif not hostapd and supplicant then
		encr:value("psk", "WPA-PSK", {mode="sta"}, {mode="sta-wds"})
		encr:value("psk2", "WPA2-PSK", {mode="sta"}, {mode="sta-wds"})
		encr:value("psk-mixed", "WPA-PSK/WPA2-PSK Mixed Mode", {mode="sta"}, {mode="sta-wds"})
		if has_sta_eap then
			encr:value("wpa", "WPA-EAP", {mode="sta"}, {mode="sta-wds"})
			encr:value("wpa2", "WPA2-EAP", {mode="sta"}, {mode="sta-wds"})
		end
		encr.description = translate(
			"WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..
			"and ad-hoc mode) to be installed."
		)
	else
		encr.description = translate(
			"WPA-Encryption requires wpa_supplicant (for client mode) or hostapd (for AP " ..
			"and ad-hoc mode) to be installed."
		)
	end
elseif hwtype == "broadcom" then
	encr:value("psk", "WPA-PSK")
	encr:value("psk2", "WPA2-PSK")
	encr:value("psk+psk2", "WPA-PSK/WPA2-PSK Mixed Mode")
elseif hwtype == "ralink" or hwtype == "rt2860v2" or hwtype == "mt_wifi" then
	encr:value("psk", "WPA-PSK")
	encr:value("psk2", "WPA2-PSK")
	encr:value("psk+psk2", "WPA-PSK/WPA2-PSK Mixed Mode")
end

auth_server = s:taboption("encryption", Value, "auth_server", translate("Radius-Authentication-Server"))
auth_server:depends({mode="ap", encryption="wpa"})
auth_server:depends({mode="ap", encryption="wpa2"})
auth_server:depends({mode="ap-wds", encryption="wpa"})
auth_server:depends({mode="ap-wds", encryption="wpa2"})
auth_server.rmempty = true
auth_server.datatype = "host"

auth_port = s:taboption("encryption", Value, "auth_port", translate("Radius-Authentication-Port"), translatef("Default %d", 1812))
auth_port:depends({mode="ap", encryption="wpa"})
auth_port:depends({mode="ap", encryption="wpa2"})
auth_port:depends({mode="ap-wds", encryption="wpa"})
auth_port:depends({mode="ap-wds", encryption="wpa2"})
auth_port.rmempty = true
auth_port.datatype = "port"

auth_secret = s:taboption("encryption", Value, "auth_secret", translate("Radius-Authentication-Secret"))
auth_secret:depends({mode="ap", encryption="wpa"})
auth_secret:depends({mode="ap", encryption="wpa2"})
auth_secret:depends({mode="ap-wds", encryption="wpa"})
auth_secret:depends({mode="ap-wds", encryption="wpa2"})
auth_secret.rmempty = true
auth_secret.password = true

acct_server = s:taboption("encryption", Value, "acct_server", translate("Radius-Accounting-Server"))
acct_server:depends({mode="ap", encryption="wpa"})
acct_server:depends({mode="ap", encryption="wpa2"})
acct_server:depends({mode="ap-wds", encryption="wpa"})
acct_server:depends({mode="ap-wds", encryption="wpa2"})
acct_server.rmempty = true
acct_server.datatype = "host"

acct_port = s:taboption("encryption", Value, "acct_port", translate("Radius-Accounting-Port"), translatef("Default %d", 1813))
acct_port:depends({mode="ap", encryption="wpa"})
acct_port:depends({mode="ap", encryption="wpa2"})
acct_port:depends({mode="ap-wds", encryption="wpa"})
acct_port:depends({mode="ap-wds", encryption="wpa2"})
acct_port.rmempty = true
acct_port.datatype = "port"

acct_secret = s:taboption("encryption", Value, "acct_secret", translate("Radius-Accounting-Secret"))
acct_secret:depends({mode="ap", encryption="wpa"})
acct_secret:depends({mode="ap", encryption="wpa2"})
acct_secret:depends({mode="ap-wds", encryption="wpa"})
acct_secret:depends({mode="ap-wds", encryption="wpa2"})
acct_secret.rmempty = true
acct_secret.password = true

wpakey = s:taboption("encryption", Value, "_wpa_key", translate("Key"))
wpakey:depends("encryption", "psk")
wpakey:depends("encryption", "psk2")
wpakey:depends("encryption", "psk+psk2")
wpakey:depends("encryption", "psk-mixed")
wpakey.datatype = "wpakey"
wpakey.rmempty = true
wpakey.password = true

wpakey.cfgvalue = function(self, section, value)
	local key = m.uci:get("wireless", section, "key")
	if key == "1" or key == "2" or key == "3" or key == "4" then
		return nil
	end
	return key
end

wpakey.write = function(self, section, value)
	self.map.uci:set("wireless", section, "key", value)
	self.map.uci:delete("wireless", section, "key1")
end


wepslot = s:taboption("encryption", ListValue, "_wep_key", translate("Used Key Slot"))
wepslot:depends("encryption", "wep-open")
wepslot:depends("encryption", "wep-shared")
wepslot:value("1", translatef("Key #%d", 1))
wepslot:value("2", translatef("Key #%d", 2))
wepslot:value("3", translatef("Key #%d", 3))
wepslot:value("4", translatef("Key #%d", 4))

wepslot.cfgvalue = function(self, section)
	local slot = tonumber(m.uci:get("wireless", section, "key"))
	if not slot or slot < 1 or slot > 4 then
		return 1
	end
	return slot
end

wepslot.write = function(self, section, value)
	self.map.uci:set("wireless", section, "key", value)
end

local slot
for slot=1,4 do
	wepkey = s:taboption("encryption", Value, "key" .. slot, translatef("Key #%d", slot))
	wepkey:depends("encryption", "wep-open")
	wepkey:depends("encryption", "wep-shared")
	wepkey.datatype = "wepkey"
	wepkey.rmempty = true
	wepkey.password = true

	function wepkey.write(self, section, value)
		if value and (#value == 5 or #value == 13) then
			value = "s:" .. value
		end
		return Value.write(self, section, value)
	end
end


if hwtype == "atheros" or hwtype == "mac80211" or hwtype == "prism2" then
	nasid = s:taboption("encryption", Value, "nasid", translate("NAS ID"))
	nasid:depends({mode="ap", encryption="wpa"})
	nasid:depends({mode="ap", encryption="wpa2"})
	nasid:depends({mode="ap-wds", encryption="wpa"})
	nasid:depends({mode="ap-wds", encryption="wpa2"})
	nasid.rmempty = true

	eaptype = s:taboption("encryption", ListValue, "eap_type", translate("EAP-Method"))
	eaptype:value("tls",  "TLS")
	eaptype:value("ttls", "TTLS")
	eaptype:value("peap", "PEAP")
	eaptype:depends({mode="sta", encryption="wpa"})
	eaptype:depends({mode="sta", encryption="wpa2"})
	eaptype:depends({mode="sta-wds", encryption="wpa"})
	eaptype:depends({mode="sta-wds", encryption="wpa2"})

	cacert = s:taboption("encryption", FileUpload, "ca_cert", translate("Path to CA-Certificate"))
	cacert:depends({mode="sta", encryption="wpa"})
	cacert:depends({mode="sta", encryption="wpa2"})
	cacert:depends({mode="sta-wds", encryption="wpa"})
	cacert:depends({mode="sta-wds", encryption="wpa2"})

	clientcert = s:taboption("encryption", FileUpload, "client_cert", translate("Path to Client-Certificate"))
	clientcert:depends({mode="sta", encryption="wpa"})
	clientcert:depends({mode="sta", encryption="wpa2"})
	clientcert:depends({mode="sta-wds", encryption="wpa"})
	clientcert:depends({mode="sta-wds", encryption="wpa2"})

	privkey = s:taboption("encryption", FileUpload, "priv_key", translate("Path to Private Key"))
	privkey:depends({mode="sta", eap_type="tls", encryption="wpa2"})
	privkey:depends({mode="sta", eap_type="tls", encryption="wpa"})
	privkey:depends({mode="sta-wds", eap_type="tls", encryption="wpa2"})
	privkey:depends({mode="sta-wds", eap_type="tls", encryption="wpa"})

	privkeypwd = s:taboption("encryption", Value, "priv_key_pwd", translate("Password of Private Key"))
	privkeypwd:depends({mode="sta", eap_type="tls", encryption="wpa2"})
	privkeypwd:depends({mode="sta", eap_type="tls", encryption="wpa"})
	privkeypwd:depends({mode="sta-wds", eap_type="tls", encryption="wpa2"})
	privkeypwd:depends({mode="sta-wds", eap_type="tls", encryption="wpa"})


	auth = s:taboption("encryption", Value, "auth", translate("Authentication"))
	auth:value("PAP")
	auth:value("CHAP")
	auth:value("MSCHAP")
	auth:value("MSCHAPV2")
	auth:depends({mode="sta", eap_type="peap", encryption="wpa2"})
	auth:depends({mode="sta", eap_type="peap", encryption="wpa"})
	auth:depends({mode="sta", eap_type="ttls", encryption="wpa2"})
	auth:depends({mode="sta", eap_type="ttls", encryption="wpa"})
	auth:depends({mode="sta-wds", eap_type="peap", encryption="wpa2"})
	auth:depends({mode="sta-wds", eap_type="peap", encryption="wpa"})
	auth:depends({mode="sta-wds", eap_type="ttls", encryption="wpa2"})
	auth:depends({mode="sta-wds", eap_type="ttls", encryption="wpa"})


	identity = s:taboption("encryption", Value, "identity", translate("Identity"))
	identity:depends({mode="sta", eap_type="peap", encryption="wpa2"})
	identity:depends({mode="sta", eap_type="peap", encryption="wpa"})
	identity:depends({mode="sta", eap_type="ttls", encryption="wpa2"})
	identity:depends({mode="sta", eap_type="ttls", encryption="wpa"})
	identity:depends({mode="sta-wds", eap_type="peap", encryption="wpa2"})
	identity:depends({mode="sta-wds", eap_type="peap", encryption="wpa"})
	identity:depends({mode="sta-wds", eap_type="ttls", encryption="wpa2"})
	identity:depends({mode="sta-wds", eap_type="ttls", encryption="wpa"})

	password = s:taboption("encryption", Value, "password", translate("Password"))
	password:depends({mode="sta", eap_type="peap", encryption="wpa2"})
	password:depends({mode="sta", eap_type="peap", encryption="wpa"})
	password:depends({mode="sta", eap_type="ttls", encryption="wpa2"})
	password:depends({mode="sta", eap_type="ttls", encryption="wpa"})
	password:depends({mode="sta-wds", eap_type="peap", encryption="wpa2"})
	password:depends({mode="sta-wds", eap_type="peap", encryption="wpa"})
	password:depends({mode="sta-wds", eap_type="ttls", encryption="wpa2"})
	password:depends({mode="sta-wds", eap_type="ttls", encryption="wpa"})
end

if hwtype == "atheros" or hwtype == "mac80211" or hwtype == "prism2" then
	local wpasupplicant = fs.access("/usr/sbin/wpa_supplicant")
	local hostcli = fs.access("/usr/sbin/hostapd_cli")
	if hostcli and wpasupplicant then
		wps = s:taboption("encryption", Flag, "wps_pushbutton", translate("Enable WPS pushbutton, requires WPA(2)-PSK"))
		wps.enabled = "1"
		wps.disabled = "0"
		wps.rmempty = false
		wps:depends("encryption", "psk")
		wps:depends("encryption", "psk2")
		wps:depends("encryption", "psk-mixed")
	end
end

return m
