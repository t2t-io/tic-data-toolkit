require! <[fs path]>
{DBG, WARN, INFO, ERR} = global.get-logger __filename
{Loader} = require \./helpers/schema-ir

WRITE_FILE = (fullpath, text) ->
  INFO "writing #{fullpath} with #{text.length} bytes"
  fs.writeFileSync fullpath, text


module.exports = exports =
  command: "ir2spec"
  describe: "generate the legacy spec.yaml for SensorWeb3 to load (deprecated since SensorWeb4)"

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
          ./bin/cli.js ir2spec /tmp/electrical-equipment.ir.json
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
    spec = loader.to-spec!
    WRITE_FILE "#{output}/#{name}.spec.yaml", spec
