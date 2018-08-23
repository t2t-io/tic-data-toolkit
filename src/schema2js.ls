require! <[fs path]>
{DBG, WARN, INFO, ERR} = global.get-logger __filename
{COMPILE_LIVESCRIPT} = require \./helpers/common


module.exports = exports =
  command: "schema2js"
  describe: "compile schema source to javascript (ls => js)"

  builder: (yargs) ->
    yargs
      .alias \o, \output
      .describe \o, 'compile into the specified directory'
      .alias \v, \verbose
      .describe \v, 'enable verbose messages'
      .default \v, no
      .alias \h, \help
      .demand <[v o]>
      .boolean <[v]>
      .epilogue """
        For example:
          ./bin/cli.js schema2js -o /tmp ./examples/electrical-equipment.ls
      """

  handler: (argv) ->
    {output, verbose} = argv
    args = argv._
    args.shift!
    return ERR "missing one argument as schema source" unless args.length > 0
    [file] = args
    name = path.basename file, \.ls
    fullpath = "#{output}/#{name}.js"
    # INFO "output => #{output}"
    # INFO "file => #{file}"
    # INFO "fullpath => #{fullpath}"
    (compile-err, js) <- COMPILE_LIVESCRIPT file
    return ERR compile-err, "failed to read and compile" if compile-err?
    (write-err) <- fs.writeFile fullpath, js
    return ERR write-err, "failed to write file" if write-err?
    return INFO "successfully compile and write to #{fullpath}, with #{js.length} bytes"

