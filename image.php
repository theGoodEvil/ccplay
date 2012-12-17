<?php

/* Configuration */
define('DATABASE', 'myDatabase');
define('USERNAME', 'myUsername');
define('PASSWORD', 'myPassword');

/* Connect to database */
$pdo = new PDO('mysql:dbname=' . DATABASE, USERNAME, PASSWORD);
$pdo->query('SET NAMES "utf8"');

/* Get random image offset */
$countStatement = $pdo->query('SELECT COUNT(*) AS imageCount FROM CCPlayImages');
$row = $countStatement->fetch(PDO::FETCH_ASSOC);
$randomOffset = mt_rand(0, $row['imageCount'] - 1);

/* Fetch random image */
$imageStatement = $pdo->prepare('SELECT id, pageid, title, author, archiveid, url, mime, sha1 FROM CCPlayImages LIMIT ?, 1');
$imageStatement->bindValue(1, $randomOffset, PDO::PARAM_INT);
$imageStatement->execute();
$image = $imageStatement->fetch(PDO::FETCH_ASSOC);

/* Fetch links */
$linkStatement = $pdo->prepare('SELECT url FROM WikiLinks WHERE imageid=?');
$linkStatement->bindValue(1, $image['id'], PDO::PARAM_INT);
$linkStatement->execute();
$links = $linkStatement->fetchAll(PDO::FETCH_COLUMN, 0);

/* Return JSON data */
$image['links'] = $links;
echo json_encode($image);

?>
