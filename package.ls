#!/usr/bin/env lsc -cj
#

# Known issue:
#   when executing the `package.ls` directly, there is always error
#   "/usr/bin/env: lsc -cj: No such file or directory", that is because `env`
#   doesn't allow space.
#
#   More details are discussed on StackOverflow:
#     http://stackoverflow.com/questions/3306518/cannot-pass-an-argument-to-python-with-usr-bin-env-python
#
#   The alternative solution is to add `envns` script to /usr/bin directory
#   to solve the _no space_ issue.
#
#   Or, you can simply type `lsc -cj package.ls` to generate `package.json`
#   quickly.
#

# package.json
#
name: \tic-data-toolkit

author:
  name: ['Yagamy']
  email: 'yagamy@gmail.com'
  url: 'https://github.com/yagamy4680'

description: 'Toolkits for data schema design and simulation for cloud (TIC) of TicTacToe'

version: \0.1.0

repository:
  type: \git
  url: ''

main: \lib/index.js

engines:
  node: \0.10.x
  npm: \1.4.x

dependencies:
  lodash: \*
  livescript: \*
  async: \*
  yargs: \*
  moment: \*
  esprima: \*
  marked: \*
  \marked-terminal : \*
  \js-yaml : \*

scripts:
  build: """
  echo "clean up lib directory ..."
  find ./lib -name '*.js' | xargs -I{} sh -c "rm -vf {}"
  ./node_modules/browserify/bin/cmd.js \\
      --node \\
      --extension=ls \\
      -t browserify-livescript \\
      --outfile lib/tic-data-toolkit.raw.js \\
      ./bin/cli.ls
  ./node_modules/uglify-es/bin/uglifyjs \\
      --compress \\
      --mangle \\
      --timings \\
      --verbose \\
      -o ./lib/tic-data-toolkit.js \\
      ./lib/tic-data-toolkit.raw.js \\
      2>&1 | perl -e '$| = 1; $f = "%-" . `tput cols` . "s\\r"; $f =~ s/\\n//; while (<>) {s/\\n//; printf $f, $_;} print "\\n"'
  """

devDependencies:
  \mermaid.cli : \*
  \browserify-livescript : \^0.2.3
  \uglify-es : \^3.3.9
  \browserify : \^16.2.2

optionalDependencies: {}
