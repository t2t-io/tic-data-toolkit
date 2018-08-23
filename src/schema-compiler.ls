#!/usr/bin/env lsc
#
require! <[vm fs path]>
require! <[lodash yargs livescript async]>
global.verbose= no

DBG = (message) ->
  console.error "DBG: #{message}" if global.verbose

LOAD_LIVESCRIPT = (fullpath, done) ->
  (err, buffer) <- fs.readFile fullpath
  return done err if err?
  text = "#{buffer}"
  try
    js = livescript.compile text
    script = new vm.Script js
    sandbox = module: {}
    context = vm.createContext sandbox
    script.runInContext context
    return done null, sandbox.module.exports
  catch error
    return done error

TO_MERMAID_SENSOR_FIELDS = (name, st, fields) ->
    xs = [ [name, "#{st} \: #{f.field}"] for f in fields ]
    xs = [ x.join ' : ' for x in xs ]
    xs.push "#{name} : --------"
    return xs
    # return xs.join '\n'

GET_SENSOR_TYPES = (c) ->
  return [] unless c?
  {superclass, sensor-types} = c
  types = [ k for k, v of sensor-types ]
  return types unless superclass?
  return types ++ GET_SENSOR_TYPES superclass

GET_SENSOR_FIELD_NAMES = (fields) ->
  return [ f.field for f in fields ]

GET_SENSOR_FIELD_NAMES_FOR_MARKDOWN = (fields) ->
  names = GET_SENSOR_FIELD_NAMES fields
  names = [ "`#{n}`" for n in names ]
  return names.join ", "

EXTRACT_FIELD_CURRYING = (name, data) -->
  return data unless name?
  return data unless \string is typeof name
  return data if name is ''
  return data[name]


class Class
  (@clazz, @manager) ->
    {displayName} = clazz
    @name = displayName
    @subclasses = []
    @p_type = lodash.snakeCase @name
    return

  init: (done) ->
    {name, manager, p_type, clazz} = self = @
    DBG "parsing #{name}: => #{p_type}"
    dummy = self.dummy = new clazz {}
    names = [ k for k, v of dummy when k isnt \constructor ]
    sensor-types = self.sensor-types = { [n, dummy[n]] for n in names }
    DBG "parsing #{name}: => #{JSON.stringify sensor-types}"
    return done! unless clazz.superclass?
    superclass = self.superclass = manager.get-clazz clazz.superclass.displayName
    return done "cannot find super class #{clazz.superclass.displayName} of #{name}" unless superclass?
    superclass.subclasses.push self
    return done!

  to-json: ->
    {name, superclass, p_type, sensor-types} = self = @
    parent = if superclass? then superclass.name else null
    return {name, parent, p_type, sensor-types}

  to-output-json: (simple=no) ->
    {name, superclass, p_type, sensor-types} = self = @
    func = if simple then (EXTRACT_FIELD_CURRYING 'field') else (EXTRACT_FIELD_CURRYING '')
    parent = if superclass? then superclass.name else null
    s_types = { [k, [(func f) for f in v]] for k, v of sensor-types }
    return {name, parent, p_type, s_types}


  dump-mermaid-class: (dump-child=no, simple=no) ->
    {name, subclasses, sensor-types} = self = @
    # DBG "dumping #{name}"
    ss = GET_SENSOR_TYPES self.superclass
    # DBG "#{name}'s parent's sensor-types: #{ss.join ','}"
    xs = [ "#{name} <|-- #{child.name}" for child in subclasses ]
    if simple
      ys = [ "#{name} \: #{st}" for st, o of sensor-types when not (st in ss) ]
    else
      ys = [ (TO_MERMAID_SENSOR_FIELDS name, st, o) for st, o of sensor-types when not (st in ss) ]
      ys = [ y for x in ys for y in x ]
    zs = xs ++ ys
    text = zs.join '\n'
    # DBG "text => #{text}"
    return text unless dump-child
    return text if subclasses.length is 0
    children = [ (c.dump-mermaid-class yes, simple) for c in subclasses ]
    return "#{text}\n#{children.join '\n'}"

  dump-markdown: ->
    {name, p_type, sensor-types} = self = @
    ss = GET_SENSOR_TYPES self.superclass
    s-types = [ st for st, fields of sensor-types when not (st in ss) ]
    header = "### #{name} (`#{p_type}`)"
    return [header, ""] if s-types.length is 0
    xs = """
      #{header}

      | p_type | s_type | fields |
      |---|---|---|
    """
    xs = xs.split '\n'
    ys = [ "| `#{p_type}` | `#{st}` | #{GET_SENSOR_FIELD_NAMES_FOR_MARKDOWN fields} |" for st, fields of sensor-types when not (st in ss) ]
    zs = xs ++ ys ++ [""]
    return zs


