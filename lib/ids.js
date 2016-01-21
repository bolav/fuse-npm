var id_id = {};
var used_id = {};
var map;
var shims = {};
var missing = {};
var created_missing = 0;
module.exports = {
	add_id: function (orig, f) {
		id_id[orig] = f;
		used_id[f] = 1;
	},
	get_used : function (f) {
		return used_id[f];
	},
	set_map: function (new_map) {
		map = new_map;
	},
	get_require: function (req) {
		var fqfn = map[req];
		if (!fqfn) {
			if (missing[req]) {
				missing[req]++;
			}
			else {
				missing[req] = 1;
			}
		}
		var rew = id_id[fqfn];
		return rew;
	},
	create_missing : function () {
		if(!created_missing) {
			created_missing = 1;
			
		}
	},
	dump : function () {
		console.log("shims");
		console.log(shims);
		console.log("missing");
		console.log(missing);
	},
	shim_used : function shim_used (shim) {
		if (shims[shim]) {
			shims[shim]++;
		}
		else {
			shims[shim] = 1;
		}
	}
}
