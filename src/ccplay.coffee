"use strict"


# Parameters

FIRST_DECADE = 1920
LAST_DECADE = 1990

PUZZLE_CANVAS_ID = "puzzleCanvas"

PAGE_TEMPLATE = """
  <div id="main">
    <h1 id="title"><%= year %>: <%= title %></h1>

    <canvas id="#{PUZZLE_CANVAS_ID}"></canvas>

    <div id="license">
      Bildlizenz:
      <a href="http://www.bild.bundesarchiv.de/archives/barchpic/search/?search[form][SIGNATUR]=<% print(archiveid.replace(' ', '+')) %>">Bundesarchiv, <%= archiveid %></a>
      / <%= author %> /
      <a href="http://creativecommons.org/licenses/by-sa/3.0/de/deed.de">CC BY-SA 3.0 DE</a>
    </div>

    <ul>
      <li id="showSolution">
        L&ouml;sung
      </li>
      <% _.each(links, function(link) { %>
        <li class="reward">
          <a href="<%= link %>" target="_blank">Wikipedia</a>
        </li>
      <% }) %>
      <li>
        <a href="javascript:document.location.reload();">Neues Bild</a>
      </li>
      <% if (!random) { %>
        <li class="reward">
          <a href="<%= nextLink %>">N&auml;chstes Jahrzehnt</a>
        </li>
      <% } %>
    </ul>
  </div>
"""


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

renderPage = ->
  decade = +getQueryParameter("decade") || FIRST_DECADE
  params =
    random: !!getQueryParameter("random")
    nextLink: if decade < LAST_DECADE
      "ccplay.html?decade=#{decade + 10}"
    else
      "finish.html"

  doRenderPage = (data) ->
    _.extend(data, params)
    $("body").html(_.template(PAGE_TEMPLATE, data))
    hideReward() unless data.random

    img = document.createElement("img")

    img.onload = ->
      ccplay.initPaper(PUZZLE_CANVAS_ID)
      puzzle = new ccplay.Puzzle(img, 4)
      puzzle.addEventListener("finish", showReward)

      adjustSize = ->
        console.log $("#title").outerHeight(true)
        maxHeight = window.innerHeight - $("#title").outerHeight(true) - $("#license").outerHeight(true)

        main = $("#main")
        main.css("max-width", "100%")

        maxWidth = main.width()
        puzzle.setMaxSize(maxWidth, maxHeight)

        actualWidth = $("##{PUZZLE_CANVAS_ID}").width()
        main.css("max-width", "#{actualWidth}px")

      adjustSize()
      $(window).resize(adjustSize)

      $("#showSolution").bind "mousedown touchstart", ->
        puzzle.showSolution()
        $(document).one "mouseup touchend touchcancel", ->
          puzzle.hideSolution()
        return false

    img.src = "proxy.php?url=#{data.url}"

  dataUrlParts = ["image.php"]
  dataUrlParts.push($.param(decade: decade)) unless params.random
  $.getJSON(dataUrlParts.join("?")).done(doRenderPage)

$(document).ready(renderPage)
