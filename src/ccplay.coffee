"use strict"


# Parameters

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
  </ul>
"""


# Loading code

doRenderPage = (data) ->
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

renderPage = ->
  $.getJSON("image.php").done(doRenderPage)

$(document).ready(renderPage)
