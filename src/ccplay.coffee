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

showPuzzle = -> $("#main").css("opacity", "1")

renderPage = ->
  showLoading()

  decade = +getQueryParameter("decade") || LAST_DECADE
  params =
    random: !!getQueryParameter("random")
    nextLink: if decade > FIRST_DECADE
      "ccplay.html?decade=#{decade - 10}"
    else
      "finish.html"

  doRenderPage = (data) ->
    _.extend(data, params)
    template = $("#mainTemplate").html()
    $("#main").html(_.template(template, data))

    hideReward() unless data.random

    img = document.createElement("img")

    img.onload = ->
      ccplay.initPaper("puzzleCanvas")
      puzzle = new ccplay.Puzzle(img, 4)
      puzzle.addEventListener("finish", showReward)

      adjustSize = ->
        console.log $("#title").outerHeight(true)
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

      hideLoading()
      showPuzzle()

    img.src = "proxy.php?url=#{data.url}"

  dataUrlParts = ["image.php"]
  dataUrlParts.push($.param(decade: decade)) unless params.random
  $.getJSON(dataUrlParts.join("?")).done(doRenderPage)

$(document).ready(renderPage)
