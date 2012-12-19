<?php

/* Configuration */
define('DATABASE', 'myDatabase');
define('USERNAME', 'myUsername');
define('PASSWORD', 'myPassword');

/* Connect to database */
$pdo = new PDO('mysql:dbname=' . DATABASE, USERNAME, PASSWORD);
$pdo->query('SET NAMES "utf8"');

/* Prepare WHERE statement to filter results */
$century = intval($_GET['century']);
$where = '';
if ($century > 0 && $century < 2000) {
    $where = ' WHERE year >= ' . $century . ' AND year < ' . ($century + 10);
}

/* Get random image offset */
$countStatement = $pdo->query('SELECT COUNT(*) AS imageCount FROM Images' . $where);
$row = $countStatement->fetch(PDO::FETCH_ASSOC);
$randomOffset = mt_rand(0, $row['imageCount'] - 1);

/* Fetch random image */
$imageStatement = $pdo->prepare('SELECT * FROM Images' . $where . ' LIMIT ?, 1');
$imageStatement->bindValue(1, $randomOffset, PDO::PARAM_INT);
$imageStatement->execute();
$image = $imageStatement->fetch(PDO::FETCH_ASSOC);

/* Fetch links */
$linkStatement = $pdo->prepare('SELECT url FROM WikiLinks WHERE imageid=?');
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
