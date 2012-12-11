(function () {
  "use strict";

  // Parameters
  var NUM_TILES = 4;

  // Functions
  function createTiles (img, numTiles) {
    var tileSize = img.size.divide(numTiles * 2).floor().multiply(2);
    var tiles = [];

    for (var y = 0; y < numTiles; y++) {
      for (var x = 0; x < numTiles; x++) {
        var gridIndex = new Point(x, y);
        var tileStart = gridIndex.multiply(tileSize);
        var tileRect = new Rectangle(tileStart, tileSize);

        var tile = new Raster(img.getSubImage(tileRect));
        tile.gridIndex = gridIndex;

        tiles.push(tile);
      };
    };

    return tiles;
  }

  function placeTileAtIndex (tile, gridIndex) {
    var tileStart = gridIndex.multiply(tile.size);
    tile.position = tileStart.add(tile.size.divide(2));
  }

  function initPuzzle () {
    // Load Image
    var img = new Raster("puzzleImage");

    // Resize Canvas
    view.viewSize = img.size;
    img.position = view.center;

    // Create Image Tiles
    var tiles = createTiles(img, NUM_TILES);
    var tileGroup = new Group(tiles);

    // Shuffle Tiles
    _.chain(tiles)
      .pluck("gridIndex")
      .shuffle()
      .each(function (gridIndex, i) {
        placeTileAtIndex(tiles[i], gridIndex);
      });

    // Remove Original Image
    img.remove();

    // Interaction Handling
    var tool = new Tool();
    var drag = null;

    tool.onMouseDown = function (evt) {
      var hit = tileGroup.hitTest(evt.point);
      var item = hit.item;

      // Bring the item to the top.
      item.remove();
      tileGroup.insertChild(tileGroup.length, item);

      drag = {
        item: item,
        offset: item.position.subtract(evt.point)
      };
    };

    tool.onMouseDrag = function (evt) {
      drag.item.position = evt.point.add(drag.offset);
    };

    tool.onMouseUp = function (evt) {
      drag = null;
    };
  }

  // Paper.js Setup
  window.onload = function () {
    paper.install(window);
    paper.setup(document.getElementById("puzzleCanvas"));

    paper.view.onFrame = function () {
      paper.view.draw();
    };

    initPuzzle();
  };
}());
