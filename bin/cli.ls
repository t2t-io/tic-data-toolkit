#!/usr/bin/env lsc
#
logger = require \yap-simple-logger
logger.init \tic-data-toolkit, __filename

argv =
  (require \yargs)
    .alias \h, \help
    .command require \../src/schema2js
    .command require \../src/schema2ir
    .command require \../src/ir2csv
    .command require \../src/ir2spec
    .command require \../src/ir2diagram
    .demand 1
    .strict!
    .help!
    .argv