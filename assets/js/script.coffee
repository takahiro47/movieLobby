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

  showing: ->
    return $.ajax
      type: 'GET'
      url: "#{@domain}/list"
      dataType: 'html'

  coming: ->
    return $.ajax
      type: 'GET'
      url: "#{$api.domain}/coming"
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
# Backbone::Content
# ===================================

class Content extends Backbone.Model

  defaults:
    data:
      type: ''

class ContentView extends Backbone.View

  className: 'content-tile col-xs-6'

  template: _.template ($ '#tmpl-content').html()

  events: {}

  initialize: ->
    @$el.html @template @model.toJSON()

  render: ->
    @$el.attr 'data-id': @model.get 'id'
    @$el.css
      'background-image': "url(\"#{@model.get 'thumbnail'}\")"

    return @


# ===================================
# Backbone::Contents
# ===================================

class Contents extends Backbone.Collection

  model: Content

class ContentsView extends Backbone.View

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
    view = new ContentView(model: content).render()
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
    '': 'index'
    '/coming': 'coming'

  initialize: ->
    # ajaxにて認証状況を取得
    $.when($mw.showing(1))
      .done (data) =>
        @navigate location.pathname, yes
        Backbone.history.start pushState: on

        # ここではAPIサーバではなくMovieWalker.comから生HTMLデータを取得しているため，
        # この場でスクレイピングを行い，JSONPデータに変換しておく
        $movies = ($ data.results[0]).find '#main .onScreenBoxContentMovie'
        movies = _.map $movies, ($movie) ->
          release = ($ $movie).find('.movieDate dt').text().match(/^([0-9]+)月([0-9]+)日/)
          return movieData =
            id: ($ $movie).find('h3 a').attr('href').match(/\/mv([0-9]+)\//)[1]
            title: ($ $movie).find('h3 a').text()
            description: ($ $movie).find('.movieInfo p').text()
            thumbnail: ($ $movie).find('.moviePhoto img').attr 'src'
            release:
              month: release[1]
              date: release[2]
        $ =>
          media.contentsView = new ContentsView media.contents
          for movie in movies
            media.contents.add new Content movie

      .fail (err) =>
        console.log 'MovieWalker.comとの通信に失敗しました'
        Backbone.history.start pushState: on
        $ =>
          media.contentsView = new ContentsView media.contents

  index: ->
    @fetch_movie()

  fetch_movie: ->


media =
  contents: new Contents
  next: no
  query:
    page: 1


$app = new Application

