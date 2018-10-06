require! <[fs path js-yaml]>
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

  Or, using csvlook utility to transform the CSV data to markdown table:

    cat #{csv} | csvlook
  """


module.exports = exports =
  command: "ir2proto"
  describe: "generate device-prototyping yaml (legacy) used for mobile app development"

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
          ./bin/cli.js ir2proto ./examples/sensorboard-foop/schema.ir.json
      """

  handler: (argv) ->
    {output, verbose} = argv
    args = argv._
    args.shift!
    return ERR "missing one argument as SPEC source file" unless args.length > 0
    [file] = args
    return ERR "expect spec source file shall end with `.ir.json`" unless file.endsWith \.ir.json
    name = path.basename file, \.ir.json
    output = path.dirname file if output is ''
    INFO "output => #{output}"
    INFO "file => #{file}"
    (read-err, buffer) <- fs.readFile file
    return ERR read-err, "failed to read #{file}" if read-err?
    text = buffer.to-string!
    INFO "reading #{buffer.length} bytes from #{file}"
    opts = {verbose}
    try
      json = js-yaml.safeLoad text
    catch error
      return ERR error, "failed to parse #{file}"
    loader = new Loader file, json, opts
    loader.load!
    WRITE_FILE "#{output}/#{name}.proto.yaml", loader.to-device-prototyping-yaml!
    # PRINT_HELP_MESSAGE "#{output}/#{name}.csv", "#{output}/#{name}.db"
