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
  initialize: (@img, @cropRect) ->
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
      @img.getImage()
      @cropRect.left
      @cropRect.top
      @cropRect.width
      @cropRect.height
      @rect.left
      @rect.top
      @rect.width
      @rect.height
    )

class Puzzle extends EventSource
  CROP_SIZE = 5
  LABEL_HEIGHT = 22
  LABEL_WIDTH = 400

  constructor: (canvas, imgId, @numTiles) ->
    super()

    @scope = new paper.PaperScope()
    @scope.setup(canvas)
    @scope.view.onFrame = => @scope.view.draw()

    # Init original image
    @img = new paper.Raster(imgId)
    @img.visible = false

    # Init tiles
    @tiles = _.map(@gridIds(), (gridId) => @createTileAt(gridId))
    @tileGroup = new paper.Group(@tiles)

    # Init view
    @scope.view.viewSize = @actualSize()

    # Init sounds
    @addEventListener("solve", => @playSound("solve"))

  startGame: ->
    @installEventHandlers()
    @shuffle()
    @started = true

  destroy: ->
    @scope.remove()

  # Sounds

  SOUNDS =
    solve: new buzz.sound("snd/solve", formats: ["ogg", "mp3"])
    move: new buzz.sound("snd/move", formats: ["ogg", "mp3"])
    shuffle: new buzz.sound("snd/shuffle", formats: ["ogg", "mp3"])

  playSound: (name) ->
    SOUNDS[name].load() # Must be loaded again to play more than once in WebKit
    SOUNDS[name].play()

  # Show solution

  showSolution: ->
    if @started
      @lastPlacement = @currentPlacement()
      _.each(@tiles, (tile) -> tile.placeAt(tile.gridId))

  hideSolution: ->
    if @started and @lastPlacement
      _.each(@tiles, (tile, i) => tile.placeAt(@lastPlacement[i]))
      delete @lastPlacement

  # Crop original image

  shouldCrop: _.once ->
    # Position the image so that pixel indices work as expected
    originalPosition = @img.position
    @img.position = @img.size.divide(2)

    labelRect = if @img.isLandscape()
      new paper.Rectangle(@img.width - LABEL_WIDTH, @img.height - LABEL_HEIGHT, LABEL_WIDTH, LABEL_HEIGHT)
    else
      new paper.Rectangle(@img.width - LABEL_HEIGHT, 0, LABEL_HEIGHT, LABEL_WIDTH)
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
    if @shouldCrop() then new paper.Point(CROP_SIZE, CROP_SIZE) else new paper.Point(0, 0)

  # Size calculations

  setMaxSize: (maxWidth, maxHeight) ->
    placement = @currentPlacement()
    @maxSize = new paper.Size(Math.max(maxWidth, 200), Math.max(maxHeight, 200))
    _.each(@tiles, (tile, i) =>
      tile.bounds = new paper.Rectangle(tile.bounds.point, @tileSize())
      tile.placeAt(placement[i])
    )

    @scope.view.viewSize = @actualSize()

  actualSize: ->
    @tileSize().multiply([@numTiles, @numTiles])

  tileSize: ->
    scaledSize = if @maxSize
        @croppedSize().scaledToFit(@maxSize)
      else
        @croppedSize()
    scaledSize.divide(@numTiles * 2).floor().multiply(2)

  # Grids and tiles

  shuffle: ->
    @playSound("shuffle")
    
    _.chain(@gridIds())
      .shuffle()
      .each((gridId, i) => @tiles[i].placeAt(gridId))

  gridIds: _.once ->
    ids = []
    for y in [0...@numTiles]
      for x in [0...@numTiles]
        ids.push(new paper.Point(x, y))
    return ids

  gridIdAt: (point) ->
    point.divide(@tileSize()).floor()

  createTileAt: (gridId) ->
    tileStart = @cropOffset().add(gridId.multiply(@tileSize()))
    tileRect = new paper.Rectangle(tileStart, @tileSize())

    tile = new Tile(@img, tileRect)
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

  installEventHandlers: ->
    tool = new paper.Tool()
    _.bindAll(this, "onMouseDown", "onMouseDrag", "onMouseUp")
    tool.onMouseDown = @onMouseDown
    tool.onMouseDrag = @onMouseDrag
    tool.onMouseUp = @onMouseUp
    @addEventListener("solve", -> tool.remove())

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


# Loading code

window.ccplay =
  Puzzle: Puzzle