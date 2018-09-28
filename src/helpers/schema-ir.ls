require! <[fs path lodash js-yaml]>
{DBG, WARN, INFO, ERR} = global.get-logger __filename

const ROOT = \__ROOT__
const SchemaBaseClassName = \schema_base_class



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
    INFO "loading #{peripheral-type.name.cyan}/#{sensor-type.name.green}/#{name.yellow} => #{type}, [#{range.join ', '}], unit:#{unit}, #{if writeable then 'writable'}" if verbose

  init: ->
    return

  get-description: ->
    return if @description? then @description else "''"

  get-unit: ->
    return if @unit? then @unit else "''"



class SensorTypeClass
  (@spec, @peripheral-type, @verbose) ->
    {s_type, s_id_list, fields} = spec
    self = @
    self.name = name = s_type
    self.s_id_list = s_id_list
    xs = [ s.red for s in s_id_list ]
    INFO "loading #{peripheral-type.name.cyan}/#{name.green} => #{xs.join ', '}" if verbose
    self.field-types = [ (new FieldTypeClass f, self, verbose) for f in fields ]

  init: ->
    {name, peripheral-type, field-types, verbose} = self = @
    INFO "init #{peripheral-type.name}/#{name}" if verbose
    [ f.init! for f in field-types ]



class PeripheralTypeClass
  (@spec, @loader, @verbose) ->
    {p_type, p_type_parent, classname, sensor_types} = spec
    self = @
    self.name = name = p_type
    self.parent-name = p_type_parent
    self.classname = classname
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
    {peripheral_types} = spec
    INFO "loader: #{filename}, #{peripheral_types.length} peripheral types."
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
      for s in sensor-types
        {s_id_list} = s
        for i in s_id_list
          {field-types} = s
          for f in field-types
            xs = [p.name, s.name, i, f.name, f.writeable, f.value-type, f.value-unit]
            self.output.push xs
    xs = self.output
    xs = [ x.join ',' for x in xs ]
    xs = ["p_type,s_type,s_id,name,writable,type,unit"] ++ xs
    return xs.join "\n"

  reset-output: ->
    @.output = []

  append-output: (line, ident=0) ->
    @.output.push "#{'  ' * ident}#{line}"

  to-spec: ->
    {p-types-ordered} = self = @
    self.reset-output!
    for p in p-types-ordered
      {sensor-types} = p
      continue unless sensor-types.length > 0
      self.append-output "#{p.name}:"
      self.append-output "manifest:", 1
      self.append-output "parent: #{if p.parent is self.root then ROOT else p.parent.name}", 2
      self.append-output "sensors:", 1
      for s in sensor-types
        {s_id_list} = s
        for i in s_id_list
          {field-types} = s
          for f in field-types
            {value-type, value-unit, description, annotations} = f
            self.append-output "- path : #{s.name}/#{i}/#{f.name}", 2
            self.append-output "description: #{description}", 3 if description? and \string is typeof description and '' != description
            self.append-output "unit : #{value-unit}", 3 if value-unit? and \string is typeof value-unit and '' != value-unit
            if value-type in <[enum boolean]>
              self.append-output "value: [#{value-type}, [#{f.value-range.join ', '}]]", 3
            else if value-type in <[int float]>
              line = "value: [#{value-type}, [#{f.value-range.join ', '}]"
              line = if f.value-incremental? then "#{line}, #{f.value-incremental}]" else "#{line}]"
              self.append-output line, 3
            else
              self.append-output "# unsupported type: #{value-type}", 3
            xs = [ k for k, v of annotations ]
            continue unless xs.length > 0
            self.append-output "annotations: '#{JSON.stringify annotations}'", 3
            /*
            xs.sort!
            self.append-output "annotations:", 3
            for x in xs
              self.append-output "#{x}: '#{JSON.stringify annotations[x]}\'", 4
            */
      self.spec-actuator-output-flag = no
      for s in sensor-types
        {s_id_list} = s
        for i in s_id_list
          {field-types} = s
          writeable-field-types = [ f for f in field-types when f.writeable ]
          continue unless writeable-field-types.length > 0
          if not self.spec-actuator-output-flag
            self.spec-actuator-output-flag = yes
            self.append-output "actuators:", 1
          for f in writeable-field-types
            {value-type, value-unit, description, annotations} = f
            self.append-output "- path: #{s.name}/#{i}/set_#{f.name}", 2
            self.append-output "description: #{description}", 3 if description? and \string is typeof description and '' != description
            self.append-output "unit: #{value-unit}", 3 if value-unit? and \string is typeof value-unit and '' != value-unit
            if value-type in <[enum boolean]>
              self.append-output "arg : [#{value-type}, [#{f.value-range.join ', '}]]", 3
            else if value-type in <[int float]>
              line = "arg : [#{value-type}, [#{f.value-range.join ', '}]"
              line = if f.value-incremental? then "#{line}, #{f.value-incremental}]" else "#{line}]"
              self.append-output line, 3
            else
              self.append-output "# unsupported type: #{value-type}", 3
            xs = [ k for k, v of annotations ]
            continue unless xs.length > 0
            xs.sort!
            self.append-output "annotations: '#{JSON.stringify annotations}'", 3
            /*
            self.append-output "annotations:", 3
            for x in xs
              self.append-output "#{x}: #{annotations[x]}", 4
            */
    return self.output.join '\n'


module.exports = exports = {Loader}
