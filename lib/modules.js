var traverse = require("babel-traverse").default;
var assert = require("assert");
var parse = require("babylon").parse;
var generate = require("babel-generator");

var mdeps = require('module-deps');
var JSONStream = require('JSONStream');
var through = require('through2');

var builtins = require('browserify/lib/builtins');
var xtend = require('xtend');

var fs    = require('fs');
var path  = require('path');
var each = require("lodash/collection/each");
var babel = require('babel-core');

var code = "function square(n) {  return n * n; }";

console.log("Loading modules");

module.exports = function (module_name) {
	var id_id = {};
	var used_id = {};
	var loadModule = fs.createWriteStream('LoadModules.uno');

	function find_module(module_name) {
		console.log("Looking for " + module_name);

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

		// md.pipe(JSONStream.stringify()).pipe(process.stdout);
		md.on('data', function process_data (file) {
			console.log("data");
			// console.log(file);
			var fn = file.id;
			fn = fn.replace(/[^\w\-\.]/g,"_");
			fn = "fusejs_lib/" + fn;
			register(fn, file.id);
			console.log("Writing to " + fn );
			trans_opts.filename = __filename;
			var trans = babel.transform(file.source, trans_opts);
			fs.writeFileSync(fn, trans.code);
			// console.log(file.deps);
			each(file.deps, function (s, t) {
				// console.log(t);
			});
		});
		md.on('file', function process_file (file, id) {
			//console.log("file");
			//console.log(file);
			//console.log(id);
		});
		md.on('package', function process_package (pkg) {
			console.log("package");
			// console.log(pkg);
		});
		md.on('transform', function (tr, file) {
			console.log("transform");
			console.log(tr);
			console.log(file);
		});
		md.on('end', function () {
			done();
			//console.log("Finished!!");
			//console.log(id_id);
		});
		md.end({ file: module_name });
		// console.log(builtins);

//		var mopts = {"id": module_name, "file": module_name };
//		var _mdeps = mdeps(mopts);
//		md.pipe(JSONStream.stringify()).pipe(process.stdout);
//		md.end({ file: __dirname + '/files/main.js' });
		
	}
	function register (fn, orig) {
		var f = path.basename(orig);
		console.log("basename of " + fn + " is " + f);
		// id_id[orig] = s.replace(/[^\w\-\.]/g,"_");
		var i = 1;
		while (used_id[f]) {
			i = i + 1;
			f = path.basename(orig) + "_" + i;
		}
		id_id[orig] = f;
		used_id[f] = 1;

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
	function done () {
		endLoadFile();
	}

	mkdirSync("fusejs_lib");
	startLoadFile();
	find_module(module_name);

	// var ast = parse(code);

	// console.log(generate);
	// console.log(generate.default(ast, null, code));
};