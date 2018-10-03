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
    module.exports = {roots: roots, classes: classes, manifest: MANIFEST};
  }).call(this);
  """


HIGHLIGHT_JAVASCRIPT = (javascript) ->
  text = "```js\n#{javascript}\n```"
  renderer = new TerminalRenderer tab: 2
  marked.setOptions {renderer}
  return marked text


TRAVERSE_TREE = (name, classes) ->
  # aa = [ [c.displayName, c.superclass?] for k, c of classes ]
  # INFO "TRAVERSE_TREE: #{name} => #{JSON.stringify aa, null, ' '}"
  xs = [ n for n, c of classes when c.superclass.displayName is name ]
  # INFO "#{name}/xs => #{JSON.stringify xs}"
  ys = [ (TRAVERSE_TREE x, classes) for x in xs ]
  # INFO "#{name}/ys => #{JSON.stringify xs}"
  return [name] ++ ys


REMOVE_SCHEMA_BASE_CLASS = (peripheral_types) ->
  type = lodash.snakeCase BASE_CLASSNAME
  xs = [ (lodash.merge {}, pt) for pt in peripheral_types when pt.p_type isnt type ]
  for x in xs
    x.p_type_parent = null if x.p_type_parent is type
  return xs




class SchemaBaseClass
  ->
    @sensors = {}
    @actuators = {}

  declare-sensors: (types-and-identities) ->
    {sensors} = self = @
    for st, identities of types-and-identities
      self.sensors[st] = {}
      for id in identities
        self.sensors[st][id] = {}


class ActionTypeClass
  (@parser, @stc, @definition, @index) ->
    return

  load: ->
    {parser, stc, definition, index} = self = @
    {ptc} = stc
    prefix = "#{ptc.name.cyan}/_/#{stc.name.green}"
    throw new Error "#{prefix} has no action definition" unless definition?
    {action, argument, unit, description} = definition
    throw new Error "#{prefix} has no action name" unless action?
    self.name = name = action
    prefix = "#{prefix}/A[#{name.yellow}]"
    unit = '' unless unit? and \string is typeof unit
    description = '' unless description? and \string is typeof description
    throw new Error "#{prefix} has no action argument definition" unless argument?
    throw new Error "#{prefix} has action argument definition but not array" unless Array.isArray argument
    throw new Error "#{prefix} has action argument definition but no elements" if argument.length is 0
    [type, range, incremental] = argument
    throw new Error "#{prefix} has action argument definition but no type as 1st element" unless type? and \string is typeof type
    throw new Error "#{prefix} has action argument definition but unsupported type: #{type}" unless type in <[boolean enum float int]>
    throw new Error "#{prefix} has action argument definition but no range as 2nd element" unless range? and Array.isArray range
    if type is \boolean
      throw new Error "#{prefix} has action argument as boolean, but the number of elements in range is not 2 => #{range.length}" unless range.length is 2
      [false_alias, true_alias] = range
      throw new Error "#{prefix} has action argument as boolean, but alias for _false_ is not string: #{false_alias}(#{typeof false_alias})" unless \string is typeof false_alias
      throw new Error "#{prefix} has action argument as boolean, but alias for _true_ is not string: #{true_alias}(#{typeof true_alias})" unless \string is typeof true_alias
    else if type is \enum
      throw new Error "#{prefix} has action argument as enum, but no elements of range array" if range.length is 0
    else if type in <[float int]>
      throw new Error "#{prefix} has action argument as float, but the number of elements in range is not 2 => #{range.length}" unless range.length is 2
      [lower, upper] = range
      throw new Error "#{prefix} has action argument as float, but lower bound is not number: #{lower}(#{typeof lower})" unless \number is typeof lower
      throw new Error "#{prefix} has action argument as float, but upper bound is not number: #{upper}(#{typeof upper})" unless \number is typeof upper
      throw new Error "#{prefix} has action argument as float, but upper (#{upper}) is smaller than lower (#{lower})" if upper < lower
    self.unit = unit
    self.argument = {type, range, incremental}
    self.description = description
    xs = lodash.merge {}, definition
    delete xs['action']
    delete xs['argument']
    delete xs['unit']
    delete xs['description']
    names = [ k for k, v of xs when not k.startsWith "$" ]
    throw new Error "#{prefix} has annotations that are not started with '$': #{names.join ','}" if names.length > 0
    names = [ k for k, v of xs ]
    names.sort!
    xs = {[(n.substring 1), xs[n]] for n in names} # removing `$` prefix of annotation declaration.
    self.annotations = xs

  to-json: ->
    {name, argument, unit, annotations} = self = @
    return {name, argument, unit, annotations}


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
    names = [ k for k, v of xs ]
    names.sort!
    xs = {[(n.substring 1), xs[n]] for n in names} # removing `$` prefix of annotation declaration.
    self.annotations = xs

  to-json: ->
    {name, writeable, value, unit, annotations} = self = @
    return {name, writeable, value, unit, annotations}


class SensorInstanceClass
  (@parser, @stc, @s_id, @annotations) ->
    return

  load: ->
    return

  to-json: ->
    {s_id, annotations} = self = @
    return {s_id, annotations}


class SensorTypeClass
  (@parser, @ptc, @name, @instances, @fields, @actions) ->
    xs = [ k for k, v of instances ]
    @actions = [] unless @actions?
    INFO "#{ptc.name}/_/#{name}/[#{xs.join ','}] => fields: #{JSON.stringify fields}"
    INFO "#{ptc.name}/_/#{name}/[#{xs.join ','}] => actions: #{JSON.stringify @actions}" if @actions.length > 0
    return

  load: ->
    {parser, ptc, name, instances, fields, actions} = self = @
    prefix = "#{ptc.name.cyan}/_/#{name.green}"
    # console.log "#{prefix}: (SensorTypeClass) loading ..."
    throw new Error "#{prefix} has no s_id object list" unless instances?
    s_id_list = [ s_id for s_id, annotations of instances ]
    throw new Error "#{prefix} has s_id list but no elements" if s_id_list.length is 0
    throw new Error "#{prefix} has no fields" unless fields?
    throw new Error "#{prefix} has field list but not array" unless Array.isArray fields
    throw new Error "#{prefix} has field list but no elements" if fields.length is 0
    self.sic-list = xs = [ (new SensorInstanceClass parser, self, s_id, annotations) for s_id, annotations of instances ]
    self.ftc-list = ys = [ (new FieldTypeClass parser, self, f, i) for let f, i in fields ]
    self.atc-list = zs = [ (new ActionTypeClass parser, self, a, i) for let a, i in actions ]
    [ x.load! for x in xs ]
    [ y.load! for y in ys ]
    [ z.load! for z in zs ]
    return

  to-json: ->
    {name, sic-list, ftc-list, atc-list} = self = @
    fields = [ f.to-json! for f in ftc-list ]
    actions = [ a.to-json! for a in atc-list ]
    instances = [ s.to-json! for s in sic-list ]
    s_type = name
    return {s_type, instances, fields, actions}


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
    {sensors, actuators} = self.object = obj = new clazz!
    # console.log "#{name.cyan}: (PeripheralTypeClass) loading ... => #{JSON.stringify sensors}"
    throw new Error "#{ptc.name.cyan} has no defined `sensors`" unless sensors? and \object is typeof sensors
    self.stc-list = xs = [ (new SensorTypeClass parser, self, s_type, s_instances, obj[s_type], actuators[s_type]) for s_type, s_instances of sensors ]
    [ x.load! for x in xs ]

  to-json: ->
    {name, classname, ptc-parent, stc-list} = self = @
    p_type_parent = if ptc-parent? then ptc-parent.name else null
    p_type = name
    class_name = classname
    sensor_types = [ s.to-json! for s in stc-list ]
    return {p_type, p_type_parent, class_name, sensor_types}



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
    self.js-source = javascript = modified
    self.js-highlighted = highlighted = HIGHLIGHT_JAVASCRIPT javascript
    {roots, classes, manifest} = ex
    throw new Error "missing roots in module.exports" unless roots?
    throw new Error "invalid roots in module.exports" unless \object is typeof roots
    throw new Error "missing classes in module.exports" unless classes?
    throw new Error "invalid classes in module.exports" unless \object is typeof classes
    throw new Error "missing manifest in module.exports" unless manifest?
    throw new Error "invalid manifest in module.exports" unless \object is typeof manifest
    {name, version} = manifest
    throw new Error "missing _name_ in manifest" unless name?
    throw new Error "missing _version_ in manifest" unless version?
    for name, root of roots
      throw new Error "the root class #{name} is not derived from #{BASE_CLASSNAME}" unless root.superclass.displayName is BASE_CLASSNAME
    xs = [ name for name, c of classes when \function isnt typeof c ]
    INFO "these variables shall be ignored: #{xs.join ', '}"
    classes = {[name, c] for name, c of classes when \function is typeof c}
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
    peripheral_types = [ p.to-json! for p in types ]
    # peripheral_types = REMOVE_SCHEMA_BASE_CLASS peripheral_types
    manifest = lodash.merge {format: 2, created_at: (new Date!)}, manifest
    self.jsonir = jsonir = {manifest, peripheral_types}
    self.yamlir = yamlir = js-yaml.safeDump jsonir, {skipInvalid: yes, noRefs: yes}
    return {javascript, highlighted, jsonir, yamlir}

  get-ptc-by-name: (name) ->
    return @p-type-map-by-name[name]

  get-ptc-by-classname: (classname) ->
    return @p-type-map-by-classname[classname]


module.exports = exports = {SchemaParser}
