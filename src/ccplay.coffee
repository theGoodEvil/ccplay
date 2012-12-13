"use strict"


# Parameters

PUZZLE_CANVAS_ID = "puzzleCanvas"
PUZZLE_IMAGE_ID = "puzzleImage"

PAGE_TEMPLATE = """
  <h1><%= title %></h1>
  <canvas id="#{PUZZLE_CANVAS_ID}"></canvas>
  <img id="#{PUZZLE_IMAGE_ID}" src="<%= url %>" />
"""


# Loading code

$(document).ready ->
  $.getJSON("image.php").done (data) ->
    $("body").html(_.template(PAGE_TEMPLATE, data))
    $("##{PUZZLE_IMAGE_ID}").one("load", ->
      ccplay.initPuzzle(PUZZLE_CANVAS_ID, PUZZLE_IMAGE_ID)
    )
