Fuse NPM
========

Load NPM modules in your fuse project.

Status: alpha

Load [npm](https://www.npmjs.com/) modules in [Fusetools](https://www.fusetools.com/).


What does it do:
----------------

- Transpiles
- Edit require statements
- Insert shims (TODO list shims here:)


How to use it:
--------------

- git clone fuse-npm into a dir
- `npm install` in fuse-npm dir
- `node <path_to_loadmodule>/loadmodules.js <package>` in your Fuse app dir
- Bundle the js files in your app. Edit `.unoproj`:
```
"Includes": [
  "*.uno",
  "*.ux",
  "*.uxl",
  "fusejs_lib/*.js:Bundle"
]
```
- Filenames are changed so look for the correct file in fusejs_lib, and use it as `require ('new_name');`


Manual changes:
---------------

Most modules requires manual changes for now. Please fix it and send PR, or report them as issues.


TODO:
-----

- Buffer
- process
- global.XMLHttpRequest = XMLHttpRequest;
- global.location = {}; // global.location.host
- var process = {};
- - process.nextTick = function() {};
