#
# Simple Logger
#
require! <[path]>

parse-filename = (filename) ->
  {app-dirname, app-filename, y-module-dir} = module
  ext-name = path.extname filename
  base-name = path.basename filename, ext-name
  return name: \__app__, basename: null if filename == app-filename
  if filename.starts-with app-dirname
    filename = filename.substring app-dirname.length
    tokens = filename.split path.sep
    if tokens.length == 2
      # E.g. /apps/sensor-web/test.ls    => name: '__test__'
      return name: "__#{base-name}__", basename: null
    else if tokens.length == 3
      # E.g. /apps/sensor-web/lib/xyz.ls => name: 'xyz'
      return name: base-name, basename: null
    else if tokens.length == 4
      # E.g. /apps/sensor-web/lib/def/good.ls => name: 'def', basename: 'good'
      return name: tokens[2], basename: base-name
    else
      # E.g. /apps/sensor-web/lib/foo/bar/great.ls => name: 'bar', basename: 'great'
      return name: "...#{tokens[tokens.length - 2]}", basename: base-name
  else
    if y-module-dir? and filename.starts-with y-module-dir
      filename = filename.substring y-module-dir.length
      tokens = filename.split path.sep
      # E.g. /externals/y-modules/sensorhub-client/lib/sensorhub-client.ls => name: 'sensorhub-client'
      return name: tokens[1], basename: null if tokens[1] == base-name
      # E.g. /externals/y-modules/yapps/lib/classes/web/index.ls => name: 'yapps', basename: 'web'
      return name: tokens[1], basename: tokens[tokens.length - 2] if \index == base-name
      # E.g. /externals/y-modules/sensorhub-client/lib/helper.ls => name: 'sensorhub-client', basename: 'helper'
      return name: tokens[1], basename: base-name
    else
      # E.g. /externals/yapps-plugins/communicator/lib/tcp.ls => name: 'communicator', basename: 'tcp'
      idx = filename.index-of '/yapps-plugins/'
      # E.g. /profiles/[xxx]/plugins/echonet-lite-service/index.ls => name: 'echonet-lite-service', basename: 'index'
      # E.g. /plugins/system-helpers/lib/regular-gc.ls             => name: 'system-helpers', basename: 'regular-gc'
      idx = filename.index-of '/plugins/' if idx < 0
      return name: "??", basename: base-name if idx < 0
      tokens = filename.substring idx .split path.sep
      return name: tokens[2], basename: base-name


class Driver
  (@module-name, @base-name) ->
    return


class ConsoleDriver extends Driver
  (@module-name, @base-name) ->
    @precise = process.env[\LOGGER_PRECISE_TIMESTAMP] is \true
    @timefmt = if @precise then 'MM/DD HH:mm:ss:SSS' else 'YYYY/MM/DD HH:mm:ss'
    return super module-name, base-name

  format-name: ->
    {paddings} = module
    {module-name, base-name} = @
    name = if base-name? and base-name != module-name then "#{module-name}::#{base-name}" else "#{module-name}"
    len = name.length
    padding = if len <= 28 then paddings[28 - len] else ""
    return "#{name}#{padding}"

  log: (lv, err, message) ->
    {timefmt} = self = @
    {levels, moment} = module
    name = @.format-name!
    msg = if message? then message else err
    level = levels[lv]
    now = moment! .format timefmt
    prefix = "#{now.gray} #{name} [#{level.string}]"
    if message?
      if err? and err.stack?
        console.error "#{prefix} #{err.stack}"
        console.error "#{prefix} #{msg}"
      else
        exx = "#{err}"
        console.error "#{prefix} err: #{exx.red} => #{msg}"
    else
      console.error "#{prefix} #{msg}"

  error: (err, message) -> return @.log \error, err, message
  info : (err, message) -> return @.log \info , err, message
  warn : (err, message) -> return @.log \warn , err, message
  debug: (err, message) -> return @.log \debug, err, message



class Logger
  (@module-name, @base-name, driver-class) ->
    @.set-driver-class driver-class
    return

  set-driver-class: (driver-class) ->
    @driver = new driver-class @module-name, @base-name

  debug: -> return @driver.debug.apply @driver, arguments unless global.argv?.v? and not global.argv.v
  info : -> return @driver.info.apply  @driver, arguments
  warn : -> return @driver.warn.apply  @driver, arguments
  error: -> return @driver.error.apply @driver, arguments


module.paddings = [""] ++ [ ([ ' ' for y from 1 to x ]).join '' for x from 1 to 28 ]
module.loggers = []
module.driver-class = ConsoleDriver


module.exports = exports =
  init: (app-filename, yap-filename, moment=null, colors=null) ->
    colors = require \colors unless colors?
    moment = require \moment unless moment?
    module.colors = colors
    module.moment = moment
    module.levels =
      info : {string: 'INFO'.green }
      debug: {string: 'DBG '.blue  }
      error: {string: 'ERR '.red   }
      warn : {string: 'WARN'.yellow}
    module.app-filename = app-filename
    module.app-dirname = path.dirname app-filename
    return unless yap-filename?
    tokens = yap-filename.split path.sep
    tokens.pop!
    tokens.pop!
    tokens.pop!
    module.y-module-dir = tokens.join path.sep
    console.error "y-module-dir = #{module.y-module-dir}" if process.env['VERBOSE'] is \true


  set-driver-class: (driver-class) ->
    console.error "set-driver-class"
    {loggers} = module
    [ l.set-driver-class driver-class for l in loggers ]
    module.driver-class = driver-class if driver-class?

  base-driver: Driver


global.get-logger = (filename) ->
  {driver-class, loggers} = module
  {name, basename} = parse-filename filename
  logger = new Logger name, basename, driver-class
  loggers.push logger
  get = (logger, level) -> return -> logger[level].apply logger, arguments
  DBG = get logger, \debug
  ERR = get logger, \error
  WARN = get logger, \warn
  INFO = get logger, \info
  return {DBG, ERR, WARN, INFO}
