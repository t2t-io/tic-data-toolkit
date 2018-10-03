require! <[fs path]>
{DBG, WARN, INFO, ERR} = global.get-logger __filename
{Loader} = require \./helpers/schema-ir

WRITE_FILE = (fullpath, text) ->
  INFO "writing #{fullpath} with #{text.length} bytes"
  fs.writeFileSync fullpath, text


PRINT_HELP_MESSAGE = (mmd1, mmd2) ->
  console.log """
  You can simply run following commands to generate PNG images from the source text generated
  by current subcommand:

    ./node_modules/.bin/mmdc -i #{mmd1} -o #{mmd1}.png -b transparent
    ./node_modules/.bin/mmdc -i #{mmd2} -o #{mmd2}.png -b transparent
  """

module.exports = exports =
  command: "ir2diagram"
  describe: "generate the text sources of several diagrams from IR for mermaid to produce PNG images"

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
          ./bin/cli.js ir2digram /tmp/electrical-equipment.ir.json
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
    {class-lr, class-std} = loader.to-mermaid-digrams!
    class-lr-filename = "#{output}/#{name}.class-lr.mmd"
    class-std-filename = "#{output}/#{name}.class.mmd"
    WRITE_FILE class-lr-filename, class-lr
    WRITE_FILE class-std-filename, class-std
    PRINT_HELP_MESSAGE class-lr-filename, class-std-filename
