global.marp or=
  config: require './classes/mds_config'
  development: false

{app}     = require 'electron'
Path      = require 'path'
MdsWindow = require './classes/mds_window'
MainMenu  = require './classes/mds_main_menu'
{exist}   = require './classes/mds_file'

# app root dir
appBaseDir = Path.dirname(__dirname)

# Initialize config
global.marp.config.initialize()

# Parse arguments
opts =
  file: null

for arg in process.argv.slice(1)
  break_arg = false
  switch arg
    when '--development', '--dev'
      global.marp.development = true
    else
      if exist(resolved_file = Path.resolve(arg))
        opts.file = resolved_file
        break_arg = true

  break if break_arg

# Application events
app.on 'window-all-closed', ->
  if process.platform != 'darwin' or !!MdsWindow.appWillQuit
    global.marp.config.save()
    app.quit()

app.on 'before-quit', ->
  MdsWindow.appWillQuit = true

app.on 'activate', (e, hasVisibleWindows) ->
  new MdsWindow if app.isReady() and not hasVisibleWindows

app.on 'open-file', (e, path) ->
  e.preventDefault()
  opts.fileOpened = true
  MdsWindow.loadFromFile path, null

app.on 'ready', ->
  global.marp.mainMenu = new MainMenu
    development: global.marp.development

  unless opts.fileOpened
    if opts.file
      MdsWindow.loadFromFile opts.file, null
    else
      new MdsWindow

if global.marp.development
  chokidar = require 'chokidar'
  browserWindows = []

  # https://github.com/yan-foto/electron-reload/blob/master/main.js
  app.on 'browser-window-created', (e, bw) ->
    browserWindows.push bw

    # Remove closed windows from list of maintained items
    bw.on 'closed', () ->
      i = browserWindows.indexOf bw
      browserWindows.splice(i, 1)

  ###
  # Callback function to be executed when any of the files
  # defined in given 'glob' is changed.
  ###
  onChange = (args...) ->
    browserWindows.forEach (bw) ->
      bw.webContents.reloadIgnoringCache()

  # Watch everything but the node_modules folder and main file
  # main file changes are only effective if hard reset is possible
  opts = Object.assign({
    ignored: [
      /node_modules|[/\\]\./
    ]})

  watcher = chokidar.watch Path.resolve(appBaseDir, 'js'), opts
  watcher.on('change', onChange)
