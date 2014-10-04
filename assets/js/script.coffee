'use strict'

# ===================================
# Globals
# ===================================

$win  = $ window
$doc  = $ document
$body = $ 'body'
$all  = $ 'html body'


# ===================================
# Fake Cross domain ajax
# ===================================

jQuery.ajax = ((_ajax) ->
  isExternal = (url) ->
    not exRegex.test(url) and /:\/\//.test(url)
  protocol = location.protocol
  hostname = location.hostname
  exRegex = RegExp(protocol + "//" + hostname)
  YQL = "http" + ((if /^https/.test(protocol) then "s" else "")) + "://query.yahooapis.com/v1/public/yql?callback=?"
  query = "select * from html where url=\"{URL}\" and xpath=\"*\""
  (o) ->
    url = o.url
    if /get/i.test(o.type) and not /json/i.test(o.dataType) and isExternal(url)

      # Manipulate options so that JSONP-x request is made to YQL
      o.url = YQL
      o.dataType = "json"
      o.data =
        q: query.replace("{URL}", url + ((if o.data then ((if /\?/.test(url) then "&" else "?")) + jQuery.param(o.data) else "")))
        format: "xml"

      # Since it's a JSONP request
      # complete === success
      if not o.success and o.complete
        o.success = o.complete
        delete o.complete
      o.success = ((_success) ->
        (data) ->
          if _success
            # Fake XHR callback.
            _success.call @,
              # YQL screws with <script>s
              # Get rid of them
              responseText: (data.results[0] or "").replace(/<script[^>]+?\/>|<script(.|\s)*?\/script>/g, "")
            , "success"
          return
      )(o.success)
    _ajax.apply this, arguments
)(jQuery.ajax)


# ===================================
# API
# ===================================

# API Server
$api =
  domain: "//#{($ '#data').data 'domain'}/api"

  account: ->
    return $.ajax "#{@domain}/account/me.json",
      type: 'GET'
      dataType: 'jsonp'

# Movie Walker
$mw =
  domain: 'http://movie.walkerplus.com'

  showing: (page = 1) ->
    return $.ajax
      type: 'GET'
      url: "#{@domain}/list/#{page}.html"
      dataType: 'html'

  coming: ->
    return $.ajax
      type: 'GET'
      url: "#{@domain}/list/coming/"
      dataType: 'html'

  detail: (id) ->
    return $.ajax
      type: 'GET'
      url: "#{@domain}/mv#{id}/"
      dataType: 'html'


# ===================================
# LocalStorage
# ===================================

storage =

  get: (key) ->
    if window.localStorage?
      return window.localStorage.getItem key
    return no

  set: (key, val) ->
    if window.localStorage?
      return window.localStorage.setItem key, val
    return no


# ===================================
# Backbone::MovieListContent
# ===================================

class MovieListContent extends Backbone.Model

class MovieListContentView extends Backbone.View

  className: 'content-tile type-list col-xs-6'

  template: _.template ($ '#tmpl-list-content').html()

  events:
    'click .js-navigate-single': 'navigateSingle'

  initialize: ->
    @$el.html @template @model.toJSON()

  render: ->
    @$el.attr 'data-id': @model.get 'id'

    # サムネイルを設定
    @$el.css
      'background-image': "url(\"#{@model.get 'thumbnail'}\")"

    # リリース日が明日であれば公開日ではなく『明日公開』と表示する
    now = new Date()
    release = @model.get 'release'
    if release.month is now.getMonth()+1 and release.date is now.getDate()
      (@$ '.release-date').text "明日公開"
    else
      (@$ '.release-date').text "#{release.month}/#{release.date}〜"

    return @

  navigateSingle: ->
    $app.navigate "movie.html?id=#{@model.get 'id'}", yes


# ===================================
# Backbone::MovieSingleContent
# ===================================

class MovieSingleContent extends Backbone.Model

class MovieSingleContentView extends Backbone.View

  className: 'content-tile type-single'

  template: _.template ($ '#tmpl-single-content').html()

  events: {}

  initialize: ->
    @$el.html @template @model.toJSON()

  render: ->
    @$el.attr 'data-id': @model.get 'id'

    # # サムネイルを設定
    # @$el.css
    #   'background-image': "url(\"#{@model.get 'thumbnail'}\")"

    # リリース日が明日であれば公開日ではなく『明日公開』と表示する
    # now = new Date()
    # release = @model.get 'release'
    # if release.month is now.getMonth()+1 and release.date is now.getDate()
    #   (@$ '.release-date').text "明日公開"
    # else
    #   (@$ '.release-date').text "#{release.month}/#{release.date}〜"

    return @


# ===================================
# Backbone::Contents
# ===================================

class MovieListContents extends Backbone.Collection

  model: MovieListContent

class MovieListContentsView extends Backbone.View

  el: $ '#content'

  template: _.template ($ '#tmpl-contents').html()

  events: {}

  initialize: (@collection) ->
    @$el.html @template()
    @listenTo @collection, 'reset', @clear
    @listenTo @collection, 'add', @append
    @render()

  render: ->
    return @

  clear: ->
    (@$ '.content-tiles').empty()

  append: (content) ->
    if content.get('type') is 'list'
      view = new MovieListContentView(model: content).render()
      (@$ ".content-tiles").append view.el
    else
      view = new MovieSingleContentView(model: content).render()
      (@$ ".content-tiles").append view.el


