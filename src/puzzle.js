(function() {
  "use strict";

  // Parameters
  var NUM_TILES = 4;

  // Functions
  function createTiles(img, numTiles) {
    var tileSize = img.size.divide(numTiles * 2).floor().multiply(2);
    var tiles = new Group();

    for (var y = 0; y < numTiles; y++) {
      for (var x = 0; x < numTiles; x++) {
        var tileStart = tileSize.multiply([x, y]);
        var tileRect = new Rectangle(tileStart, tileSize);

        var tile = new Raster(img.getSubImage(tileRect));
        tile.position = tileStart.add(tileSize.divide(2));

        tiles.addChild(tile);
      };
    };

    return tiles;
  }


  function initPuzzle() {
    // Load Image
    var img = new Raster("puzzleImage");

    // Resize Canvas
    view.viewSize = img.size;
    img.position = view.center;

    // Create Image Tiles
    createTiles(img, NUM_TILES);

    // Remove Original Image
    img.remove();
  }


  window.onload = function() {
    paper.install(window);
    paper.setup(document.getElementById("puzzleCanvas"));
    initPuzzle();

    paper.view.onFrame = function() {
      paper.view.draw();
    };
  };
}());
