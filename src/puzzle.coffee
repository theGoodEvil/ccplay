"use strict"


# Puzzle code

limitToView = (point) ->
  Point.min(view.bounds.size.subtract([1, 1]), Point.max(view.bounds.point, point))

paper.Raster::placeAt = (gridId) ->
  tileStart = gridId.multiply(@size)
  @position = tileStart.add(@size.divide(2))

class Puzzle
  constructor: (imgId, @numTiles) ->
    # Init original image
    @img = new Raster(imgId)
    @img.visible = false
    @img.placeAt(new Point(0, 0))

    # Init tiles
    @tileSize = @img.size.divide(@numTiles * 2).floor().multiply(2)
    @tiles = _.map(@gridIds(), (gridId) => @createTileAt(gridId))
    @tileGroup = new Group(@tiles)

    # Init view
    view.viewSize = @tileSize.multiply([@numTiles, @numTiles])

    # Shuffle tiles
    _.chain(@gridIds())
      .shuffle()
      .each((gridId, i) => @tiles[i].placeAt(gridId))

    # Install event handlers
    _.extend(new Tool(), @eventHandlers())

  showSolution: -> @doShowSolution(true)
  hideSolution: -> @doShowSolution(false)
  doShowSolution: (showSolution) ->
    @tileGroup.visible = !showSolution
    @img.visible = showSolution

  gridIds: _.once ->
    ids = []
    for y in [0...@numTiles]
      for x in [0...@numTiles]
        ids.push(new Point(x, y))
    return ids

  gridIdAt: (point) ->
    point.divide(@tileSize).floor()

  createTileAt: (gridId) ->
    tileStart = gridId.multiply(@tileSize)
    tileRect = new Rectangle(tileStart, @tileSize)
    tile = new Raster(@img.getSubImage(tileRect))
    tile.gridId = gridId
    return tile

  tileAt: (point) ->
    hit = @tileGroup.hitTest(point)
    hit?.item

  finished: ->
    _.every(@tiles, (tile) => @gridIdAt(tile.position).equals(tile.gridId))

  eventHandlers: _.once ->
    onMouseDown: (evt) =>
      tile = @tileAt(evt.point)

      # Take the tile out of the tile group, so that it is
      # always on top and tiles below it can be picked.
      tile.remove()
      paper.project.activeLayer.addChild(tile)

      @drag =
        tile: tile
        offset: tile.position.subtract(evt.point)
        sourceIndex: @gridIdAt(evt.point)

      return

    onMouseDrag: (evt) =>
      newPosition = evt.point.add(@drag.offset)
      @drag.tile.position = limitToView(newPosition)

      return

    onMouseUp: (evt) =>
      dropPoint = limitToView(evt.point)

      sourceTile = @drag.tile
      targetIndex = @gridIdAt(dropPoint)
      sourceTile.placeAt(targetIndex)

      targetTile = @tileAt(dropPoint)
      sourceIndex = @drag.sourceIndex
      targetTile.placeAt(sourceIndex) if targetTile

      # Put the tile back into the tile group.
      sourceTile.remove()
      @tileGroup.addChild(sourceTile)

      @drag = null
      tool.remove() if @finished()

      return


# Loading code

window.ccplay =
  Puzzle: Puzzle
  initPaper: (canvasId) ->
    paper.install(window)
    paper.setup(document.getElementById(canvasId))
    paper.view.onFrame = -> paper.view.draw()
