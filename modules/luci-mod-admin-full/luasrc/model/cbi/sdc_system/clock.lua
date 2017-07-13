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

---------------------------------------------------------------------------------

--
-- NTP Client
--

s = m:section(TypedSection, "system", translate("NTP Server Setting"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "ntpserver1", translate("Ntp Server 1"))
o.datatype = "string"
function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server1") ~= nil then
			return string.gsub(token, "NtpClient2Server1 ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server1") ~= nil then
			v = string.format("%sNtpClient2Server1 %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/SDC/Clock.conf", v)
end

o = s:option(Value, "ntpserver2", translate("Ntp Server 2"))
o.datatype = "string"
function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server2") ~= nil then
			return string.gsub(token, "NtpClient2Server2 ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server2") ~= nil then
			v = string.format("%sNtpClient2Server2 %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/SDC/Clock.conf", v)
end

o = s:option(Value, "ntpserver3", translate("Ntp Server 3"))
o.datatype = "string"
function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server3") ~= nil then
			return string.gsub(token, "NtpClient2Server3 ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server3") ~= nil then
			v = string.format("%sNtpClient2Server3 %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/SDC/Clock.conf", v)
end

o = s:option(Value, "ntpserver4", translate("Ntp Server 4"))
o.datatype = "string"
function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server4") ~= nil then
			return string.gsub(token, "NtpClient2Server4 ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server4") ~= nil then
			v = string.format("%sNtpClient2Server4 %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/SDC/Clock.conf", v)
end

o = s:option(Value, "ntpserver5", translate("Ntp Server 5"))
o.datatype = "string"
function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server5") ~= nil then
			return string.gsub(token, "NtpClient2Server5 ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClient2Server5") ~= nil then
			v = string.format("%sNtpClient2Server5 %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/SDC/Clock.conf", v)
end

o = s:option(Value, "ntpclientinterval", translate("Interval"))
o.datatype = "string"
function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClientInterval") ~= nil then
			return string.gsub(token, "NtpClientInterval ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClientInterval") ~= nil then
			v = string.format("%sNtpClientInterval %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/SDC/Clock.conf", v)
end

o = s:option(Value, "ntpclienttimeout", translate("Timeout"))
o.datatype = "string"
function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClientTimeout") ~= nil then
			return string.gsub(token, "NtpClientTimeout ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/SDC/Clock.conf"), "[^\r\n]+") do
		if string.find(token, "NtpClientTimeout") ~= nil then
			v = string.format("%sNtpClientTimeout %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/SDC/Clock.conf", v)
end

---------------------------------------------------------------------------------

return m