class ClassManager
  (@schema) ->
    @classes = []
    @class-map = {}
    return

  init: (done) ->
    {schema} = self = @
    self.classes = classes = [ (new Class clazz, self) for name, clazz of schema ]
    self.class-map = {[c.name, c] for c in classes}
    f = (c, cb) -> return c.init cb
    (init-err) <- async.eachSeries classes, f
    return done init-err if init-err?
    return done!

  get-clazz: (name) ->
    return @class-map[name]

  generate-mermaid-class-diagram: (fullpath="/tmp/schema.mmd", simple=no)->
    {classes, class-map} = self = @
    names = [ c.name for c in classes ]
    DBG "names => #{names.join ', '}"
    top = [ c for c in classes when not c.superclass? ]
    ys = [ "classDiagram" ]
    xs = [ (c.dump-mermaid-class yes, simple) for c in top ]
    zs = ys ++ xs
    text = zs.join '\n'
    (err) <- fs.writeFile fullpath, text
    return console.dir err if err?
    console.log """


      You can copy and paste following text to https://mermaidjs.github.io/mermaid-live-editor/
      to generate SVG:
      ------

      #{text}

      ------
      Or, run this command:

          ./node_modules/mermaid.cli/index.bundle.js -i #{fullpath} -o #{fullpath}.png
          ./node_modules/mermaid.cli/index.bundle.js -i #{fullpath} -o #{fullpath}.pdf
          ./node_modules/mermaid.cli/index.bundle.js -i #{fullpath} -o #{fullpath}.svg
          open #{fullpath}.png
          open #{fullpath}.pdf
          open -a "Google Chrome" #{fullpath}.svg
    """


  generate-markdown: (fullpath="/tmp/schema.md", source="") ->
    {classes, class-map} = self = @
    names = [ c.name for c in classes ]
    DBG "names => #{names.join ', '}"
    xs = [ c.dump-markdown! for c in classes ]
    xs = [ a for x in xs for a in x ]
    ys = []
    zs = ["![](#{path.basename source}.png)", ""] ++ xs ++ ys
    text = zs.join '\n'
    (err) <- fs.writeFile fullpath, text
    return console.dir err if err?
    console.log "written to #{fullpath}"


  generate-json: (fullpath="/tmp/schema.md", source="") ->
    {classes} = self = @
    xs = [ c.to-output-json! for c in classes ]
    text = JSON.stringify xs, null, '  '
    (err) <- fs.writeFile fullpath, text
    return console.dir err if err?
    console.log "written to #{fullpath}"




argv = yargs
  .alias \s, \schema
  .describe \s, 'the input schema file, e.g. schema.ls'
  .alias \f, \format
  .describe \f, 'the output file format, e.g. mermaid, merimaid-simple, markdown, json'
  .default \f, \markdown
  .alias \v, \verbose
  .describe \v, 'enable verbose output messages'
  .default \v, no
  .demandOption <[schema format verbose]>
  .boolean <[verbose]>
  .strict!
  .help!
  .argv

{schema, format, verbose} = argv
global.verbose = verbose
DBG "schema => #{schema}"
DBG "format => #{format}"
DBG "output => #{output}"
DBG "verbose => #{verbose}"
return console.error "invalid format: #{format}" unless format in <[markdown mermaid mermaid-simple json]>
output = switch format
  | \mermaid        => "#{schema}.mmd"
  | \mermaid-simple => "#{schema}.simple.mmd"
  | \markdown       => "#{schema}.md"
  | \json           => "#{schema}.json"
  | otherwise       => "#{schema}.txt"
(load-err, SCHEMA) <- LOAD_LIVESCRIPT schema
return console.error load-err if load-err?
manager = global.manager = new ClassManager SCHEMA
(init-err) <- manager.init
return console.error init-err if init-err?
return manager.generate-mermaid-class-diagram output, no if format is \mermaid
return manager.generate-mermaid-class-diagram output, yes if format is \mermaid-simple
return manager.generate-markdown output, schema if format is \markdown
return manager.generate-json output if format is \json
