var id_id = {};
var used_id = {};
var map;

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
		var rew = id_id[fqfn];
		return rew;
	},
	dump : function () {
		console.log("id_id");
		console.log(id_id);
		console.log("used_id");
		console.log(used_id);
		console.log("map");
		console.log(map);
	}
}
