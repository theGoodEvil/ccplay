"use strict"


# Parameters

FIRST_DECADE = 1920
LAST_DECADE = 1990


# Utilities

getQueryParameter = _.memoize (name) ->
  re = new RegExp("[?&]#{name}=([^&]+)")
  match = re.exec(window.location.search)
  if match
    decodeURIComponent(match[1].replace('+', ' '))
  else
    null


# Loading code

hideReward = -> $(".reward").addClass("hidden")
showReward = -> $(".reward").removeClass("hidden")

showLoading = -> $("#loading").css("opacity", "1")
hideLoading = -> $("#loading").css("opacity", "0")

showPuzzle = -> $("#main").css("opacity", "1").css("visibility", "visible")

initButtonSound = ->
  buttonSound = new buzz.sound("snd/button", formats: ["ogg", "mp3"])
  playButtonSound = _.bind(buttonSound.play, buttonSound)
  $(".audibleButton").bind("mousedown touchstart", playButtonSound)

page =
  init: ->
    @decade = +getQueryParameter("decade") || LAST_DECADE
    @params =
      random: !!getQueryParameter("random")
      nextLink: if @decade > FIRST_DECADE
        "ccplay.html?decade=#{@decade - 10}"
      else
        "finish.html"

  loadDataDeferred: ->
    dataUrlParts = ["image.php"]
    dataUrlParts.push($.param(decade: @decade)) unless @params.random
    $.getJSON(dataUrlParts.join("?"))

  renderTemplate: (data) ->
    template = $("#mainTemplate").html()
    $("#main").html(_.template(template, data))

  loadImageDeferred: (srcUrl) ->
    $.Deferred (deferred) =>
      img = document.createElement("img")
      img.onload = -> deferred.resolve(img)
      img.src = srcUrl

  initPuzzle: (img) ->
    hideReward() unless @params.random

    ccplay.initPaper("puzzleCanvas")
    puzzle = new ccplay.Puzzle(img, 4)
    puzzle.addEventListener("finish", showReward)

    shuffle = _.bind(puzzle.shuffle, puzzle)
    _.delay(shuffle, 2000)

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
      @renderTemplate(_.extend(data, @params))
      @loadImageDeferred("proxy.php?url=#{data.url}")
    .then (img) =>
      @initPuzzle(img)

$(document).ready ->
  showLoading()
  page.renderDeferred().done ->
    initButtonSound()
    hideLoading()
    showPuzzle()
