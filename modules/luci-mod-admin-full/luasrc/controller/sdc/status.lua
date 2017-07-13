-- Copyright 2008 Steven Barth <steven@midlink.org>
-- Copyright 2011 Jo-Philipp Wich <jow@openwrt.org>
-- Licensed to the public under the Apache License 2.0.

module("luci.controller.sdc.status", package.seeall)

function index()
	entry({"sdc", "status"}, alias("sdc", "status", "overview"), _("Status"), 20).index = true
	entry({"sdc", "status", "overview"}, template("sdc_status/index"), _("Overview"), 1)
	entry({"sdc", "status", "nameinfo"}, call("action_nameinfo")).leaf = true
end

function action_nameinfo(...)
	local i
	local rv = { }
	for i = 1, select('#', ...) do
		local addr = select(i, ...)
		local fqdn = nixio.getnameinfo(addr)
		rv[addr] = fqdn or (addr:match(":") and "[%s]" % addr or addr)
	end

	luci.http.prepare_content("application/json")
	luci.http.write_json(rv)
end
