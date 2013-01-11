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
        "bzw", "geb", "lat", "St", "gem"]
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

  queryParam: (prop) ->
    "#{prop}=#{@get(prop)}" if @get(prop)?

  url: ->
    idParam = @queryParam("id")
    _.compact([@urlRoot, idParam]).join("?")

  fetch: ->
    @set("loading", true)
    Backbone.Model::fetch.call(this, silent: true).then =>
      $.when(@fetchTeaser(), @fetchImage()).then =>
        @set("loading", false)
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
  render: ->
    @puzzle?.destroy()
    @puzzle = new ccplay.Puzzle(@el, @model.get("img"), 4)
    @puzzle.addEventListener("solve", => @trigger("solve"))

    startGame = _.bind(@puzzle.startGame, @puzzle)
    _.delay(startGame, 2000)

  setMaxSize: (maxWidth, maxHeight) ->
    @puzzle?.setMaxSize(maxWidth, maxHeight)

  showSolution: ->
    @puzzle?.showSolution()

  hideSolution: ->
    @puzzle?.hideSolution()


class GroupView extends Backbone.View
  constructor: (options) ->
    super(options)
    @subviews = []

  addSubview: (subview) ->
    @subviews.push(subview)
    return subview

  render: ->
    _.invoke(@subviews, "render")


class LoadingView extends Backbone.View
  constructor: (options) ->
    super(options)
    @listenTo(@model, "change", @render)

  render: ->
    if @model.get("loading")
      @$el.css("opacity", "1")
    else
      @$el.css("opacity", "0")


class MainView extends GroupView
  constructor: (options) ->
    super(options)
    @puzzle = new PuzzleView(model: @model, el: $("#puzzle"))
    @addSubview(@puzzle)

    @title = @addTemplateSubview("title")
    @license = @addTemplateSubview("license")
    @teaser = @addTemplateSubview("teaser")
    @actions = @addTemplateSubview("actions")

    @listenTo(@model, "change", @render)
    @listenTo(@puzzle, "solve", @showReward)
    $(window).on("resize", => @adjustSize())

  addTemplateSubview: (name) ->
    @addSubview(new TemplateView(name, model: @model))

  render: ->
    if @model.get("loading")
      @$el.css("opacity", 0)
    else
      super()

      @$el.css("opacity", 1)
      @adjustSize()

      @delegateEvents
        "mousedown #showSolution": "showSolution"
        "touchstart #showSolution": "showSolution"
        "click #newImage": "newImage"

  showSolution: ->
    @puzzle.showSolution()
    $(document).one "mouseup touchend touchcancel", =>
      @puzzle.hideSolution()
    return false

  showReward: -> $(".reward").removeClass("reward")

  newImage: ->
    @model.clear(silent: true)
    @model.fetch()

  adjustSize: ->
    maxPuzzleHeight = window.innerHeight - @title.$el.outerHeight(true) - @license.$el.outerHeight(true)
    @$el.css("max-width", "100%")

    maxPuzzleWidth = @$el.width()
    @puzzle.setMaxSize(maxPuzzleWidth, maxPuzzleHeight)

    actualPuzzleWidth = @puzzle.$el.width()
    @$el.css("max-width", "#{actualPuzzleWidth}px")


# Go!

$ ->
  model = new Model()

  loadingView = new LoadingView(el: $("#loading"), model: model)
  mainView = new MainView(el: $("#main"), model: model)

  model.fetch()
