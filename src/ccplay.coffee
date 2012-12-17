"use strict"


# Parameters

PUZZLE_CANVAS_ID = "puzzleCanvas"
PUZZLE_IMAGE_ID = "puzzleImage"

PAGE_TEMPLATE = """
  <h1><%= title %></h1>
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
    <% _.each(links, function(link) { %>
      <li>
        <a href="<%= link %>">Wikipedia</a>
      </li>
    <% }) %>
  </ul>
"""


# Loading code

$(document).ready ->
  $.getJSON("image.php").done (data) ->
    $("body").html(_.template(PAGE_TEMPLATE, data))
    $("##{PUZZLE_IMAGE_ID}").one("load", ->
      ccplay.initPuzzle(PUZZLE_CANVAS_ID, PUZZLE_IMAGE_ID)
    )
