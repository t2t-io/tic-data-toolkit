require! <[fs path lodash js-yaml]>

global.get-bundled-modules = ->
  lodash_merge = lodash.merge
  lodash_sortBy = lodash.sortBy
  return {lodash_merge, lodash_sortBy}

{Parser, constants} = require \./toe/ir-parser
{SchemaBaseClassName} = constants
{DBG, WARN, INFO, ERR} = global.get-logger __filename

const ROOT = \__ROOT__


class Loader extends Parser
  reset-output: (initials=[], spaces=2) ->
    initials = [] unless initials?
    @.output = initials
    @.spaces = spaces

  append-output: (line, ident=0) ->
    @.output.push "#{' ' * (ident * @spaces)}#{line}"

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

  to-spec: ->
    {p-types-ordered, manifest} = self = @
    text = js-yaml.safeDump {manifest}
    headers = text.split '\n'
    self.reset-output headers
    self.append-output "peripheral_types:"
    for p in p-types-ordered
      {sensor-types} = p
      continue unless sensor-types.length > 0
      self.append-output ""
      self.append-output "#{p.name}:", 1
      self.append-output "parent: #{if p.parent is self.root then ROOT else p.parent.name}", 2
      self.append-output "class_name: #{p.classname}", 2
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
