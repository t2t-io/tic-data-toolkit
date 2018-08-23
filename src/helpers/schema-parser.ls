require! <[vm]>
require! <[lodash esprima livescript async marked]>
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




class Collection
  (@name, @opts) ->
    @objects = []
    @object-map = {}
    return

  add: (o) ->
    {name} = o
    @objects.push o
    @object-map[name] = o
    return o

  add-objects: (objects) ->
    self = @
    [ self.add o for o in objects ]
    return self

  get-objects: ->
    return @objects

  get-object-as-dict: ->
    return @object-map

  apply-object-func: (func-name, done) ->
    {objects} = self = @
    f = (o, cb) ->
      func = o[func-name]
      return cb "missing function #{func-name}" unless func?
      return cb "missing function #{func} with correct type" unless \function is typeof func
      return func.apply o, [cb]
    return async.eachSeries objects, f, done





class AttributeField
  (@parent) ->
    return


class Attribute
  # name => `power_consumption`
  # id   => `00`
  (@parent, @name, @id, @settings) ->
    # INFO "attribute/constructor => #{name}/#{id} => #{JSON.stringify settings}"
    @fields = []
    @field-map = {}

  init: (done) ->
    {name, id, settings} = self = @
    INFO "#{name}/#{id} => #{JSON.stringify settings}"
    return done!


class AttributeCollection
  (@parent, @attribute-name) ->
    @attributes = []
    @attribute-map = {}

  init: (done) ->
    {attribute-name, attributes, parent} = self = @
    {name} = parent
    f = (a, cb) ->
      # INFO "#{name}/#{attribute-name}: initialize attribute #{a?}"
      INFO "#{name}/#{attribute-name}: initialize attribute #{a.name}/#{a.id}"
      return a.init cb
    INFO "#{name}/#{attribute-name} init #{attributes.length} attributes ..."
    return async.eachSeries attributes, f, done

  add-attribute: (attr-name, id, settings) ->
    {attribute-name, attributes, attribute-map} = self = @
    return WARN "unexpected attribute missing _name_ is added to collection for #{attribute-name}" unless attr-name?
    return WARN "unexpected attribute missing __id__ is added to collection for #{attribute-name}" unless id?
    return WARN "unexpected attribute #{attr-name}/#{id} is added to collection for #{attribute-name}" unless attr-name is attribute-name
    x = attribute-map[id]
    return WARN "unexpected attribute #{attr-name}/#{id} was existed in the collection for #{attribute-name}" if x?
    attr = new Attribute self, attr-name, id, settings
    self.attributes.push attr
    self.attribute-map[id] = attr
    return attr


class PeripheralType
  (@clazz, @parser) ->
    {displayName} = clazz
    @class_name = displayName
    @name = lodash.snakeCase displayName

    @collections = {}
    INFO "load #{@name}/#{@class_name} ..."
    return

  init: (done) ->
    {clazz} = self = @
    self.ref = ref = new clazz!
    # self.attributes = attributes = ref.attributes
    for name, identities of ref.attributes
      settings = ref[name]
      for id in identities
        # INFO "#{self.name}: #{name}/#{id} => #{JSON.stringify settings}"
        ac = self.collections[name]
        ac = new AttributeCollection self, name unless ac?
        ac.add-attribute name, id, settings
        self.collections[name] = ac
      # INFO "#{name}: #{k}/#{v} => #{JSON.stringify ref[k]}"
    attrs = [ a for name, a of self.collections ]
    f = (ac, cb) -> return ac.init cb
    return async.eachSeries attrs, f, done


class PeripheralType
  (@parser, @verbose, @clazz) ->
    return



class SchemaBaseClass
  ->
    @hello = {}
    @attributes = {}



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
    highlighted = HIGHLIGHT_JAVASCRIPT modified
    javascript = modified
    return {javascript, highlighted}

    /*
    types = [ (new PeripheralType clazz, self) for name, clazz of schema ]
    self.peripheral-types = (new Collection \peripheral-type, {verbose}).add-objects types
    self.peripheral-types.apply-object-func \init, done
    */

module.exports = exports = {SchemaParser}
