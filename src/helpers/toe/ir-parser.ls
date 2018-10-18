##
# The parser for SensorWeb4 to parse the schema of specific peripheral-service, with the given IR source
# file in json format. Please note, this module is shared between `tic-data-toolkit` and `yapps-tt`
# repository.
#
require! <[fs path crypto]>
{lodash_merge, lodash_sortBy} = global.get-bundled-modules!
{DBG, WARN, INFO, ERR} = global.get-logger __filename

const SchemaBaseClassName = \schema_base_class


class ActionTypeClass
  (@spec, @sensor-type, @verbose) ->
    {name, argument, unit, description, annotations} = spec
    {type, range, incremental} = argument
    {peripheral-type} = sensor-type
    self = @
    self.name = name
    self.argument-type = type
    self.argument-range = range
    self.argument-incremental = incremental
    self.argument-unit = unit
    self.description = description
    self.annotations = annotations
    u = if unit? and unit.length > 0 then "unit:#{unit.gray}, " else ""
    INFO "loading #{peripheral-type.name.cyan}/#{sensor-type.name.green}/#{'*'.magenta}/#{name.yellow} => #{type}, [#{range.join ', '}], #{u}" if verbose

  init: ->
    return

  get-description: ->
    return if @description? then @description else "''"

  get-unit: ->
    return if @unit? then @unit else "''"

  get-annotations: (sensor-instance=null) ->
    return lodash_merge {}, @annotations unless sensor-instance?
    return lodash_merge {}, @annotations, sensor-instance.annotations


class FieldTypeClass
  (@spec, @sensor-type, @verbose) ->
    {name, writeable, value, unit, description, annotations} = spec
    {type, range, incremental} = value
    {peripheral-type} = sensor-type
    self = @
    self.name = name
    self.writeable = writeable
    self.value-type = type
    self.value-range = range
    self.value-incremental = incremental
    self.value-unit = unit
    self.description = description
    self.annotations = annotations
    u = if unit? and unit.length > 0 then "unit:#{unit.gray}, " else ""
    w = if writeable then "writeable".blue else ""
    INFO "loading #{peripheral-type.name.cyan}/#{sensor-type.name.green}/#{'*'.magenta}/#{name.yellow} => #{type}, [#{range.join ', '}], #{u}#{w}" if verbose

  init: ->
    return

  get-name: ->
    return @name

  get-type: ->
    return @value-type

  get-range: ->
    return @value-range

  get-description: ->
    return if @description? then @description else "''"

  get-unit: ->
    return if @unit? then @unit else "''"

  get-annotations: (sensor-instance=null) ->
    return lodash_merge {}, @annotations unless sensor-instance?
    return lodash_merge {}, @annotations, sensor-instance.annotations


class SensorInstanceClass
  (@spec, @sensor-type, @verbose) ->
    {s_id, annotations} = spec
    {peripheral-type} = sensor-type
    @id = @s_id = id = s_id
    @annotations = annotations
    @annotations = {} unless @annotations?
    INFO "loading #{peripheral-type.name.cyan}/#{sensor-type.name.green}/#{id.magenta} => #{JSON.stringify annotations}" if verbose

  init: ->
    return

  get-id: ->
    return @s_id

  get-annotations: ->
    return @annotations


class SensorTypeClass
  (@spec, @peripheral-type, @verbose) ->
    {s_type, instances, fields, actions} = spec
    self = @
    self.name = name = s_type
    self.instances = instances
    xs = [ x.s_id.red for x in instances ]
    INFO "loading #{peripheral-type.name.cyan}/#{name.green} => #{xs.join ', '}" if verbose
    self.sensor-instances = [ (new SensorInstanceClass i, self, verbose) for i in instances ]
    self.field-types = [ (new FieldTypeClass f, self, verbose) for f in fields ]
    self.action-types = [ (new ActionTypeClass a, self, verbose) for a in actions ]

  init: ->
    {name, peripheral-type, sensor-instances, field-types, action-types, verbose} = self = @
    INFO "init #{peripheral-type.name}/#{name}" if verbose
    [ s.init! for s in sensor-instances ]
    [ f.init! for f in field-types ]
    [ a.init! for a in action-types ]

  get-sensor-ids: ->
    {sensor-instances} = @
    xs = [ (x.get-id!) for x in sensor-instances ]
    return xs

  get-field-types: ->
    return @field-types


class PeripheralTypeClass
  (@spec, @parser, @verbose) ->
    {p_type, p_type_parent, class_name, sensor_types} = spec
    self = @
    self.name = name = p_type
    self.parent-name = p_type_parent
    self.classname = class_name
    INFO "loading #{name.cyan}" if verbose
    self.sensor-types = [ (new SensorTypeClass s, self, verbose) for s in sensor_types ]
    self.sensor-type-names = [ s.name for s in self.sensor-types ]
    self.sensor-type-map = { [s.name, s] for s in self.sensor-types }
    self.children = []

  add-child: (p) ->
    self = @
    self.children.push p
    self.children = lodash_sortBy self.children, <[name]>

  init: ->
    {name, sensor-types, parser, parent-name, verbose} = self = @
    {p-type-map} = parser
    INFO "init #{name}" if verbose
    [ s.init! for s in sensor-types ]
    self.parent = parent = p-type-map[parent-name]
    return parent.add-child self if parent?
    return parser.set-root-class self if name is SchemaBaseClassName
    throw new Error "detect a class without parent class, but itself is not #{SchemaBaseClassName} => #{name}"

  get-sensor-type: (s_type) ->
    return @sensor-type-map[s_type]

  get-sensor-type-names: ->
    return @sensor-type-names



class Parser
  (@filename, @spec, @opts) ->
    {verbose} = opts
    self = @
    self.verbose = verbose
    return

  set-root-class: (@root) ->
    return

  load: ->
    {spec, filename, verbose} = self = @
    {content, manifest} = spec
    throw new Error "missing manifest field" unless manifest?
    throw new Error "missing content field" unless content?
    {checksum} = manifest
    throw new Error "missing checksum field, or type mismatch" unless checksum? and \string is typeof checksum
    buffer = new Buffer JSON.stringify content
    sha256 = crypto.createHash \sha256
    sha256.update buffer
    throw new Error "checksum verification failure" unless checksum is (sha256.digest \hex)
    {peripheral_types} = content
    INFO "parser: #{filename}, #{peripheral_types.length} peripheral types."
    self.manifest = manifest
    self.p-types = xs = [ (new PeripheralTypeClass pt, self, verbose) for pt in peripheral_types ]
    self.p-type-map = {[x.name, x] for x in xs}
    [ x.init! for x in xs ]
    {root} = self
    throw new Error "missing root class" unless root?
    root.level = 0
    self.p-types-ordered = [root]
    self.dfs-discovery root
    throw new Error "DFS discovery but number of elements is mismatched: #{xs.length} != #{self.p-types-ordered.length}" unless xs.length is self.p-types-ordered.length
    for p in self.p-types-ordered
      INFO "tree #{'    ' * p.level}#{p.name.cyan}"

  dfs-discovery: (p) ->
    {p-types-ordered} = self = @
    {children} = p
    for c in children
      p-types-ordered.push c
      c.level = p.level + 1
      self.dfs-discovery c

  get-peripheral-types: ->
    return @p-types-ordered

  get-peripheral-type: (p_type) ->
    return @p-type-map[p_type]


constants = {SchemaBaseClassName}
module.exports = exports = {Parser, constants}
