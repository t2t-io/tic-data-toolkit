#!/usr/bin/env lsc
#
logger = require \yap-simple-logger
logger.init \tic-dk, __filename

argv =
  (require \yargs)
    .alias \h, \help
    .command require \../src/schema2js
    .demand 1
    .strict!
    .help!
    .argv