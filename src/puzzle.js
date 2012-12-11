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

  function indexAtPoint (tileSize, point) {
    return point.divide(tileSize).floor();
  }

  function initInteraction (tiles) {
    var tileGroup = new Group(tiles);
    var tool = new Tool();
    var drag = null;

    function tileAtPoint (point) {
      var hit = tileGroup.hitTest(point);
      return hit ? hit.item : null;
    }

    tool.onMouseDown = function (evt) {
      var tile = tileAtPoint(evt.point);

      // Move the tile out of the tile group, so that it is
      // always on top and tiles below it can be picked.
      tile.remove();
      paper.project.activeLayer.addChild(tile);

      drag = {
        tile: tile,
        offset: tile.position.subtract(evt.point),
        sourceIndex: indexAtPoint(tile.size, evt.point)
      };
    };

    tool.onMouseDrag = function (evt) {
      drag.tile.position = evt.point.add(drag.offset);
    };

    tool.onMouseUp = function (evt) {
      var sourceTile = drag.tile;
      var targetIndex = indexAtPoint(sourceTile.size, evt.point);
      placeTileAtIndex(sourceTile, targetIndex);

      var targetTile = tileAtPoint(evt.point);
      if (targetTile) {
        placeTileAtIndex(targetTile, drag.sourceIndex);
      }

      sourceTile.remove();
      tileGroup.addChild(sourceTile);

      drag = null;
    };
  }

  function initPuzzle () {
    // Load Image
    var img = new Raster("puzzleImage");

    // Resize Canvas
    view.viewSize = img.size;
    img.position = view.center;

    // Create Image Tiles
    var tiles = createTiles(img, NUM_TILES);

    // Shuffle Tiles
    _.chain(tiles)
      .pluck("gridIndex")
      .shuffle()
      .each(function (gridIndex, i) {
        placeTileAtIndex(tiles[i], gridIndex);
      });

    // Remove Original Image
    img.remove();

    initInteraction(tiles);
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
