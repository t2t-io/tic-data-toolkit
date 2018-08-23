require! <[fs]>
require! <[livescript]>


COMPILE_LIVESCRIPT = (fullpath, done) ->
  (err, buffer) <- fs.readFile fullpath
  return done err if err?
  text = buffer.toString!
  try
    bare = yes
    javascript = livescript.compile text, {bare}
    return done null, javascript
  catch error
    return done error


module.exports = exports = {
  COMPILE_LIVESCRIPT
}
