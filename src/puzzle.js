(function () {
  "use strict";

  // Parameters
  var NUM_TILES = 4;

  // Put paper.js classes into global namespace
  paper.install(window);

  // Tile class
  var Tile = Raster.extend({
    initialize: function (gridIndex, data) {
      this.base(data);
      this.gridIndex = gridIndex;
    },

    snapToGrid: function () {
      var tileStart = this.gridIndex.multiply(this.size);
      this.position = tileStart.add(this.size.divide(2));
    }
  });

  // Functions
  function createTiles (img, numTiles) {
    var tileSize = img.size.divide(numTiles * 2).floor().multiply(2);
    var tiles = new Group();

    for (var y = 0; y < numTiles; y++) {
      for (var x = 0; x < numTiles; x++) {
        var gridIndex = new Point(x, y);
        var tileStart = gridIndex.multiply(tileSize);
        var tileRect = new Rectangle(tileStart, tileSize);

        var tile = new Tile(gridIndex, img.getSubImage(tileRect));
        tile.snapToGrid();

        tiles.addChild(tile);
      };
    };

    return tiles;
  }

  function initPuzzle () {
    // Load Image
    var img = new Raster("puzzleImage");

    // Resize Canvas
    view.viewSize = img.size;
    img.position = view.center;

    // Create Image Tiles
    var tiles = createTiles(img, NUM_TILES);

    // Remove Original Image
    img.remove();

    // Interaction Handling
    var tool = new Tool();
    var drag = null;

    tool.onMouseDown = function (evt) {
      var hit = tiles.hitTest(evt.point);
      var item = hit.item;

      // Bring the item to the top.
      item.remove();
      tiles.insertChild(tiles.length, item);

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
    paper.setup(document.getElementById("puzzleCanvas"));

    paper.view.onFrame = function () {
      paper.view.draw();
    };

    initPuzzle();
  };
}());
