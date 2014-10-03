fs = require 'fs'
url = require 'url'
path = require 'path'

args = [].concat process.argv
while arg = args.shift()
  switch arg
    when '-p', '--port'
      PORT = parseInt args.shift()
    when '-m', '--mode'
      MODE = args.shift()
      MODE = if MODE is 'dev' then 'dist' else 'public'
    when '-i', '--index'
      INDEX = args.shift()
      INDEX = INDEX.slice 1 while '/' is INDEX.slice 0, 1
    when '-h', '--help'
      console.log '''
        Usage: grunt [options]

        Options:
          -p, --port  [INT]  server port (3000)
          -m, --mode  [STR]  "dev" or "pro" (dev)
          -i, --index [STR]  fallback file (index.html)
          -h, --help         show this message and exit

        Example:
          grunt -p 3000 -m dev -i index.html

        Tasks:
          Build:
            coffee, stylus, jade
          Lint:
            jshint, csslint
          Minify:
            uglify, cssmin
          Server:
            connect, watch
          Phony:
            default - launch server after build
            build   - execute all tasks without server
        '''
      process.exit 1

mountFolder = (connect, dir) ->
  connect.static require('path').resolve(dir)

module.exports = (grunt) ->
  'use strict'

  require 'coffee-script'
  require 'coffee-errors'

  # Load grunt tasks automatically

  require('load-grunt-tasks') grunt,
    scope: 'devDependencies'

  # Time how long tasks take. Can help when optimizing build times

  require('time-grunt') grunt


  ## Tasks

  grunt.registerTask 'serve', (target) ->
    if target is 'dist'
      return grunt.task.run [ 'build', 'connect:dist:keepalive', ]
    grunt.task.run [ 'test', 'connect:livereload', 'watch' ]
    return
  grunt.registerTask 'server', ->
    grunt.log.warn 'The `server` task has been deprecated. Use `grunt serve` to start a server.'
    grunt.task.run ['serve']
    return
  grunt.registerTask 'build', [ 'clean', 'copy', 'coffee', 'uglify', 'stylus', 'cssmin', 'jade', 'imagemin', 'svgmin', 'htmlmin' ]
  grunt.registerTask 'test',  [ 'coffeelint', 'build', 'csslint', 'simplemocha', 'play' ]
  grunt.registerTask 'default', [ 'serve' ]


  ## Config

  grunt.option 'force', yes

  grunt.initConfig

    picha:
      dist: 'dist/'
      public: 'public/'

    pkg: grunt.file.readJSON 'package.json'
    hash: fs.readFileSync('.git/FETCH_HEAD', 'utf-8').trim().split(' ').shift().slice(0, 7)

    watch:
      options:
        spawn: no
        interrupt: yes
        livereload: yes
        dateFormat: (time) ->
          grunt.log.writeln "The watch finished in #{time}ms at #{new Date().toLocaleTimeString()}"
      coffee:
        files: [ 'assets/**/*.coffee']
        tasks: [ 'coffeelint', 'coffee', 'uglify', 'jade:compile' ]
      jade:
        files: [ 'assets/**/*.jade' ]
        tasks: [ 'jade' ]
      stylus:
        files: [ 'assets/**/*.styl']
        tasks: [ 'stylus', 'cssmin' ] # 'csslint'
      gruntfile:
        files: [ 'Gruntfile.coffee' ]
        tasks: [ 'test' ]
      livereload:
        options:
          livereload: '<%= connect.options.livereload %>'
        files: [ 'assets/images/{,*/}*.{png,jpg,jpeg,gif,webp,svg}' ]
        tasks: [ 'test' ]

    # The actual grunt server settings
    connect:
      options:
        port: 4000
        hostname: 'localhost' # Change this to '0.0.0.0' to access the server from outside.
        livereload: 35729
      livereload:
        options:
          middleware: (connect, options) ->
            mw = [connect.logger 'dev']
            mw.push (req, res) ->
              route = path.resolve MODE, (url.parse req.url).pathname.replace /^\//, ''
              fs.exists route, (exist) ->
                fs.stat route, (err, stat) ->
                  return fs.createReadStream(route).pipe(res) if exist and stat.isFile()
                  return fs.createReadStream(index).pipe(res)
            return mw
          open: no
          livereload: yes
          base: '.'
      dist:
        options:
          base: 'dist/'

    clean:
      dist:
        src: [ 'dist/' ]
      public:
        src: [ 'public/', '*.html' ]

    bower:
      install:
        options:
          targetDir: './lib',
          layout: (type, component) ->
            if type is 'css'
              return 'css'
            else
              return 'js'
          install: yes
          verbose: no
          cleanTargetDir: yes
          cleanBowerDir: no

    copy:
      img:
        files: [{
          expand: yes
          cwd: 'assets/'
          src: [ '**/*.{jpg,png,gif}' ]
          dest: 'dist/'
        }]
      js:
        files: [{
          expand: yes
          cwd: 'assets/'
          src: [ '**/*.js' ]
          dest: 'dist/'
        }]
      css:
        files: [{
          expand: yes
          cwd: 'assets/'
          src: [ '**/*.css' ]
          dest: 'dist/'
        }]
      font:
        files: [{
          expand: yes
          cwd: 'assets/'
          src: [ '**/*.{eot,svg,ttf,otf,woff}' ]
          dest: 'public/'
        }]
      source:
        files: [{
          expand: yes
          cwd: 'assets/'
          src: [ '**/*.coffee' ]
          dest: 'dist/'
        }]

    coffeelint:
      options:
        max_line_length:
          value: 319 # 79
        indentation:
          value: 2
        newlines_after_classes:
          level: 'error'
        no_empty_param_list:
          level: 'error'
        no_unnecessary_fat_arrows:
          level: 'ignore'
      dist:
        files: [
          { expand: yes, cwd: 'assets/', src: [ '**/*.coffee' ] }
          { expand: yes, cwd: 'config/', src: [ '**/*.coffee' ] }
          { expand: yes, cwd: 'events/', src: [ '**/*.coffee' ] }
          { expand: yes, cwd: 'helper/', src: [ '**/*.coffee' ] }
          { expand: yes, cwd: 'models/', src: [ '**/*.coffee' ] }
          { expand: yes, cwd: 'tests/', src: [ '**/*.coffee' ] }
        ]

    csslint:
      options:
        csslintrc: '.csslintrc'
      strict:
        options:
          import: 2
        src: 'dist/**/*.css'

    coffee:
      options:
        sourceMap: yes
        sourceRoot: ''
        bare: yes
        #> Angular.jsによってglobal空間でオブジェクトを使いまわす
        separator: 'linefeed'
      compile:
        files: [{
          expand: yes
          cwd: 'assets/'
          src: [ '*.coffee', '**/*.coffee' ]
          dest: 'dist/'
          ext: '.js'
        }]

    stylus:
      options:
        compress: no
        urlfunc: 'embedurl'
      compile:
        files: [{
          expand: yes
          cwd: 'assets/'
          src: [ 'style.styl', '**/style.styl' ] # [ '*.styl', '**/*.styl' ]
          dest: 'dist/'
          ext: '.css'
        }]

    jade:
      debug:
        options:
          pretty: yes
          data:
            version: '<%- pkg.version %>'
            timestamp: "<%= new Date().getTime() %>"
        files: [{
          expand: yes
          cwd: 'assets/views'
          src: [ '*.jade', '**/*.jade' ]
          dest: 'dist/'
          ext: '.html'
        }]
      compile:
        options:
          pretty: no
          data:
            version: '<%- pkg.version %>'
            timestamp: "<%= new Date().getTime() %>"
        files: [{
          expand: yes
          cwd: 'assets/views'
          src: [ '!(_)*.jade', '**/!(_)*.jade' ]
          dest: ''
          ext: '.html'
        }]

    uglify:
      dist:
        options:
          mangle: on
        files: [{
          expand: yes
          cwd: 'dist/'
          src: [ '*.js', '**/*.js' ]
          dest: 'public/'
          ext: '.js'
        }]

    cssmin:
      dist:
        files: [{
          expand: yes
          cwd: 'dist/'
          src: [ '*.css', '**/*.css' ]
          dest: 'public/'
          ext: '.css'
        }]

    imagemin:
      dist:
        files: [{
          expand: yes
          cwd: 'dist/'
          src: [ '*.{jpg,png,gif}', '**/*.{jpg,png,gif}' ]
          dest: 'public/'
        }]

    svgmin:
      dist:
        files: [
          expand: yes
          cwd: 'dist/'
          src: [ '{,*/}*.svg', '!{fonts,font}/*.svg' ]
          dest: 'public/'
        ]

    htmlmin:
      dist:
        options:
          collapseWhitespace: yes
          collapseBooleanAttributes: yes
          removeCommentsFromCDATA: yes
          removeOptionalTags: yes
        files: [
          expand: yes
          cwd: 'views/'
          src: [ '*.{html}', '**/*.{html}' ]
          dest: 'public/'
        ]

    simplemocha:
      options:
        ui: 'bdd'
        reporter: 'spec'
        compilers: 'coffee:coffee-script'
        ignoreLeaks: no
      dist:
        src: [ 'tests/test.coffee' ]

    play:
      fanfare:
        # file: 'node_modules/grunt-play/sounds/fanfare.mp3'
        file: 'assets/sounds/ta_ta_pi01.mp3'





