"use strict"


# Parameters

NUM_TILES = 4


# The Puzzle

initPuzzle = (img, numTiles) ->
  tileSize = img.size.divide(numTiles * 2).floor().multiply(2)
  view.viewSize = tileSize.multiply([numTiles, numTiles])

  computeGridIds = ->
    gridIds = []
    for y in [0...NUM_TILES]
      for x in [0...NUM_TILES]
        gridIds.push(new Point(x, y))
    return gridIds

  createTile = (gridId) ->
    tileStart = gridId.multiply(tileSize)
    tileRect = new Rectangle(tileStart, tileSize)

    tile = new Raster(img.getSubImage(tileRect))
    tile.gridId = gridId
    return tile

  placeTileAtIndex = (tile, gridId) ->
    tileStart = gridId.multiply(tile.size)
    tile.position = tileStart.add(tile.size.divide(2))

  indexAtPoint = (point) ->
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
        sourceIndex: indexAtPoint(evt.point)

      return

    tool.onMouseDrag = (evt) ->
      newPosition = evt.point.add(drag.offset)
      drag.tile.position = newPosition
      return

    tool.onMouseUp = (evt) ->
      sourceTile = drag.tile
      targetIndex = indexAtPoint(evt.point)
      placeTileAtIndex(sourceTile, targetIndex)

      targetTile = tileAtPoint(evt.point)
      sourceIndex = drag.sourceIndex
      placeTileAtIndex(targetTile, sourceIndex) if targetTile

      sourceTile.remove()
      tileGroup.addChild(sourceTile)

      drag = null
      return

  # Create tiles
  gridIds = computeGridIds()
  tiles = _.map(gridIds, (gridId) -> createTile(gridId))

  # Place tiles randomly
  _.chain(gridIds)
    .shuffle()
    .each((gridId, i) -> placeTileAtIndex(tiles[i], gridId))

  initInteraction(tiles)

# Paper.js Setup
window.onload = ->
  paper.install(window)
  paper.setup(document.getElementById("puzzleCanvas"))

  paper.view.onFrame = ->
    paper.view.draw()

  img = new Raster("puzzleImage")
  initPuzzle(img, NUM_TILES)
