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

loadWikipediaArticleDeferred = (link) ->
  title = _.last(link.split("wiki/"))
  articleUrl = "http://de.wikipedia.org/w/api.php?format=json&action=parse&prop=text&page=#{title}"
  $.getJSON(proxyUrl(articleUrl)).then (json) ->
    return json.parse.text["*"]

firstParagraph = (article) ->
  ps = $(article).filter ->
    elem = $(this)
    return elem.is("p") &&
      elem.has("#coordinates").length == 0 &&
      elem.has("[style=\"display:none\"]").length == 0
  text = ps.first().text()

  # Strip footnote links
  return text.replace(/\[\d\]/, "")


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
  urlRoot: "imageData.php"

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
        @set("twitterLink", @twitterLink(), silent: true)
        @set("loading", false, silent: true)
        @change()

  fetchArticle: ->
    loadWikipediaArticleDeferred(@get("links")[0]).then (article) =>
      @set("article", { firstParagraph: firstParagraph(article) }, silent: true)

  fetchImage: ->
    loadImageDeferred(proxyUrl(@get("url"))).then (img) =>
      @set("img", img, silent: true)

  twitterLink: ->
    text = encodeURIComponent("Es ist #{@get("year")}.")
    url = encodeURIComponent("http://ccplay.de/image/#{@get("id")}")
    "https://twitter.com/share?lang=de&text=#{text}&url=#{url}&hashtags=ccplay"


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


class DecadeView extends Backbone.View
  tagName: "a"
  className: "decade"
  attributes: -> href: "#decade/#{@model.get("id")}"

  constructor: (options) ->
    super(options)
    @$el.text(@model.get("id"))
    @listenTo(@model, "change:unlocked", @render)

  render: ->
    @$el.toggleClass("unlocked", @model.get("unlocked"))


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
    @listenTo(@model, "change:solved", => @article.$el.slideToggle("slow"))
    $(window).resize => @adjustSize()

  addTemplateSubview: (name) ->
    @addSubview(new TemplateView(name, el: $("##{name}"), model: @model))

  render: ->
    if @model.get("loading")
      @$el.css("opacity", 0)
    else unless @model.get("solved")
      super()

      @$el.css("opacity", 1)
      @adjustSize()
      _.defer -> window.scrollTo(0, 1)

      @delegateEvents
        "mousedown .solutionButton": "showSolution"
        "touchstart .solutionButton": "showSolution"
        "click .reloadButton": =>
          @toggleElement("help", false)
          @toggleElement("imprint", false)
          return true
        "click .helpButton": =>
          @toggleElement("help")
          @toggleElement("imprint", false)
          return false
        "click .imprintLink": =>
          @toggleElement("imprint")
          @toggleElement("help", false)
          return false
        "click .closeButton": =>
          @toggleElement("imprint", false)
          @toggleElement("help", false)
          return false

  showSolution: ->
    @puzzle.showSolution()
    $(document).one "mouseup touchend touchcancel", =>
      @puzzle.hideSolution()

  toggleElement: (id, newState) ->
    element = $("##{id}")
    currentState = element.is(":visible")
    newState = !currentState unless newState?
    $("html, body").animate({ scrollTop: 0 }, 500) if newState
    element.slideToggle("slow") if newState != currentState    

  adjustSize: ->
    @$el.css("max-width", "100%")
    availableWidth = @$el.width()
    isPhone = availableWidth <= 320

    actionsWidth = if isPhone then 0 else @actions.$el.width()
    maxPuzzleWidth = availableWidth - 2 * actionsWidth
    maxPuzzleHeight = window.innerHeight -
                      @title.$el.outerHeight(true) -
                      @license.$el.outerHeight(true) -
                      if isPhone then @actions.$el.outerHeight(true) else 0

    @puzzle.setMaxSize(maxPuzzleWidth, maxPuzzleHeight)

    actualPuzzleWidth = "#{@puzzle.$el.width()}px"
    @$el.css("max-width", actualPuzzleWidth)

    unless isPhone
      @actions.$el.css("left", actualPuzzleWidth)


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
