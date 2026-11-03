const test = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const { createApp } = require('../src/server');

function get(server, path) {
  return new Promise((resolve, reject) => {
    const { port } = server.address();
    http
      .get({ port, path }, (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => resolve({ status: res.statusCode, body }));
      })
      .on('error', reject);
  });
}

test('service endpoints', async (t) => {
  const server = createApp().listen(0);
  t.after(() => server.close());

  await t.test('GET / returns service info', async () => {
    const r = await get(server, '/');
    assert.strictEqual(r.status, 200);
    assert.strictEqual(JSON.parse(r.body).service, 'oeson-microservice');
  });

  await t.test('GET /health/live is alive', async () => {
    const r = await get(server, '/health/live');
    assert.strictEqual(r.status, 200);
    assert.strictEqual(JSON.parse(r.body).status, 'alive');
  });

  await t.test('GET /health/ready is ready', async () => {
    const r = await get(server, '/health/ready');
    assert.strictEqual(r.status, 200);
    assert.strictEqual(JSON.parse(r.body).status, 'ready');
  });

  await t.test('GET /metrics exposes prometheus metrics', async () => {
    const r = await get(server, '/metrics');
    assert.strictEqual(r.status, 200);
    assert.ok(r.body.includes('http_requests_total'));
  });
});
