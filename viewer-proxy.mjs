import http from 'node:http';
import net from 'node:net';

const viewerPort = Number(process.env.III_VIEWER_PORT || 8082);
const streamPort = Number(process.env.III_STREAM_PORT || 3112);
const publicPort = Number(process.env.VIEWER_PUBLIC_PORT || 8083);
const hosts = new Set((process.env.VIEWER_ALLOWED_HOSTS || '').split(',').map(value => value.trim().toLowerCase()).filter(Boolean));
const origins = new Set((process.env.VIEWER_ALLOWED_ORIGINS || '').split(',').map(value => value.trim().replace(/\/$/, '').toLowerCase()).filter(Boolean));

const server = http.createServer((request, response) => {
  const upstream = http.request({
    hostname: '127.0.0.1',
    port: viewerPort,
    method: request.method,
    path: request.url,
    headers: request.headers,
  }, result => {
    response.writeHead(result.statusCode, result.headers);
    result.pipe(response);
  });
  upstream.setTimeout(30000, () => upstream.destroy());
  upstream.on('error', () => {
    if (!response.headersSent) response.writeHead(502);
    response.end('Viewer upstream unavailable');
  });
  response.on('close', () => upstream.destroy());
  request.pipe(upstream);
});

server.on('upgrade', (request, socket, head) => {
  const host = (request.headers.host || '').toLowerCase();
  const origin = (request.headers.origin || '').replace(/\/$/, '').toLowerCase();
  const path = (request.url || '/').split('?')[0];
  if (!hosts.has(host) || (origin && !origins.has(origin)) || !['/', '/stream/mem-live/viewer'].includes(path)) {
    socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');
    return;
  }
  const upstream = net.connect(streamPort, '127.0.0.1', () => {
    const headers = Object.entries(request.headers).flatMap(([name, value]) =>
      (Array.isArray(value) ? value : [value]).map(item => `${name}: ${item}`));
    upstream.write(`${request.method} ${request.url} HTTP/${request.httpVersion}\r\n${headers.join('\r\n')}\r\n\r\n`);
    if (head.length) upstream.write(head);
    socket.pipe(upstream).pipe(socket);
  });
  upstream.on('error', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
  socket.on('close', () => upstream.destroy());
  upstream.on('close', () => socket.destroy());
});

server.listen(publicPort, '::');
