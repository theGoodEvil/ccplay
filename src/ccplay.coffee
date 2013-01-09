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

loadImageDeferred = (srcUrl) ->
  deferred = new $.Deferred()

  img = document.createElement("img")
  img.onload = -> deferred.resolve(img)
  img.onerror = -> deferred.reject()
  img.src = srcUrl

  return deferred.promise()


# Wikipedia Article Handling

loadWikipediaArticleDeferred = (link) ->
  title = _.last(link.split("wiki/"))
  articleUrl = "http://de.wikipedia.org/w/api.php?format=json&action=parse&prop=text&page=#{title}"
  $.getJSON(proxyUrl(articleUrl)).then (json) ->
    return json.parse.text["*"]

extractTeaser = (article) ->
  firstParagraph = (article) ->
    ps = $(article).filter ->
      elem = $(this)
      return elem.is("p") &&
        elem.has("#coordinates").length == 0 &&
        elem.has("[style=\"display:none\"]").length == 0
    return ps.first().text()

  firstSentence = (text) ->
    endsOnIgnoredEnding = (stopIndex) ->
      IGNORED_ENDINGS = [
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "m.b.H", "e.V",
        "bzw", "geb", "lat", "St"]
      _.some(IGNORED_ENDINGS, (e) -> e == text.substr(stopIndex - e.length, e.length))

    done = false
    stopIndex = 0
    until done
      stopIndex = text.indexOf(".", stopIndex)
      if stopIndex in [-1, text.length - 1]
        # End of text, or no period at all
        stopIndex = text.length - 1
        done = true
      else if text[stopIndex + 1] != " " or endsOnIgnoredEnding(stopIndex)
        # Period that is not followed by a space, or preceded by an exception
        stopIndex += 1
      else
        # Period that ends the sentence
        done = true
    return text.substr(0, stopIndex + 1)

  teaser = firstSentence(firstParagraph(article))

  # Strip footnote links
  return teaser.replace(/\[\d\]/, "")


# Model

Model = Backbone.Model.extend
  urlRoot: "image.php"

  fetch: ->
    Backbone.Model::fetch.call(this, silent: true).then =>
      loadWikipediaArticleDeferred(@get("links")[0])
    .then (article) =>
      @set("teaser", extractTeaser(article), silent: true)
      @change()


# View

View = Backbone.View.extend
  initialize: ->
    View::template ||= _.template($("#mainTemplate").html())

    @model = new Model()
    @listenTo(@model, 'change', @render)
    @model.fetch()

    @showLoading()

  render: ->
    markup = @template(@model.toJSON())
    @$el.html(markup)

    loadImageDeferred(proxyUrl(@model.get("url"))).done (img) =>
      @initPuzzle(img)
      @hideLoading()
      @showPuzzle()

  showLoading: -> $("#loading").css("opacity", "1")
  hideLoading: -> $("#loading").css("opacity", "0")

  hideReward: -> $(".reward").addClass("hidden")
  showReward: -> $(".reward").removeClass("hidden")

  showPuzzle: -> $("#main").css("opacity", "1").css("visibility", "visible")

  initPuzzle: (img) ->
    @hideReward()

    ccplay.initPaper("puzzleCanvas")
    puzzle = new ccplay.Puzzle(img, 4)
    puzzle.addEventListener("finish", @showReward)

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


# Go!

$ -> view = new View(el: $("#main"))
