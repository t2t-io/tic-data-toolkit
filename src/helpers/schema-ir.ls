require! <[fs path lodash js-yaml]>
{DBG, WARN, INFO, ERR} = global.get-logger __filename

const ROOT = \__ROOT__
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
    return lodash.merge {}, @annotations unless sensor-instance?
    return lodash.merge {}, @annotations, sensor-instance.annotations


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

  get-description: ->
    return if @description? then @description else "''"

  get-unit: ->
    return if @unit? then @unit else "''"

  get-annotations: (sensor-instance=null) ->
    return lodash.merge {}, @annotations unless sensor-instance?
    return lodash.merge {}, @annotations, sensor-instance.annotations


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



class PeripheralTypeClass
  (@spec, @loader, @verbose) ->
    {p_type, p_type_parent, class_name, sensor_types} = spec
    self = @
    self.name = name = p_type
    self.parent-name = p_type_parent
    self.classname = class_name
    INFO "loading #{name.cyan}" if verbose
    self.sensor-types = [ (new SensorTypeClass s, self, verbose) for s in sensor_types ]
    self.children = []

  add-child: (p) ->
    self = @
    self.children.push p
    self.children = lodash.sortBy self.children, <[name]>

  init: ->
    {name, sensor-types, loader, parent-name, verbose} = self = @
    {p-type-map} = loader
    INFO "init #{name}" if verbose
    [ s.init! for s in sensor-types ]
    self.parent = parent = p-type-map[parent-name]
    return parent.add-child self if parent?
    return loader.set-root-class self if name is \schema_base_class
    throw new Error "detect a class without parent class, but itself is not schema_base_class => #{name}"



class Loader
  (@filename, @spec, @opts) ->
    {verbose} = opts
    self = @
    self.verbose = verbose
    return

  set-root-class: (@root) ->
    return

  load: ->
    {spec, filename, verbose} = self = @
    {peripheral_types, manifest} = spec
    INFO "loader: #{filename}, #{peripheral_types.length} peripheral types."
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

  to-csv: ->
    {p-types-ordered} = self = @
    self.output = []
    for p in p-types-ordered
      {sensor-types} = p
      for st in sensor-types
        {sensor-instances} = st
        for si in sensor-instances
          {field-types} = st
          for ft in field-types
            xs = [p.name, st.name, si.id, ft.name, ft.writeable, ft.value-type, ft.value-unit]
            self.output.push xs
    xs = self.output
    xs = [ x.join ',' for x in xs ]
    xs = ["p_type,s_type,s_id,name,writable,type,unit"] ++ xs
    return xs.join "\n"

  reset-output: (initials=[], spaces=2) ->
    initials = [] unless initials?
    @.output = initials
    @.spaces = spaces

  append-output: (line, ident=0) ->
    @.output.push "#{' ' * (ident * @spaces)}#{line}"

  to-spec: ->
    {p-types-ordered, manifest} = self = @
    text = js-yaml.safeDump {manifest}
    headers = text.split '\n'
    self.reset-output headers
    self.append-output "peripheral_types:"
    for p in p-types-ordered
      {sensor-types} = p
      continue unless sensor-types.length > 0
      self.append-output "#{p.name}:", 1
      self.append-output "p_type: #{p.name}", 2
      self.append-output "p_type_parent: #{if p.parent is self.root then ROOT else p.parent.name}", 2
      self.append-output "sensors:", 2
      for st in sensor-types
        {sensor-instances} = st
        for si in sensor-instances
          {field-types} = st
          for ft in field-types
            {value-type, value-unit, writeable, description} = ft
            self.append-output "- path : #{st.name}/#{si.id}/#{ft.name}", 3
            self.append-output "unit : '#{value-unit}'", 4 if value-unit? and \string is typeof value-unit and '' != value-unit
            self.append-output "writeable : #{writeable}", 4
            self.append-output "description: '#{description}'", 4 if description? and \string is typeof description and '' != description
            if value-type in <[enum boolean]>
              self.append-output "value: [#{value-type}, [#{ft.value-range.join ', '}]]", 4
            else if value-type in <[int float]>
              line = "value: [#{value-type}, [#{ft.value-range.join ', '}]"
              line = if ft.value-incremental? then "#{line}, #{ft.value-incremental}]" else "#{line}]"
              self.append-output line, 4
            else
              self.append-output "# unsupported type: #{value-type}", 4
            annotations = ft.get-annotations si
            xs = [ k for k, v of annotations ]
            continue unless xs.length > 0
            self.append-output "annotations: '#{JSON.stringify annotations}'", 4
      self.spec-actuator-output-flag = no
      for st in sensor-types
        {sensor-instances} = st
        for si in sensor-instances
          {action-types} = st
          continue unless action-types.length > 0
          if not self.spec-actuator-output-flag
            self.spec-actuator-output-flag = yes
            self.append-output "actuators:", 2
          for at in action-types
            {argument-type, argument-unit, description} = at
            self.append-output "- path: #{st.name}/#{si.id}/#{at.name}", 3
            self.append-output "unit: '#{argument-unit}'", 4 if argument-unit? and \string is typeof argument-unit and '' != argument-unit
            self.append-output "description: '#{description}'", 4 if description? and \string is typeof description and '' != description
            if argument-type in <[enum boolean]>
              self.append-output "arg : [#{argument-type}, [#{at.argument-range.join ', '}]]", 4
            else if argument-type in <[int float]>
              line = "arg : [#{argument-type}, [#{at.argument-range.join ', '}]"
              line = if at.argument-incremental? then "#{line}, #{at.argument-incremental}]" else "#{line}]"
              self.append-output line, 4
            else
              self.append-output "# unsupported type: #{argument-type}", 4
            annotations = at.get-annotations si
            xs = [ k for k, v of annotations ]
            continue unless xs.length > 0
            xs.sort!
            self.append-output "annotations: '#{JSON.stringify annotations}'", 4
    return self.output.join '\n'

  to-class-lr-diagram: ->
    {p-types-ordered} = self = @
    self.reset-output [], 4
    self.append-output "graph LR"
    for pt in p-types-ordered
      {name, parent-name} = pt
      continue if name is SchemaBaseClassName
      parent = if parent-name is SchemaBaseClassName then 'ROOT' else parent-name
      self.append-output "#{name} --> #{parent}", 1
    return self.output.join '\n'

  to-class-diagram: ->
    {p-types-ordered} = self = @
    self.reset-output [], 4
    self.append-output "classDiagram"
    for pt in p-types-ordered
      {name, classname, parent-name, parent} = pt
      continue if name is SchemaBaseClassName
      parent = if parent-name is SchemaBaseClassName then 'ROOT' else parent.classname
      self.append-output "#{parent} <|-- #{classname}"
    for pt in p-types-ordered
      {name, classname, sensor-types} = pt
      continue if name is SchemaBaseClassName
      for st in sensor-types
        self.append-output "#{classname} : #{st.name}"
      /*
      for st in sensor-types
        {field-types} = st
        for ft in field-types
          self.append-output "#{classname} : #{ft.value-type} #{st.name}/#{ft.name}"
      */
    return self.output.join '\n'

  to-mermaid-digrams: ->
    class-lr = @.to-class-lr-diagram!
    class-std = @.to-class-diagram!
    return {class-lr, class-std}


module.exports = exports = {Loader}
