-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

local sys   = require "luci.sys"
local zones = require "luci.sys.zoneinfo"
local fs    = require "nixio.fs"
local conf  = require "luci.config"

local m, s, o
local has_ntpd = fs.access("/sysconf/net-snmp/snmp/")

m = Map("system", translate("SNMP"), translate("Here you can configure the SNMP server."))
m:chain("luci")

---------------------------------------------------------------------------------

--
-- NTP Client
--

s = m:section(TypedSection, "system", translate("SNMP Setting"))
s.anonymous = true
s.addremove = false

o = s:option(Value, "syslocation", translate("Location"))
o.datatype = "string"
o.rmempty = false
o.optional = false
--o.default = "" 

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "syslocation") ~= nil and string.find(token, "#") == nil then
			return string.gsub(token, "syslocation ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "syslocation") ~= nil and string.find(token, "#") == nil then
			v = string.format("%ssyslocation %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "syscontact", translate("Contact"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "syscontact") ~= nil and string.find(token, "#") == nil then
			return string.gsub(token, "syscontact ", "")
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "syscontact") ~= nil and string.find(token, "#") == nil then
			v = string.format("%ssyscontact %s\n", v, value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer1", translate("SNMP Server 1"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec1") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec1 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec1 ", ""), 0, i-1)
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec1") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec1 ", ""), " ")
			
			v = string.format("%scom2sec sec1 %s %s\n", v, value, string.sub(string.gsub(token, "com2sec sec1 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec1 ", ""))))
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer1Community", translate("SNMP Server 1 Community"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec1") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec1 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec1 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec1 ", "")))
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec1") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec1 ", ""), " ")
			v = string.format("%scom2sec sec1 %s %s\n", v, string.sub(string.gsub(token, "com2sec sec1 ", ""), 0, i-1), value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer2", translate("SNMP Server 2"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec2") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec2 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec2 ", ""), 0, i-1)
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec2") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec2 ", ""), " ")
			
			v = string.format("%scom2sec sec2 %s %s\n", v, value, string.sub(string.gsub(token, "com2sec sec2 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec2 ", ""))))
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer2Community", translate("SNMP Server 2 Community"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec2") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec2 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec2 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec2 ", "")))
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec2") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec2 ", ""), " ")
			v = string.format("%scom2sec sec2 %s %s\n", v, string.sub(string.gsub(token, "com2sec sec2 ", ""), 0, i-1), value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer3", translate("SNMP Server 3"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec3") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec3 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec3 ", ""), 0, i-1)
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec3") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec3 ", ""), " ")
			
			v = string.format("%scom2sec sec3 %s %s\n", v, value, string.sub(string.gsub(token, "com2sec sec3 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec3 ", ""))))
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer3Community", translate("SNMP Server 3 Community"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec3") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec3 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec3 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec3 ", "")))
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec3") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec3 ", ""), " ")
			v = string.format("%scom2sec sec3 %s %s\n", v, string.sub(string.gsub(token, "com2sec sec3 ", ""), 0, i-1), value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer4", translate("SNMP Server 4"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec4") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec4 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec4 ", ""), 0, i-1)
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec4") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec4 ", ""), " ")
			
			v = string.format("%scom2sec sec4 %s %s\n", v, value, string.sub(string.gsub(token, "com2sec sec4 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec4 ", ""))))
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer4Community", translate("SNMP Server 4 Community"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec4") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec4 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec4 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec4 ", "")))
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec4") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec4 ", ""), " ")
			v = string.format("%scom2sec sec4 %s %s\n", v, string.sub(string.gsub(token, "com2sec sec4 ", ""), 0, i-1), value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer5", translate("SNMP Server 5"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec5") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec5 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec5 ", ""), 0, i-1)
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec5") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec5 ", ""), " ")
			
			v = string.format("%scom2sec sec5 %s %s\n", v, value, string.sub(string.gsub(token, "com2sec sec5 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec5 ", ""))))
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

o = s:option(Value, "snmpServer5Community", translate("SNMP Server 5 Community"))
o.datatype = "string"
o.rmempty = false
o.optional = false

