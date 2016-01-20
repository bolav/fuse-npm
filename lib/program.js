var program = require('commander');
var pkg = require("../package.json");

var uniq = require("lodash/array/uniq");
var each = require("lodash/collection/each");

var modules = require("./modules");

program
  .version(pkg.version)
  // .option('-p, --peppers', 'Add peppers')
  .parse(process.argv);
 
var module_names = program.args;
module_names = uniq(module_names);
modules(module_names);
