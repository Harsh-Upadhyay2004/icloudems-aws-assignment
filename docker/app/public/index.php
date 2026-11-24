<?php
$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($uri === '/health') {
    http_response_code(200);
    echo "OK";
    exit;
}
header('Content-Type: application/json');
echo json_encode([
    'app' => getenv('APP_NAME') ?: 'iCloudEMS-ERP',
    'env' => getenv('APP_ENV') ?: 'production',
    'db_host' => getenv('DB_HOST') ?: 'mysql',
    'redis_host' => getenv('REDIS_HOST') ?: 'redis',
    'status' => 'running'
]);
