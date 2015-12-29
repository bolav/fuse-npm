var mdeps = require('module-deps');

var builtins = require('browserify/lib/builtins');
var xtend = require('xtend');

var fs    = require('fs');
var path  = require('path');
var each = require("lodash/collection/each");
var babel = require('babel-core');
var ids = require('./ids');

console.log("Loading modules");

module.exports = function (module_name) {
	var loadModule = fs.createWriteStream('LoadModules.uno');

	function create_array(module_name) {
		mopts = {};
		mopts.modules = xtend(builtins);
		var md = mdeps();

		md.on('data', function process_data (file) {
			console.log(file.id);
			var fn = file.id;
			fn = fn.replace(/[^\w\-\.]/g,"_");
			fn = "fusejs_lib/" + fn;
			register(fn, file.id);
		});
		md.on('end', function () {
			array_done();
		});
		md.end({ file: module_name });		
	}
	function find_module(module_name) {
		mopts = {};
		mopts.modules = xtend(builtins);
		var md = mdeps();
		var trans_opts = { highlightCode: true,
						   presets: 'es2015,react,stage-2',
                           plugins: 'transform-object-assign,transform-fuse-requires',
                           comments: true,
                           babelrc: false,
                           ignore: null,
                           // filename: 't2.js',
                           only: null };

		md.on('data', function process_data (file) {
			console.log(file.id);
			var fn = file.id;
			fn = fn.replace(/[^\w\-\.]/g,"_");
			fn = "fusejs_lib/" + fn;
			ids.set_map(file.deps);
			trans_opts.filename = __filename;
			var trans = babel.transform(file.source, trans_opts);
			fs.writeFileSync(fn, trans.code);
		});
		md.on('end', function () {
			find_done();
		});
		md.end({ file: module_name });
	}
	function register (fn, orig) {
		var f = path.basename(orig);
		var i = 1;
		while (ids.get_used(f)) {
			i = i + 1;
			f = path.basename(orig) + "_" + i;
		}
		ids.add_id(orig, f);

		loadModule.write('        Register("'+ f +'", new FileModule(import BundleFile("'+ fn +'")));\n');
	}
	function process_file (a, b, c) {
		console.log("a: " + a);
		console.log("b: " + b);
		console.log("c: " + c);
	}
	function startLoadFile () {
		loadModule.write('using Uno;\n');
		loadModule.write('using Uno.Collections;\n');
		loadModule.write('using Fuse;\n');
		loadModule.write('using Fuse.Scripting;\n');
		loadModule.write('public class LoadModules : Behavior {\n');
		loadModule.write('    static void Register(string moduleId, IModule module) {;\n');
		loadModule.write('        Uno.UX.Resource.SetGlobalKey(module, moduleId);\n');
		loadModule.write('    }\n');
		loadModule.write('    public LoadModules () {\n');
		loadModule.write('        debug_log "Loading my modules";\n');
	}
	function endLoadFile () {
		loadModule.write('    }\n');
		loadModule.write('}\n');
		loadModule.end();
	}
	function mkdirSync (path) {
	  try {
	    fs.mkdirSync(path);
	  } catch(e) {
	    if ( e.code != 'EEXIST' ) throw e;
	  }
	}
	function find_done () {
		endLoadFile();
	}
	function array_done () {
		console.log("find_module");
		find_module(module_name);
	}

	mkdirSync("fusejs_lib");
	startLoadFile();
	console.log("create_array");
	create_array(module_name);

	// var ast = parse(code);

	// console.log(generate);
	// console.log(generate.default(ast, null, code));
};