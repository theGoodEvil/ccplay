"use strict"


# Parameters

NUM_TILES = 4


# Puzzle code

puzzle = (img, numTiles) ->

  # Compute tile and view size
  tileSize = img.size.divide(numTiles * 2).floor().multiply(2)
  view.viewSize = tileSize.multiply([numTiles, numTiles])

  # Create tiles
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

  gridIds = computeGridIds()
  tiles = _.map(gridIds, (gridId) -> createTile(gridId))

  # Place tiles randomly
  placeTileAtIndex = (tile, gridId) ->
    tileStart = gridId.multiply(tile.size)
    tile.position = tileStart.add(tile.size.divide(2))

  _.chain(gridIds)
    .shuffle()
    .each((gridId, i) -> placeTileAtIndex(tiles[i], gridId))

  # Handle interaction
  tileGroup = new Group(tiles)
  tool = new Tool()
  drag = null

  gridIdAt = (point) ->
    point.divide(tileSize).floor()

  tileAt = (point) ->
    hit = tileGroup.hitTest(point)
    hit?.item

  limitToView = (point) ->
    Point.min(view.bounds.size.subtract([1, 1]), Point.max(view.bounds.point, point))

  finished = ->
    _.every(tiles, (tile) -> gridIdAt(tile.position).equals(tile.gridId))

  tool.onMouseDown = (evt) ->
    tile = tileAt(evt.point)

    # Take the tile out of the tile group, so that it is
    # always on top and tiles below it can be picked.
    tile.remove()
    paper.project.activeLayer.addChild(tile)

    drag =
      tile: tile
      offset: tile.position.subtract(evt.point)
      sourceIndex: gridIdAt(evt.point)

    return

  tool.onMouseDrag = (evt) ->
    newPosition = evt.point.add(drag.offset)
    drag.tile.position = limitToView(newPosition)

    return

  tool.onMouseUp = (evt) ->
    dropPoint = limitToView(evt.point)

    sourceTile = drag.tile
    targetIndex = gridIdAt(dropPoint)
    placeTileAtIndex(sourceTile, targetIndex)

    targetTile = tileAt(dropPoint)
    sourceIndex = drag.sourceIndex
    placeTileAtIndex(targetTile, sourceIndex) if targetTile

    # Put the tile back into the tile group.
    sourceTile.remove()
    tileGroup.addChild(sourceTile)

    drag = null
    tool.remove() if finished()

    return


# Loading code

window.ccplay =
  initPuzzle: (canvasId, imgId) ->
    paper.install(window)
    paper.setup(document.getElementById(canvasId))
    paper.view.onFrame = -> paper.view.draw()

    img = new Raster(imgId)
    img.visible = false
    puzzle(img, NUM_TILES)
