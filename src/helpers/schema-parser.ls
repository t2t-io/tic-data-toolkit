require! <[vm]>
require! <[lodash esprima livescript async marked js-yaml]>
TerminalRenderer = require \marked-terminal
{DBG, WARN, INFO, ERR} = global.get-logger __filename

const BASE_CLASSNAME = \SchemaBaseClass
const DEFAULT_PARSER_OPTIONS = {verbose: no}

GENERATE_NEW_JAVASCRIPT = (javascript, class-names) ->
  xs = javascript.split '\n'
  xs = [ "  #{x}" for x in xs when not x.startsWith "module.exports =" ]
  ys = [ "#{c}: #{c}" for c in class-names ]
  return """
  (function(){
  #{xs.join '\n'}
    var classes = {#{ys.join ', '}};
    module.exports = {roots: roots, classes: classes};
  }).call(this);
  """


HIGHLIGHT_JAVASCRIPT = (javascript) ->
  text = "```js\n#{javascript}\n```"
  renderer = new TerminalRenderer tab: 2
  marked.setOptions {renderer}
  return marked text


TRAVERSE_TREE = (name, classes) ->
  xs = [ n for n, c of classes when c.superclass.displayName is name ]
  # INFO "#{name}/xs => #{JSON.stringify xs}"
  ys = [ (TRAVERSE_TREE x, classes) for x in xs ]
  # INFO "#{name}/ys => #{JSON.stringify xs}"
  return [name] ++ ys


class SchemaBaseClass
  ->
    @attributes = {}


class FieldTypeClass
  (@parser, @stc, @definition, @index) ->
    return

  load: ->
    {parser, stc, definition, index} = self = @
    {ptc} = stc
    prefix = "#{ptc.name.cyan}/_/#{stc.name.green}"
    throw new Error "#{prefix} has no field definition" unless definition?
    {field, writeable, value, unit, description} = definition
    throw new Error "#{prefix} has no field name" unless field?
    self.name = name = field
    prefix = "#{prefix}/#{name.yellow}"
    # console.log "#{prefix}: (FieldTypeClass) loading ..."
    unit = '' unless unit? and \string is typeof unit
    description = '' unless description? and \string is typeof description
    writeable = no unless writeable? and \boolean is typeof writeable
    throw new Error "#{prefix} has no field value definition" unless value?
    throw new Error "#{prefix} has field value definition but not array" unless Array.isArray value
    throw new Error "#{prefix} has field value definition but no elements" if value.length is 0
    [type, range, incremental] = value
    throw new Error "#{prefix} has field value definition but no type as 1st element" unless type? and \string is typeof type
    throw new Error "#{prefix} has field value definition but unsupported type: #{type}" unless type in <[boolean enum float int]>
    throw new Error "#{prefix} has field value definition but no range as 2nd element" unless range? and Array.isArray range
    if type is \boolean
      throw new Error "#{prefix} has field value as boolean, but the number of elements in range is not 2 => #{range.length}" unless range.length is 2
      [false_alias, true_alias] = range
      throw new Error "#{prefix} has field value as boolean, but alias for _false_ is not string: #{false_alias}(#{typeof false_alias})" unless \string is typeof false_alias
      throw new Error "#{prefix} has field value as boolean, but alias for _true_ is not string: #{true_alias}(#{typeof true_alias})" unless \string is typeof true_alias
    else if type is \enum
      throw new Error "#{prefix} has field value as enum, but no elements of range array" if range.length is 0
    else if type in <[float int]>
      throw new Error "#{prefix} has field value as float, but the number of elements in range is not 2 => #{range.length}" unless range.length is 2
      [lower, upper] = range
      throw new Error "#{prefix} has field value as float, but lower bound is not number: #{lower}(#{typeof lower})" unless \number is typeof lower
      throw new Error "#{prefix} has field value as float, but upper bound is not number: #{upper}(#{typeof upper})" unless \number is typeof upper
      throw new Error "#{prefix} has field value as float, but upper (#{upper}) is smaller than lower (#{lower})" if upper < lower
    self.writeable = writeable
    self.unit = unit
    self.value = {type, range, incremental}
    self.description = description
    xs = lodash.merge {}, definition
    delete xs['field']
    delete xs['writeable']
    delete xs['value']
    delete xs['unit']
    delete xs['description']
    names = [ k for k, v of xs when not k.startsWith "$" ]
    throw new Error "#{prefix} has annotations that are not started with '$': #{names.join ','}" if names.length > 0
    self.annotations = xs

  to-json: ->
    {name, writeable, value, annotations} = self = @
    return {name, writeable, value, annotations}



class SensorTypeClass
  (@parser, @ptc, @name, @identities, @fields) ->
    # console.log "#{ptc.name}/????/#{name}/[#{identities.join ','}] => #{JSON.stringify fields}"
    return

  load: ->
    {parser, ptc, name, identities, fields} = self = @
    prefix = "#{ptc.name.cyan}/_/#{name.green}"
    # console.log "#{prefix}: (SensorTypeClass) loading ..."
    throw new Error "#{prefix} has no s_id list" unless identities?
    throw new Error "#{prefix} has s_id but not array" unless Array.isArray identities
    throw new Error "#{prefix} has s_id list but no elements" if identities.length is 0
    throw new Error "#{prefix} has s_id list has no string element" unless \string is typeof identities[0]
    throw new Error "#{prefix} has no fields" unless fields?
    throw new Error "#{prefix} has field list but not array" unless Array.isArray fields
    throw new Error "#{prefix} has field list but no elements" if fields.length is 0
    self.ftc-list = xs = [ (new FieldTypeClass parser, self, f, i) for let f, i in fields ]
    [ x.load! for x in xs ]
    return

  to-json: ->
    {name, identities, ftc-list} = self = @
    fields = [ f.to-json! for f in ftc-list ]
    s_type = name
    s_id_list = identities
    return {s_type, s_id_list, fields}


