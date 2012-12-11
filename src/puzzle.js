// Parameters
var NUM_TILES = 4;


function createTiles(img, numTiles) {
  var tileSize = (img.size / numTiles / 2).floor() * 2;
  var tiles = [];

  for (var y = 0; y < numTiles; y++) {
    for (var x = 0; x < numTiles; x++) {
      var tileStart = tileSize * [x, y];
      var tileRect = new Rectangle(tileStart, tileSize);

      var tile = new Raster(img.getSubImage(tileRect));
      tile.position = tileStart + tileSize / 2;

      tiles.push(tile);
    };
  };

  return tiles;
}


function main() {
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


main();
