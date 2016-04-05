var mdeps = require('module-deps');

var builtins = require('browserify/lib/builtins');
var xtend = require('xtend');

var fs    = require('fs');
var path  = require('path');
var each = require("lodash/collection/each");
var babel = require('babel-core');
var ids = require('./ids');
var resolver = require('./fuse-resolve');
// var resolver = require('resolve');

console.log("Loading modules");

module.exports = function (modules) {
	function create_array(module_name) {
		mopts = { resolve: resolver };
		mopts.extensions = [ '.js', '.json' ];
		mopts.modules = xtend(builtins);
		var md = mdeps(mopts);

		md.on('data', function process_data (file) {
			var fn = create_fn(file.id);
			register(fn, file.id);
		});
		md.on('end', function () {
			array_done();
		});
		md.end({ file: module_name });		
	}
	function find_module(module_name) {
		mopts = { resolve: resolver };
		mopts.extensions = [ '.js', '.json' ];
		mopts.modules = xtend(builtins);
		var md = mdeps(mopts);
		var trans_opts = { highlightCode: true,
						   presets: 'es2015,react,stage-2',
                           plugins: 'transform-object-assign,transform-fuse',
                           // plugins: 'transform-bolav-debug',
                           comments: true,
                           babelrc: false,
                           ignore: null,
                           // filename: 'g.js',
                           only: null };

		md.on('data', function process_data (file) {
			var fn = create_fn(file.id);
			ids.set_map(file.deps);
			var src_fn = path.join(path.parse(__filename).dir, fn);
			if (/\.json$/.test(file.id)) {
				fs.writeFileSync(fn, "module.exports=" + file.source);
				return;
			}

			trans_opts.filename = src_fn;
			var trans = babel.transform(file.source, trans_opts);
			fs.writeFileSync(fn, trans.code);
		});
		md.on('end', function () {
			find_done();
		});
		md.end({ file: module_name });
	}
	function register (fn, orig) {
		ids.add_id(orig, fn);
	}
	function mkdirSync (path) {
	  try {
	    fs.mkdirSync(path);
	  } catch(e) {
	    if ( e.code != 'EEXIST' ) throw e;
	  }
	}
	function removeFiles (path) {
		console.log("Emptying " + path);
		fs.readdirSync(path).forEach(function(file,index){
		  var curPath = path + "/" + file;
		  // console.log(curPath);
		  fs.unlinkSync(curPath);
		});
	}
	function find_done () {
		if (modules.length) {
			module_name = modules.shift();
			create_array(module_name);
			return;
		}
		var missing_mods = ids.create_missing();
		if (missing_mods) {
			modules = modules.concat(missing_mods);
			find_done();
			return;
		}
		// ids.dump();
	}
	function array_done () {
		console.log("find_module");
		find_module(module_name);
	}
	function strip_fn (fn) {
		var current_dir = path.join(process.cwd(),"node_modules") + path.sep;
		if (fn.substr(0,current_dir.length) === current_dir) {
			fn = fn.substr(current_dir.length);
		}
		var global_dir = path.join(__dirname, "..", "node_modules") + path.sep;
		if (fn.substr(0,global_dir.length) === global_dir) {
			fn = "G_" + fn.substr(global_dir.length);
		}
		return fn;
	}
	function create_fn (filename) {
		var fn = strip_fn(filename);
		fn = fn.replace(/[^\w\-\.]/g,"_");
		fn = "fusejs_lib/" + fn;
		return fn;
	}

	mkdirSync("fusejs_lib");
	removeFiles("fusejs_lib");
	console.log("create_array");
	// modules.push(path.join(__dirname, "..", "shims", "document.js"));
	module_name = modules.shift();
	create_array(module_name);
};