function o.parse(self, section, novld)
	local fvalue = self:formvalue(section)
	local fexist = ( fvalue and (#fvalue > 0) )	-- not "nil" and "not empty"
	local cvalue = self:cfgvalue(section)
	local rm_opt = ( self.rmempty or self.optional )
	local eq_cfg					-- flag: equal cfgvalue

	-- If favlue and cvalue are both tables and have the same content
	-- make them identical
	if type(fvalue) == "table" and type(cvalue) == "table" then
		eq_cfg = (#fvalue == #cvalue)
		if eq_cfg then
			for i=1, #fvalue do
				if cvalue[i] ~= fvalue[i] then
					eq_cfg = false
				end
			end
		end
		if eq_cfg then
			fvalue = cvalue
		end
	end

	-- removed parameter "section" from function call because used/accepted nowhere
	-- also removed call to function "transfer"
	local vvalue, errtxt = self:validate(fvalue)

	-- error handling; validate return "nil"
	if not vvalue then
		if novld then 		-- and "novld" set
			return		-- then exit without raising an error
		end

		if fexist then		-- and there is a formvalue
			self:add_error(section, "invalid", errtxt or self.title .. ": invalid")
			return		-- so data are invalid
		elseif not rm_opt then	-- and empty formvalue but NOT (rmempty or optional) set
			self:add_error(section, "missing", errtxt or self.title .. ": missing")
			return		-- so data is missing
		elseif errtxt then
			self:add_error(section, "invalid", errtxt)
			return
		end
--		error  ("\n option: " .. self.option ..
--			"\n fvalue: " .. tostring(fvalue) ..
--			"\n fexist: " .. tostring(fexist) ..
--			"\n cvalue: " .. tostring(cvalue) ..
--			"\n vvalue: " .. tostring(vvalue) ..
--			"\n vexist: " .. tostring(vexist) ..
--			"\n rm_opt: " .. tostring(rm_opt) ..
--			"\n eq_cfg: " .. tostring(eq_cfg) ..
--			"\n eq_def: " .. tostring(eq_def) ..
--			"\n novld : " .. tostring(novld) ..
--			"\n errtxt: " .. tostring(errtxt) )
	end

	-- lets continue with value returned from validate
	eq_cfg  = ( vvalue == cvalue )					-- update equal_config flag
	local vexist = ( vvalue and (#vvalue > 0) ) and true or false	-- not "nil" and "not empty"
	local eq_def = ( vvalue == self.default )			-- equal_default flag

	-- (rmempty or optional) and (no data or equal_default)
	if rm_opt and (not vexist or eq_def) then
		if self:remove(section) then		-- remove data from UCI
			self.section.changed = true	-- and push events
		end
		return
	end

	-- not forcewrite and no changes, so nothing to write
	if not self.forcewrite and eq_cfg then
		return
	end

	-- we should have a valid value here
	assert (vvalue, "\n option: " .. self.option ..
			"\n fvalue: " .. tostring(fvalue) ..
			"\n fexist: " .. tostring(fexist) ..
			"\n cvalue: " .. tostring(cvalue) ..
			"\n vvalue: " .. tostring(vvalue) ..
			"\n vexist: " .. tostring(vexist) ..
			"\n rm_opt: " .. tostring(rm_opt) ..
			"\n eq_cfg: " .. tostring(eq_cfg) ..
			"\n eq_def: " .. tostring(eq_def) ..
			"\n errtxt: " .. tostring(errtxt) )

	-- write data to UCI; raise event only on changes
	if self:write(section, vvalue) and not eq_cfg then
		self.section.changed = true
	end
end

function o.cfgvalue(self, section)
    --return fs.readfile("/SDC/Clock.conf") or ""
	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec5") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec5 ", ""), " ")
			return string.sub(string.gsub(token, "com2sec sec5 ", ""), i + 1, string.len(string.gsub(token, "com2sec sec5 ", "")))
		end
	end
end

function o.write(self, section, value)
	local  v = ""

	for token in string.gmatch(fs.readfile("/sysconf/net-snmp/snmp/snmpd.conf"), "[^\r\n]+") do
		if string.find(token, "com2sec sec5") ~= nil then
			i, j = string.find(string.gsub(token, "com2sec sec5 ", ""), " ")
			v = string.format("%scom2sec sec5 %s %s\n", v, string.sub(string.gsub(token, "com2sec sec5 ", ""), 0, i-1), value)
		else
			v = string.format("%s%s\n", v, token)
		end
	end

	fs.writefile("/sysconf/net-snmp/snmp/snmpd.conf", v)
end

---------------------------------------------------------------------------------

return m