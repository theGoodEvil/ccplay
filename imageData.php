<?php

/* Connect to database */
$config = parse_ini_file("config.ini");
$pdo = new PDO(
  "mysql:host=" . $config["hostname"] . ";dbname=" . $config["dbname"],
  $config["username"],
  $config["password"]);
$pdo->query('SET NAMES "utf8"');

/* Prepare WHERE statement to filter results */
$decade = array_key_exists('decade', $_GET) ? intval($_GET['decade']) : -1;
$pageid = array_key_exists('pageid', $_GET) ? intval($_GET['pageid']) : -1;

$where = '';
$randomOffset = 0;

if ($pageid >= 0) {
  $where = ' WHERE pageid = ' . $pageid;
} else {
  $where = ' WHERE landscape = TRUE';

  if ($decade > 0 && $decade < 2000) {
    $where = $where . ' AND year >= ' . $decade . ' AND year < ' . ($decade + 10);
  }

  /* Get random image offset */
  $countStatement = $pdo->query('SELECT COUNT(*) AS imageCount FROM images' . $where);
  $row = $countStatement->fetch(PDO::FETCH_ASSOC);
  $randomOffset = mt_rand(0, $row['imageCount'] - 1);
}

/* Fetch random image */
$imageStatement = $pdo->prepare('SELECT * FROM images' . $where . ' LIMIT ?, 1');
$imageStatement->bindValue(1, $randomOffset, PDO::PARAM_INT);
$imageStatement->execute();
$image = $imageStatement->fetch(PDO::FETCH_ASSOC);

/* Fetch links */
$linkStatement = $pdo->prepare('SELECT url FROM wikilinks WHERE imageid=?');
$linkStatement->bindValue(1, $image['id'], PDO::PARAM_INT);
$linkStatement->execute();
$links = $linkStatement->fetchAll(PDO::FETCH_COLUMN, 0);

/* Set headers */
header("Content-Type: application/json");
header("Cache-Control: no-cache");

/* Return JSON data */
$image['links'] = $links;
echo json_encode($image);

?>
