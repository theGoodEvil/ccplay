<?php

$url = $_GET["url"];
$session = curl_init($url);

curl_setopt($session, CURLOPT_HEADER, true);
curl_setopt($session, CURLOPT_RETURNTRANSFER, true);

$data = curl_exec($session);
$info = curl_getinfo($session);

$body = $info["size_download"] ? substr($data, $info["header_size"], $info["size_download"]) : "";
        
$headers = substr($data, 0, $info["header_size"]);
header("Content-Type: " . $headers["image/jpeg"]);

curl_close($session);
echo $body;

?>
