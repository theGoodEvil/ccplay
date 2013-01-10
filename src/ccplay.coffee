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

class Model extends Backbone.Model
  urlRoot: "image.php"

  fetch: ->
    Backbone.Model::fetch.call(this, silent: true).then =>
      $.when(@fetchTeaser(), @fetchImage()).then =>
        @change()

  fetchTeaser: ->
    loadWikipediaArticleDeferred(@get("links")[0]).then (article) =>
      @set("teaser", extractTeaser(article), silent: true)

  fetchImage: ->
    loadImageDeferred(proxyUrl(@get("url"))).then (img) =>
      @set("img", img, silent: true)


# Views

class TemplateView extends Backbone.View
  @compileTemplate: _.memoize (name) ->
    templateName = "#{name}Template"
    templateString = $("##{templateName}").html()

    return _.template(templateString)

  constructor: (name, options) ->
    super(_.extend(options, el: $("##{name}")))
    @template = TemplateView.compileTemplate(name)

  render: ->
    markup = @template(@model.toJSON())
    @$el.html(markup)


class PuzzleView extends Backbone.View
  constructor: (options) ->
    super(options)
    ccplay.initPaper("puzzleCanvas")

  render: ->
    puzzle = new ccplay.Puzzle(@model.get("img"), 4)
    puzzle.addEventListener("solve", => @trigger("solve"))

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


class GroupView extends Backbone.View
  constructor: (options) ->
    super(options)
    @subviews = []

  addSubview: (subview) ->
    @subviews.push(subview)

  render: ->
    _.invoke(@subviews, "render")


class CCPlayView extends GroupView
  constructor: (options) ->
    super(options)
    @model = new Model()
    @listenTo(@model, "change", @render)

    @puzzleView = new PuzzleView(model: @model)
    @addSubview(@puzzleView)

    @addTemplateSubview("title")
    @addTemplateSubview("license")
    @addTemplateSubview("teaser")
    @addTemplateSubview("actions")

    @model.fetch()

  addTemplateSubview: (name) ->
    @addSubview(new TemplateView(name, model: @model))

  render: ->
    super()
    @hideReward()

  hideReward: -> $(".reward").addClass("hidden")
  showReward: -> $(".reward").removeClass("hidden")


# Go!

$ -> view = new CCPlayView(el: $("#main"))
