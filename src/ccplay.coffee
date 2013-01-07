"use strict"


# Utilities

getQueryParameter = _.memoize (name) ->
  re = new RegExp("[?&]#{name}=([^&]+)")
  match = re.exec(window.location.search)
  if match
    decodeURIComponent(match[1].replace('+', ' '))
  else
    null

proxyUrl = (url) ->
  "proxy.php?url=#{encodeURIComponent(url)}"

# Loading code

hideReward = -> $(".reward").addClass("hidden")
showReward = -> $(".reward").removeClass("hidden")

showLoading = -> $("#loading").css("opacity", "1")
hideLoading = -> $("#loading").css("opacity", "0")

showPuzzle = -> $("#main").css("opacity", "1").css("visibility", "visible")

page =
  init: ->
    @decade = +getQueryParameter("decade")
    @id = +getQueryParameter("id")

  loadDataDeferred: ->
    dataUrlParts = ["image.php"]
    if @decade
      dataUrlParts.push($.param(decade: @decade))
    else if @id
      dataUrlParts.push($.param(id: @id))
    $.getJSON(dataUrlParts.join("?"))

  renderTemplate: (data) ->
    template = $("#mainTemplate").html()
    $("#main").html(_.template(template, data))

  loadArticleDeferred: (link) ->
    title = _.last(link.split("wiki/"))
    articleUrl = "http://de.wikipedia.org/w/api.php?format=json&action=parse&prop=text&page=#{title}"
    $.getJSON(proxyUrl(articleUrl)).then (json) ->
      return json.parse.text["*"]

  extractTeaser: (article) ->
    firstParagraph = (article) ->
      ps = $(article).filter ->
        elem = $(this)
        return elem.is("p") &&
          elem.has("#coordinates").length == 0 &&
          elem.has("[style=\"display:none\"]").length == 0
      return ps.first().text()
    firstSentence = (text) ->
      lastCharBeforePeriod = text.search(/[^0-9]\./g)
      if lastCharBeforePeriod == -1
        text
      else
        text.substring(0, lastCharBeforePeriod + 2)
    firstSentence(firstParagraph(article))

  loadImageDeferred: (srcUrl) ->
    $.Deferred (deferred) =>
      img = document.createElement("img")
      img.onload = -> deferred.resolve(img)
      img.onerror = -> deferred.reject()
      img.src = srcUrl

  initPuzzle: (img) ->
    hideReward()

    ccplay.initPaper("puzzleCanvas")
    puzzle = new ccplay.Puzzle(img, 4)
    puzzle.addEventListener("finish", showReward)

    startGame = _.bind(puzzle.startGame, puzzle)
    _.delay(startGame, 2000)

    adjustSize = ->
      maxHeight = window.innerHeight - $("#title").outerHeight(true) - $("#license").outerHeight(true)

      main = $("#main")
      main.css("max-width", "100%")

      maxWidth = main.width()
      puzzle.setMaxSize(maxWidth, maxHeight)

      actualWidth = $("#puzzleCanvas").width()
      main.css("max-width", "#{actualWidth}px")

    adjustSize()
    $(window).resize(adjustSize)

    $("#showSolution").bind "mousedown touchstart", ->
      puzzle.showSolution()
      $(document).one "mouseup touchend touchcancel", ->
        puzzle.hideSolution()
      return false

  renderDeferred: ->
    @init()
    @loadDataDeferred().then (data) =>
      console.log("image id: #{data.id}")
      @loadArticleDeferred(data.links[0]).then (article) =>
        teaser = @extractTeaser(article)
        @renderTemplate(_.extend(data, teaser: teaser))
        @loadImageDeferred(proxyUrl(data.url))
    .then (img) =>
      @initPuzzle(img)

$(document).ready ->
  showLoading()
  page.renderDeferred().done ->
    hideLoading()
    showPuzzle()
  .fail ->
    document.location.reload()
