<?php

$url = $_GET["url"];
$session = curl_init($url);

curl_setopt($session, CURLOPT_HEADER, true);
curl_setopt($session, CURLOPT_RETURNTRANSFER, true);

$data = curl_exec($session);
$info = curl_getinfo($session);

$body = $info["size_download"] ? substr($data, $info["header_size"], $info["size_download"]) : "";
header("Content-Type: " . $info["content_type"]);

curl_close($session);
echo $body;

?>
