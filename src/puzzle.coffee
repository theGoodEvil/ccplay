"use strict"

# Parameters
NUM_TILES = 4

# Functions
createTiles = (img, numTiles) ->
  tileSize = img.size.divide(numTiles * 2).floor().multiply(2)
  tiles = []

  for y in [0...numTiles]
    for x in [0...numTiles]
      gridIndex = new Point(x, y)
      tileStart = gridIndex.multiply(tileSize)
      tileRect = new Rectangle(tileStart, tileSize)

      tile = new Raster(img.getSubImage(tileRect))
      tile.gridIndex = gridIndex

      tiles.push(tile)

  tiles

placeTileAtIndex = (tile, gridIndex) ->
  tileStart = gridIndex.multiply(tile.size)
  tile.position = tileStart.add(tile.size.divide(2))

indexAtPoint = (tileSize, point) ->
  point.divide(tileSize).floor()

initInteraction = (tiles) ->
  tileGroup = new Group(tiles)
  tool = new Tool()
  drag = null

  tileAtPoint = (point) ->
    hit = tileGroup.hitTest(point)
    hit?.item || null

  tool.onMouseDown = (evt) ->
    tile = tileAtPoint(evt.point)

    # Move the tile out of the tile group, so that it is
    # always on top and tiles below it can be picked.
    tile.remove()
    paper.project.activeLayer.addChild(tile)

    drag =
      tile: tile
      offset: tile.position.subtract(evt.point)
      sourceIndex: indexAtPoint(tile.size, evt.point)

    return

  tool.onMouseDrag = (evt) ->
    drag.tile.position = evt.point.add(drag.offset)
    return

  tool.onMouseUp = (evt) ->
    sourceTile = drag.tile
    targetIndex = indexAtPoint(sourceTile.size, evt.point)
    placeTileAtIndex(sourceTile, targetIndex)

    targetTile = tileAtPoint(evt.point)
    sourceIndex = drag.sourceIndex
    placeTileAtIndex(targetTile, sourceIndex) if targetTile

    sourceTile.remove()
    tileGroup.addChild(sourceTile)

    drag = null
    return

initPuzzle = ->
  # Load Image
  img = new Raster("puzzleImage")

  # Resize Canvas
  view.viewSize = img.size
  img.position = view.center

  # Create Image Tiles
  tiles = createTiles(img, NUM_TILES)

  # Shuffle Tiles
  _.chain(tiles)
    .pluck("gridIndex")
    .shuffle()
    .each((gridIndex, i) -> placeTileAtIndex(tiles[i], gridIndex))

  # Remove Original Image
  img.remove()

  initInteraction(tiles)

# Paper.js Setup
window.onload = ->
  paper.install(window)
  paper.setup(document.getElementById("puzzleCanvas"))

  paper.view.onFrame = ->
    paper.view.draw()

  initPuzzle()
