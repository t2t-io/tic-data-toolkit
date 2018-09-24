require! <[fs path]>
{DBG, WARN, INFO, ERR} = global.get-logger __filename
{COMPILE_LIVESCRIPT} = require \./helpers/common
{SchemaParser} = require \./helpers/schema-parser


WRITE_FILE = (fullpath, text) ->
  INFO "writing #{fullpath} with #{text.length} bytes"
  fs.writeFileSync fullpath, text


module.exports = exports =
  command: "schema2ir"
  describe: "compile schema source to IR (intermediate representation)"

  builder: (yargs) ->
    yargs
      .alias \o, \output
      .describe \o, 'compile into the specified directory'
      .alias \s, \sqlite
      .describe \s, 'output sqlite3 database as well'
      .default \s, no
      .alias \v, \verbose
      .describe \v, 'enable verbose messages'
      .default \v, no
      .alias \h, \help
      .demand <[v o]>
      .boolean <[v]>
      .epilogue """
        For example:
          ./bin/cli.js schema2spec -o /tmp ./examples/electrical-equipment.ls
      """

  handler: (argv) ->
    {output, verbose} = argv
    args = argv._
    args.shift!
    return ERR "missing one argument as schema source" unless args.length > 0
    [file] = args
    name = path.basename file, \.ls
    fullpath = "#{output}/#{name}.js"
    INFO "output => #{output}"
    INFO "file => #{file}"
    (read-err, buffer) <- fs.readFile file
    return ERR read-err, "failed to read #{file}" if read-err?
    text = buffer.to-string!
    opts = {verbose}
    parser = new SchemaParser opts
    try
      {javascript, highlighted, jsonir, yamlir} = parser.parse text
    catch error
      return ERR error, "failed to parse #{file}"
    WRITE_FILE "#{output}/#{name}.js", javascript
    WRITE_FILE "#{output}/#{name}.js.colored", highlighted
    WRITE_FILE "#{output}/#{name}.ir.json", JSON.stringify jsonir, null, ' '
    WRITE_FILE "#{output}/#{name}.ir.yaml", yamlir
    INFO "done."
