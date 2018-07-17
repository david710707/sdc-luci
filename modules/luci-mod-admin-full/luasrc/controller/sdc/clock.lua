-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2008-2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.sdc.clock", package.seeall)

function index()
	local fs = require "nixio.fs"

	entry({"sdc", "clock"}, alias("sdc", "clock", "clockStatus"), _("Clock"), 80).index = true
	entry({"sdc", "clock", "clockStatus"}, template("sdc_clock/index"), _("Status"), 1)
	entry({"sdc", "clock", "clockNtp"}, cbi("sdc_clock/clockNtp"), _("NTP"), 2)

	--entry({"admin", "clock"}, alias("admin", "clock", "clockStatus"), _("Clock"), 80).index = true
	--entry({"admin", "clock", "clockStatus"}, template("admin_clock/index"), _("Status"), 1)
	--entry({"admin", "clock", "clockSetting"}, cbi("admin_clock/clockSetting"), _("Setting"), 2)
	--entry({"admin", "clock", "clockNtp"}, cbi("admin_clock/clockNtp"), _("NTP"), 3)
	--entry({"admin", "clock", "clockSnmp"}, cbi("admin_clock/clockSnmp"), _("SNMP"), 4)
end