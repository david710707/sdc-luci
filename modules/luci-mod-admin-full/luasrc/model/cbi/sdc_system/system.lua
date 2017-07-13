-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local sys   = require "luci.sys"
local zones = require "luci.sys.zoneinfo"
local fs    = require "nixio.fs"
local conf  = require "luci.config"

local m, s, o
local has_ntpd = fs.access("/usr/sbin/ntpd")

m = Map("system", translate("System"), translate("Here you can configure the basic aspects of your device like its hostname or the timezone."))
m:chain("luci")

s = m:section(TypedSection, "system", translate("System Properties"))
s.anonymous = true
s.addremove = false

s:tab("general",  translate("General Settings"))


--
-- System Properties
--

o = s:taboption("general", Value, "hostname", translate("Hostname"))
o.datatype = "hostname"

function o.write(self, section, value)
	Value.write(self, section, value)
	sys.hostname(value)
end


o = s:taboption("general", ListValue, "zonename", translate("Timezone"))
o:value("UTC")

for i, zone in ipairs(zones.TZ) do
	o:value(zone[1])
end

function o.write(self, section, value)
	local function lookup_zone(title)
		for _, zone in ipairs(zones.TZ) do
			if zone[1] == title then return zone[2] end
		end
	end

	AbstractValue.write(self, section, value)
	local timezone = lookup_zone(value) or "GMT0"
	self.map.uci:set("system", section, "timezone", timezone)
	fs.writefile("/etc/TZ", timezone .. "\n")
end

return m