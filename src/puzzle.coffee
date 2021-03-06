"use strict"


# Event source

class EventDispatcher
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

paper.Size::scaledToFit = (maxSize) ->
  xScale = Math.min(1, maxSize.width / @width)
  yScale = Math.min(1, maxSize.height / @height)
  return @multiply(Math.min(xScale, yScale))

paper.Item::isLandscape = ->
  @bounds.width >= @bounds.height

paper.Item::placeAt = (gridId) ->
  tileStart = gridId.multiply(@bounds.size)
  @position = tileStart.add(@bounds.size.divide(2))


Tile = paper.Item.extend
  initialize: (@raster, @cropRect) ->
    @base()
    @rect = new paper.Rectangle(@cropRect.size).setCenter(0, 0)
    return

  _getBounds: (type, matrix) ->
    if matrix then matrix._transformBounds(@rect) else @rect

  _hitTest: (point) ->
    if @rect.contains(point)
      new HitResult('fill', this)
    else
      null

  draw: (ctx, param) ->
    ctx.drawImage(
      @raster.getImage()
      @cropRect.left
      @cropRect.top
      @cropRect.width
      @cropRect.height
      @rect.left
      @rect.top
      @rect.width
      @rect.height
    )


class Puzzle extends EventDispatcher
  CROP_SIZE = 5
  LABEL_HEIGHT = 22
  LABEL_WIDTH = 400

  constructor: (canvas, img, @numTiles) ->
    super()

    @scope = new paper.PaperScope()
    @scope.setup(canvas)
    @scope.view.onFrame = => @scope.view.draw()

    # Init original image
    @raster = new paper.Raster(img)
    @raster.visible = false

    # Init cropping
    crop = @shouldCrop()
    @croppedSize = @computeCroppedSize(crop)
    cropOffset = @computeCropOffset(crop)

    # Init tiles
    @gridIds = @computeGridIds()
    @tiles = _.map(@gridIds, (gridId) => @createTileAt(gridId, cropOffset))
    @tileGroup = new paper.Group(@tiles)

    # Init view
    @scope.view.viewSize = @actualSize()

    # Init sounds
    @addEventListener("solve", => @playSound("solve"))

    # Init interaction
    @emptyTool = new paper.Tool()
    @puzzleTool = @createPuzzleTool()
    @emptyTool.activate()
    @addEventListener("solve", => @puzzleTool.remove())

  startGame: ->
    @shuffle()
    @puzzleTool.activate()

  destroy: ->
    @scope.remove()

  # Sounds

  SOUNDS =
    solve: new buzz.sound("snd/solve", formats: ["ogg", "mp3"], preload: true)
    move: new buzz.sound("snd/move", formats: ["ogg", "mp3"], preload: true)
    shuffle: new buzz.sound("snd/shuffle", formats: ["ogg", "mp3"], preload: true)

  playSound: (name) ->
    SOUNDS[name].play()

  # Show solution

  showSolution: ->
    if @puzzleTool.isActive() and not @lastPlacement
      @emptyTool.activate()
      @lastPlacement = @currentPlacement()
      _.each(@tiles, (tile) -> tile.placeAt(tile.gridId))
      return true
    return false

  hideSolution: ->
    if @lastPlacement
      _.each(@tiles, (tile, i) => tile.placeAt(@lastPlacement[i]))
      delete @lastPlacement
      @puzzleTool.activate()

  # Crop original image

  shouldCrop: ->
    # Position the image so that pixel indices work as expected
    originalPosition = @raster.position
    @raster.position = @raster.size.divide(2)

    labelRect = if @raster.isLandscape()
      new paper.Rectangle(@raster.width - LABEL_WIDTH, @raster.height - LABEL_HEIGHT, LABEL_WIDTH, LABEL_HEIGHT)
    else
      new paper.Rectangle(@raster.width - LABEL_HEIGHT, 0, LABEL_HEIGHT, LABEL_WIDTH)
    color = @raster.getAverageColor(labelRect)

    @raster.position = originalPosition
    return color.red > 0.995 and color.green > 0.995 and color.blue > 0.995

  computeCroppedSize: (crop) ->
    if crop
      if @raster.isLandscape()
        @raster.size.subtract([2 * CROP_SIZE, CROP_SIZE + LABEL_HEIGHT])
      else
        @raster.size.subtract([CROP_SIZE + LABEL_HEIGHT, 2 * CROP_SIZE])
    else
      @raster.size

  computeCropOffset: (crop) ->
    if crop then new paper.Point(CROP_SIZE, CROP_SIZE) else new paper.Point(0, 0)

  # Size calculations

  setMaxSize: (maxWidth, maxHeight) ->
    placement = @currentPlacement()
    minSize = 10 * @numTiles
    @maxSize = new paper.Size(Math.max(maxWidth, minSize), Math.max(maxHeight, minSize))
    _.each(@tiles, (tile, i) =>
      tile.bounds = new paper.Rectangle(tile.bounds.point, @tileSize())
      tile.placeAt(placement[i])
    )

    @scope.view.viewSize = @actualSize()

  actualSize: ->
    @tileSize().multiply([@numTiles, @numTiles])

  tileSize: ->
    scaledSize = if @maxSize
        @croppedSize.scaledToFit(@maxSize)
      else
        @croppedSize
    scaledSize.divide(@numTiles).floor()

  # Grids and tiles

  shuffle: ->
    @playSound("shuffle")
    
    _.chain(@gridIds)
      .shuffle()
      .each((gridId, i) => @tiles[i].placeAt(gridId))

  computeGridIds: ->
    ids = []
    for y in [0...@numTiles]
      for x in [0...@numTiles]
        ids.push(new paper.Point(x, y))
    return ids

  gridIdAt: (point) ->
    point.divide(@tileSize()).floor()

  createTileAt: (gridId, cropOffset) ->
    tileStart = cropOffset.add(gridId.multiply(@tileSize()))
    tileRect = new paper.Rectangle(tileStart, @tileSize())

    tile = new Tile(@raster, tileRect)
    tile.gridId = gridId
    tile.placeAt(gridId)

    return tile

  tileAt: (point) ->
    hit = @tileGroup.hitTest(point)
    hit?.item

  # Game logic

  currentPlacement: ->
    _.map(@tiles, (tile) => @gridIdAt(tile.position))

  solved: ->
    _.every(@tiles, (tile) => @gridIdAt(tile.position).equals(tile.gridId))

  # Interaction

  createPuzzleTool: ->
    tool = new paper.Tool()
    _.bindAll(this, "onMouseDown", "onMouseDrag", "onMouseUp")
    tool.onMouseDown = @onMouseDown
    tool.onMouseDrag = @onMouseDrag
    tool.onMouseUp = @onMouseUp
    return tool

  limitToView: (point) ->
    bounds = @scope.view.bounds
    paper.Point.min(bounds.size.subtract([1, 1]), paper.Point.max(bounds.point, point))

  onMouseDown: (evt) ->
    tile = @tileAt(evt.point)

    # Take the tile out of the tile group, so that it is
    # always on top and tiles below it can be picked.
    tile.remove()
    @scope.project.activeLayer.addChild(tile)

    @drag =
      tile: tile
      offset: tile.position.subtract(evt.point)
      sourceIndex: @gridIdAt(evt.point)

    return

  onMouseDrag: (evt) ->
    newPosition = evt.point.add(@drag.offset)
    @drag.tile.position = @limitToView(newPosition)

    return

  onMouseUp: (evt) ->
    dropPoint = @limitToView(evt.point)

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

    if @solved()
      @dispatchEvent("solve")
    else
      @playSound("move")

    return


# Export code

window.ccplay =
  Puzzle: Puzzle
