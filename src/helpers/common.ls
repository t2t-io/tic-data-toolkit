require! <[fs]>
require! <[livescript]>


COMPILE_LIVESCRIPT = (fullpath, done) ->
  (err, buffer) <- fs.readFile fullpath
  return done err if err?
  text = buffer.toString!
  try
    javascript = livescript.compile text
    return done null, javascript
  catch error
    return done error



LOAD_LIVESCRIPT = (fullpath, done) ->
  (err, javascript) <- COMPILE_LIVESCRIPT fullpath
  return done err if err?
  try
    script = new vm.Script javascript
    sandbox = module: {}
    context = vm.createContext sandbox
    script.runInContext context
    return done null, sandbox.module.exports
  catch error
    return done error


module.exports = exports = {
  COMPILE_LIVESCRIPT,
  LOAD_LIVESCRIPT
}