# ===================================
# Backbone::Application
# ===================================

class Application extends Backbone.Router

  # el
  $title: $ 'title'
  $search: null

  # state
  fetching: no

  routes:
    '(?page=:page)': 'index'
    'index.html(?page=:page)': 'index'
    'coming.html': 'coming'
    'movie.html?id=(:id)': 'movie_detail'

  initialize: ->
    @navigate location.pathname, yes
    Backbone.history.start pushState: on, root: '/movieLobby'
    $ =>
      media.movieListContentsView = new MovieListContentsView media.movieListContents

  index: (page) ->
    console.log '映画一覧(公開中)ページ'
    # ページが設定されていなければ1ページ目と判定する

    # 映画一覧データを取得
    $.when( $mw.showing( page ) )
      .done (data) =>
        # ここではAPIサーバではなくMovieWalker.comから生HTMLデータを取得しているため，
        # この場でスクレイピングを行い，JSONPデータに変換しておく
        $movies = ($ data.results[0]).find '#main .onScreenBoxContentMovie'
        movies = _.map $movies, ($movie) ->
          release = ($ $movie).find('.movieDate dt').text().match(/^([0-9]+)月([0-9]+)日/)
          return movieData =
            type: 'list'
            id: ($ $movie).find('h3 a').attr('href').match(/\/mv([0-9]+)\//)[1]
            title: ($ $movie).find('h3 a').text()
            description: ($ $movie).find('.movieInfo p').text()
            thumbnail: ($ $movie).find('.moviePhoto img').attr 'src'
            release:
              month: release[1]
              date: release[2]
        console.log "#{movies.length}件の映画データを取得完了"

        # 映画アイテムを画面に追加
        media.movieListContents.reset()
        for movie in media.movies = movies
          media.movieListContents.add new MovieListContent movie

        # ナビのタイトルを書き換え
        ($ '.nav__title h1').text '公開中'

      .fail (err) =>
        console.log 'MovieWalker.comとの通信に失敗しました'


  showing: (page) ->


  coming: ->
    console.log '映画一覧(近日公開)ページ'
    # 映画一覧データを取得
    $.when( $mw.coming() )
      .done (data) =>
        # ここではAPIサーバではなくMovieWalker.comから生HTMLデータを取得しているため，
        # この場でスクレイピングを行い，JSONPデータに変換しておく
        $movies = ($ data.results[0]).find '#comingMovieList .movie'
        movies = _.map $movies, ($movie) ->
          release = ($ $movie).find('.publishDate p').text().match(/^([0-9]+)月([0-9]+)日/)
          wanted = ($ $movie).find('.publishDate a span').text().match(/^([0-9]+)人/)
          return movieData =
            type: 'list'
            id: ($ $movie).find('h3 a').attr('href').match(/\/mv([0-9]+)\//)[1]
            title: ($ $movie).find('h3 a').text()
            description: ($ $movie).find('.movieInfo p').text()
            thumbnail: ($ $movie).find('.movieInner img').attr 'src'
            wanted: if wanted then wanted[1] else 0
            release:
              month: release[1]
              date: release[2]
        console.log "#{movies.length}件の映画データを取得完了", movies

        # 映画アイテムを画面に追加
        media.movieListContents.reset()
        for movie in media.movies = movies
          media.movieListContents.add new MovieListContent movie

        # ナビのタイトルを書き換え
        ($ '.nav__title h1').text '近日公開'

      .fail (err) =>
        console.log 'MovieWalker.comとの通信に失敗しました'


  movie_detail: (id) ->
    console.log "映画詳細ページ id=#{id}"
    $.when( $mw.detail( id ) )
      .done (data) =>
        # ここではAPIサーバではなくMovieWalker.comから生HTMLデータを取得しているため，
        # この場でスクレイピングを行い，JSONPデータに変換しておく
        $movie = ($ data.results[0]).find '#main'
        release = ($ $movie).find('#publishDate p').text().match(/^([0-9]+)月([0-9]+)日/)
        movie =
          type: 'single'
          id: id
          title: ($ $movie).find('#pageHeader h1 a').text()
          description: ($ $movie).find('#mainInfo p').text()
          thumbnail: ($ $movie).find('#mainImage img').attr 'src'
          wanted: ($ $movie).find('#mitai_text2').text()
          release:
            month: release[1]
            date: release[2]
        console.log "id=#{id}の映画データを取得完了", movie

        # 映画アイテムを画面に追加
        media.movieListContents.reset()
        media.movieListContents.add new MovieListContent movie

        # ナビのタイトルを書き換え
        ($ '.nav__title h1').text movie.title

      .fail (err) =>
        console.log 'MovieWalker.comとの通信に失敗しました'


media =
  movieListContents: new MovieListContents
  next: no
  query:
    current: null
    page: 1


$app = new Application

