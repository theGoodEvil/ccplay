"use strict"


# Event source

class EventSource
  constructor: ->
    @allListeners = {}

  addEventListener: (type, listener) ->
    listeners = @allListeners[type] ||= []
    listeners.push(listener)
    return

  removeEventListener: (type, listener) ->
    listeners = @allListeners[type]
    index = listeners?.indexOf(listener) || -1
    listeners.splice(index, 1) if index >= 0
    return

  dispatchEvent: (type, evt) ->
    listeners = @allListeners[type] || []
    listener(evt) for listener in listeners
    return


# Puzzle code

limitToView = (point) ->
  Point.min(view.bounds.size.subtract([1, 1]), Point.max(view.bounds.point, point))

paper.Raster::isLandscape = ->
  @width >= @height

paper.Raster::placeAt = (gridId) ->
  tileStart = gridId.multiply(@size)
  @position = tileStart.add(@size.divide(2))

class Puzzle extends EventSource
  CROP_SIZE = 5
  LABEL_HEIGHT = 22
  LABEL_WIDTH = 400

  constructor: (imgId, @numTiles) ->
    super()

    # Init original image
    @img = new Raster(imgId)
    @img.visible = false
    @img.position = @img.size.divide(2).subtract(@cropOffset())

    # Init tiles
    @tileSize = @croppedSize().divide(@numTiles * 2).floor().multiply(2)
    @tiles = _.map(@gridIds(), (gridId) => @createTileAt(gridId))
    @tileGroup = new Group(@tiles)

    # Init view
    view.viewSize = @tileSize.multiply([@numTiles, @numTiles])

    # Shuffle tiles
    _.chain(@gridIds())
      .shuffle()
      .each((gridId, i) => @tiles[i].placeAt(gridId))

    # Install event handlers
    tool = new Tool()
    _.extend(tool, @eventHandlers())
    @addEventListener("finish", -> tool.remove())

  showSolution: -> @doShowSolution(true)
  hideSolution: -> @doShowSolution(false)
  doShowSolution: (showSolution) ->
    @tileGroup.visible = !showSolution
    @img.visible = showSolution

  shouldCrop: _.once ->
    # Position the image so that pixel indices work as expected
    originalPosition = @img.position
    @img.position = @img.size.divide(2)

    labelRect = if @img.isLandscape()
      new Rectangle(@img.width - LABEL_WIDTH, @img.height - LABEL_HEIGHT, LABEL_WIDTH, LABEL_HEIGHT)
    else
      new Rectangle(@img.width - LABEL_HEIGHT, 0, LABEL_HEIGHT, LABEL_WIDTH)
    color = @img.getAverageColor(labelRect)

    @img.position = originalPosition
    return color.red > 0.998 and color.green > 0.998 and color.blue > 0.998

  croppedSize: _.once ->
    if @shouldCrop()
      if @img.isLandscape()
        @img.size.subtract([2 * CROP_SIZE, CROP_SIZE + LABEL_HEIGHT])
      else
        @img.size.subtract([CROP_SIZE + LABEL_HEIGHT, 2 * CROP_SIZE])
    else
      @img.size

  cropOffset: _.once ->
    if @shouldCrop() then new Point(CROP_SIZE, CROP_SIZE) else new Point(0, 0)

  gridIds: _.once ->
    ids = []
    for y in [0...@numTiles]
      for x in [0...@numTiles]
        ids.push(new Point(x, y))
    return ids

  gridIdAt: (point) ->
    point.divide(@tileSize).floor()

  createTileAt: (gridId) ->
    tileStart = @cropOffset().add(gridId.multiply(@tileSize))
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
      @dispatchEvent("finish") if @finished()

      return


# Loading code

window.ccplay =
  Puzzle: Puzzle
  initPaper: (canvasId) ->
    paper.install(window)
    paper.setup(document.getElementById(canvasId))
    paper.view.onFrame = -> paper.view.draw()
