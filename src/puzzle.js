// Parameters
var NUM_TILES = 4;


// Load Image
var img = new Raster("puzzleImage");
// img.visible = false;

// Resize Canvas
view.viewSize = img.size;
img.position = view.center;

// Create Image Tiles
var tileSize = (img.size / NUM_TILES / 2).floor() * 2;
var tiles = [];

for (var y = 0; y < NUM_TILES; y++) {
  for (var x = 0; x < NUM_TILES; x++) {
    var tileStart = tileSize * [x, y];
    var tileRect = new Rectangle(tileStart, tileSize);

    var tile = new Raster(img.getSubImage(tileRect));
    tile.position = tileStart + tileSize / 2;

    tiles.push(tile);
  };
};

// Remove Original Image
img.remove();
