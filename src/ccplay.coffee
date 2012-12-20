"use strict"


# Parameters

FIRST_DECADE = 1920
LAST_DECADE = 1990

PUZZLE_CANVAS_ID = "puzzleCanvas"

PAGE_TEMPLATE = """
  <h1><%= year %>: <%= title %></h1>

  <canvas id="#{PUZZLE_CANVAS_ID}"></canvas>
  
  <div>
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
      <li>
        <a href="<%= link %>" target="_blank">Wikipedia</a>
      </li>
    <% }) %>
    <li>
      <a href="javascript:document.location.reload();">Neues Bild</a>
    </li>
    <% if (!random) { %>
      <li>
        <a href="<%= nextLink %>">N&auml;chstes Jahrzehnt</a>
      </li>
    <% } %>
  </ul>
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

    img = document.createElement("img")

    img.onload = ->
      ccplay.initPaper(PUZZLE_CANVAS_ID)
      puzzle = new ccplay.Puzzle(img, 4)

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