class PeripheralTypeClass
  (@parser, @verbose, @clazz) ->
    {displayName} = clazz
    @classname = displayName
    @name = lodash.snakeCase displayName
    @ptc-children = []
    @ptc-parent = null
    @object = null
    return

  add-child: (child) ->
    @ptc-children.push child

  dbg: (message) ->
    return DBG message if @verbose

  dbg-hierachy: ->
    {name, ptc-children, ptc-parent} = self = @
    ptc-children = [ c.name.cyan for c in ptc-children ]
    ptc-parent = if ptc-parent? then ptc-parent.name else "<<ROOT>>"
    text = if ptc-children.length is 0 then "" else " <- [#{ptc-children.join ', '}]"
    self.dbg "#{ptc-parent.green} <- #{name.yellow}#{text}"

  load: ->
    {parser, clazz, classname, name} = self = @
    self.ptc-parent = ptc-parent = if classname is BASE_CLASSNAME then null else parser.get-ptc-by-classname clazz.superclass.displayName
    self.ptc-parent.add-child self if ptc-parent?
    self.ptc-parent-name = ptc-parent-name = if ptc-parent? then ptc-parent.name else null
    {attributes} = self.object = obj = new clazz!
    # console.log "#{name.cyan}: (PeripheralTypeClass) loading ... => #{JSON.stringify attributes}"
    throw new Error "#{ptc.name.cyan} has no defined `attributes`" unless attributes? and \object is typeof attributes
    self.stc-list = xs = [ (new SensorTypeClass parser, self, s_type, s_id_list, obj[s_type]) for s_type, s_id_list of attributes ]
    [ x.load! for x in xs ]

  to-json: ->
    {name, classname, ptc-parent, stc-list} = self = @
    p_type_parent = if ptc-parent? then ptc-parent.name else null
    p_type = name
    sensor_types = [ s.to-json! for s in stc-list ]
    return {p_type, p_type_parent, classname, sensor_types}



class SchemaParser
  (opts) ->
    @opts = lodash.merge {}, DEFAULT_PARSER_OPTIONS, opts
    {verbose} = @opts
    @verbose = verbose

  dbg: (message) ->
    return DBG message if @verbose

  err: ->
    ERR.apply null, arguments
    return no

  load-js: (javascript) ->
    self = @
    self.dbg "loading javascript (#{javascript.length} bytes)"
    try
      script = new vm.Script javascript
      sandbox = module: {}, SCHEMA_BASE_CLASS: SchemaBaseClass
      context = vm.createContext sandbox
      script.runInContext context
      for k, v of sandbox.module.exports
        for x, y of v
          self.dbg "loading javascript: #{k}/#{x}"
      return [null, sandbox.module.exports]
    catch error
      return [error]

  parse: (@source) ->
    {opts, verbose} = self = @
    bare = yes
    javascript = livescript.compile source, {bare}
    p = esprima.parse javascript
    declarations = p.body[0].declarations
    variable-declarations = [ d.id for d in declarations when d.type is \VariableDeclarator ]
    variable-names = [ v.name for v in variable-declarations ]
    throw new Error "missing variable `roots`" unless \roots in variable-names
    variable-names = [ v for v in variable-names when v isnt BASE_CLASSNAME and v not in <[roots exports]> ]
    self.dbg "variables: #{JSON.stringify variable-names}"
    modified = GENERATE_NEW_JAVASCRIPT javascript, variable-names
    [load-err, ex] = self.load-js modified
    throw load-err if load-err?
    {roots, classes} = ex
    throw new Error "missing roots in module.exports" unless roots?
    throw new Error "invalid roots in module.exports" unless \object is typeof roots
    throw new Error "missing classes in module.exports" unless classes?
    throw new Error "invalid classes in module.exports" unless \object is typeof classes
    for name, root of roots
      throw new Error "the root class #{name} is not derived from #{BASE_CLASSNAME}" unless root.superclass.displayName is BASE_CLASSNAME
    xs = [ (TRAVERSE_TREE name, classes) for name, root of roots ]
    self.dbg "results.a => #{JSON.stringify xs}"
    xs = lodash.flattenDeep xs
    self.dbg "results.b => #{JSON.stringify xs}"
    ys = [ x.yellow for x in xs ]
    INFO "load classes in order: #{xs.join ', '}"
    classes[BASE_CLASSNAME] = SchemaBaseClass
    self.loaded-class-names = names = [BASE_CLASSNAME] ++ xs
    self.loaded-classes = classes
    self.p-types = types = [ (new PeripheralTypeClass self, verbose, classes[n]) for n in names ]
    self.p-type-map-by-name = {[t.name, t] for t in types}
    self.p-type-map-by-classname = {[t.classname, t] for t in types}
    [ t.load! for t in types ]
    [ t.dbg-hierachy! for t in types ]
    self.js-source = javascript = modified
    self.js-highlighted = highlighted = HIGHLIGHT_JAVASCRIPT javascript
    peripheral_types = [ p.to-json! for p in types ]
    self.jsonir = jsonir = {peripheral_types}
    self.yamlir = yamlir = js-yaml.safeDump jsonir, {skipInvalid: yes}
    return {javascript, highlighted, jsonir, yamlir}

  get-ptc-by-name: (name) ->
    return @p-type-map-by-name[name]

  get-ptc-by-classname: (classname) ->
    return @p-type-map-by-classname[classname]

module.exports = exports = {SchemaParser}
