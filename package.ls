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

version: \0.0.1

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
  \yap-simple-logger : \yagamy4680/yap-simple-logger

scripts:
  build: """
  rm -vf ./lib/*.js;
  find src -name '*.ls' | xargs -I{} sh -c "echo compiling {} ...; cat {} | lsc -cp > lib/\\$(basename {} .ls).js"
  """

devDependencies:
  \mermaid.cli : \*

optionalDependencies: {}
