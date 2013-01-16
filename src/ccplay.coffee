"use strict"


# Utilities

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

EXCEPTIONS = /// ^(
  .                               # single letters
  | [IVXLCDM]+                    # roman numerals
  | \d+                           # arabic numerals
  | m\.b\.H | e\.V                # organizations
  | bzw | geb | St | gem | Nr     # common abbreviations
  | lat | engl                    # language abbreviations
)$ ///

loadWikipediaArticleDeferred = (link) ->
  title = _.last(link.split("wiki/"))
  articleUrl = "http://de.wikipedia.org/w/api.php?format=json&action=parse&prop=text&page=#{title}"
  $.getJSON(proxyUrl(articleUrl)).then (json) ->
    return json.parse.text["*"]

extractContent = (article) ->
  getFirstParagraph = (article) ->
    ps = $(article).filter ->
      elem = $(this)
      return elem.is("p") &&
        elem.has("#coordinates").length == 0 &&
        elem.has("[style=\"display:none\"]").length == 0
    text = ps.first().text()

    # Strip footnote links
    return text.replace(/\[\d\]/, "")

  getFirstSentence = (text) ->
    lastWord = (stopIndex) ->
      previousSpace = text.lastIndexOf(" ", stopIndex)
      text.substring(previousSpace + 1, stopIndex)

    done = false
    stopIndex = 0
    until done
      stopIndex = text.indexOf(".", stopIndex)
      if stopIndex in [-1, text.length - 1]
        # End of text, or no period at all
        stopIndex = text.length - 1
        done = true
      else if text[stopIndex + 1] != " " or EXCEPTIONS.test(lastWord(stopIndex))
        # Period that is not followed by a space, or preceded by an exception
        stopIndex += 1
      else
        # Period that ends the sentence
        done = true
    return text.substr(0, stopIndex + 1)

  firstParagraph = getFirstParagraph(article)
  teaser = getFirstSentence(firstParagraph)

  return { firstParagraph: firstParagraph, teaser: teaser }


# Model

class DecadeModel extends Backbone.Model
  defaults:
    unlocked: false


class Timeline extends Backbone.Collection
  constructor: (firstDecade, lastDecade) ->
    super()
    decades = (new DecadeModel(id: decade) for decade in [firstDecade..lastDecade] by 10)
    @reset(decades)

  unlock: (year) ->
    decade = Math.floor(year / 10) * 10
    @get(decade).set("unlocked", true)


class MainModel extends Backbone.Model
  urlRoot: "image.php"

  defaults:
    solved: false

  reset: (options = {}) ->
    @clear(options)
    @set(_.result(this, "defaults"), options)

  queryParam: (prop) ->
    "#{prop}=#{@get(prop)}" if @get(prop)?

  url: ->
    param = @queryParam("id") or @queryParam("decade")
    _.compact([@urlRoot, param]).join("?")

  fetch: ->
    @set("loading", true)
    Backbone.Model::fetch.call(this, silent: true).then =>
      $.when(@fetchArticle(), @fetchImage()).then =>
        @set("loading", false)
        @change()

  fetchArticle: ->
    loadWikipediaArticleDeferred(@get("links")[0]).then (article) =>
      @set("article", extractContent(article), silent: true)

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
    super(options)
    @template = TemplateView.compileTemplate(name)

  render: ->
    markup = @template(@model.toJSON())
    @$el.html(markup)


class GroupView extends Backbone.View
  constructor: (options) ->
    super(options)
    @subviews = []

  addSubview: (subview, options = {}) ->
    @subviews.push(subview)
    @$el.append(subview.el) if options.append
    return subview

  render: ->
    _.invoke(@subviews, "render")


class DecadeView extends TemplateView
  tagName: "span"
  className: "decade"

  constructor: (options) ->
    super("decade", options)
    @listenTo(@model, "change", @render)


class TimelineView extends GroupView
  constructor: (options) ->
    super(options)
    @model.each (decade) =>
      @addSubview(new DecadeView(model: decade), append: true)


class PuzzleView extends Backbone.View
  render: ->
    @puzzle?.destroy()
    @puzzle = new ccplay.Puzzle(@el, @model.get("img"), 4)
    @puzzle.addEventListener("solve", => @model.set("solved", true))

    startGame = _.bind(@puzzle.startGame, @puzzle)
    _.delay(startGame, 2000)

  setMaxSize: (maxWidth, maxHeight) ->
    @puzzle?.setMaxSize(maxWidth, maxHeight)

  showSolution: ->
    @puzzle?.showSolution()

  hideSolution: ->
    @puzzle?.hideSolution()


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
    @article = @addTemplateSubview("article")
    @actions = @addTemplateSubview("actions")

    @listenTo(@model, "change", @render)
    $(window).resize => @adjustSize()

  addTemplateSubview: (name) ->
    @addSubview(new TemplateView(name, el: $("##{name}"), model: @model))

  render: ->
    if @model.get("loading")
      @$el.css("opacity", 0)
    else if @model.get("solved")
      @article.render()
    else
      super()

      @$el.css("opacity", 1)
      @adjustSize()
      _.defer -> window.scrollTo(0, 1)

      @delegateEvents
        "mousedown #solutionButton": "showSolution"
        "touchstart #solutionButton": "showSolution"

  showSolution: ->
    @puzzle.showSolution()
    $(document).one "mouseup touchend touchcancel", =>
      @puzzle.hideSolution()
    return false

  adjustSize: ->
    @$el.css("max-width", "100%")
    availableWidth = @$el.width()

    actionsWidth = if availableWidth > 480 then @actions.$el.width() + 20 else 0
    maxPuzzleWidth = availableWidth - actionsWidth

    @puzzle.setMaxSize(maxPuzzleWidth, Infinity)

    actualPuzzleWidth = @puzzle.$el.width()
    @$el.css("max-width", "#{actualPuzzleWidth + actionsWidth}px")

# App

class App extends Backbone.Router
  routes:
    "decade/:decade": "decadeRoute"
    "image/(:id)": "imageRoute"
    "*path": "defaultRoute"

  constructor: ->
    super()

    timeline = new Timeline(1920, 1990)
    timelineView = new TimelineView(el: $("#timeline"), model: timeline)
    timelineView.render()

    @model = new MainModel()
    loadingView = new LoadingView(el: $("#loading"), model: @model)
    mainView = new MainView(el: $("#main"), model: @model)

    @model.on "change:id", (model, id) =>
      @navigate("image/#{id}", replace: true) if id?

    @model.on "change:solved", (model, solved) ->
      timeline.unlock(model.get("year")) if solved

  newImage: (options) ->
    @model.reset(silent: true)
    @model.set(options, silent: true)
    @model.fetch()

  decadeRoute: (decade) ->
    @newImage(decade: decade)

  imageRoute: (id) ->
    options = if id then {id: id} else {}
    @newImage(options)

  defaultRoute: ->
    @navigate("image/", trigger: true)


# Go!

$ ->
  app = new App()
  Backbone.history.start()
