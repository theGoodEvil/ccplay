"use strict"


# Parameters

PUZZLE_CANVAS_ID = "puzzleCanvas"
PUZZLE_IMAGE_ID = "puzzleImage"

PAGE_TEMPLATE = """
  <h1><%= year %>: <%= title %></h1>

  <div>
    <p>
      Dieses Bild ist unter der Creative Commons-Lizenz <a href="http://creativecommons.org/licenses/by-sa/3.0/de/deed.de">Namensnennung-Weitergabe unter gleichen Bedingungen 3.0 Deutschland</a> lizenziert.
    </p>
    <p>
      Namensnennung: Bundesarchiv, <%= archiveid %> / <%= author %> / CC-BY-SA
    </p>
  </div>

  <canvas id="#{PUZZLE_CANVAS_ID}"></canvas>
  <img id="#{PUZZLE_IMAGE_ID}" src="<%= url %>" />
  
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

  $("##{PUZZLE_IMAGE_ID}").one "load", ->
    ccplay.initPaper(PUZZLE_CANVAS_ID)
    puzzle = new ccplay.Puzzle(PUZZLE_IMAGE_ID, 4)

    $("#showSolution").bind "mousedown touchstart", ->
      puzzle.showSolution()
      $(document).one "mouseup touchend touchcancel", ->
        puzzle.hideSolution()
      return false

renderPage = ->
  $.getJSON("image.php").done(doRenderPage)

$(document).ready(renderPage)
