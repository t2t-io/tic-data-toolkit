require! <[fs path]>
{DBG, WARN, INFO, ERR} = global.get-logger __filename
{Loader} = require \./helpers/schema-ir

WRITE_FILE = (fullpath, text) ->
  INFO "writing #{fullpath} with #{text.length} bytes"
  fs.writeFileSync fullpath, text


PRINT_HELP_MESSAGE = (csv, db) ->
  console.log """
  You can simply run following command to import CSV into SQLite3 database, and feel free to perform
  any kinds of query:

    rm -f #{db} && \\
      echo -e ".mode csv\\n.import #{csv} DataSchema\\n.mode col\\nSELECT * FROM DataSchema;" | sqlite3 #{db}
  """


module.exports = exports =
  command: "ir2csv"
  describe: "generate CSV from IR for SQLite to import"

  builder: (yargs) ->
    yargs
      .alias \o, \output
      .describe \o, 'compile into the specified directory (same directory of IR file when the option is not specified'
      .default \o, ''
      .alias \v, \verbose
      .describe \v, 'enable verbose messages'
      .default \v, no
      .alias \h, \help
      .demand <[v o]>
      .boolean <[v]>
      .epilogue """
        For example:
          ./bin/cli.js ir2csv /tmp/electrical-equipment.ir.json
      """

  handler: (argv) ->
    {output, verbose} = argv
    args = argv._
    args.shift!
    return ERR "missing one argument as IR source file" unless args.length > 0
    [file] = args
    name = path.basename file, \.ir.json
    output = path.dirname file if output is ''
    fullpath = "#{output}/#{name}.js"
    INFO "output => #{output}"
    INFO "file => #{file}"
    (read-err, buffer) <- fs.readFile file
    return ERR read-err, "failed to read #{file}" if read-err?
    text = buffer.to-string!
    INFO "reading #{buffer.length} bytes from #{file}"
    opts = {verbose}
    try
      json = JSON.parse text
    catch error
      return ERR error, "failed to parse #{file}"
    loader = new Loader file, json, opts
    loader.load!
    csv = loader.to-csv!
    WRITE_FILE "#{output}/#{name}.csv", csv
    PRINT_HELP_MESSAGE "#{output}/#{name}.csv", "#{output}/#{name}.db"