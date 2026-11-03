const express = require('express');
const client = require('prom-client');

function createApp() {
  const app = express();
  const register = new client.Registry();
  client.collectDefaultMetrics({ register });

  const httpRequests = new client.Counter({
    name: 'http_requests_total',
    help: 'Total HTTP requests',
    labelNames: ['method', 'route', 'status'],
    registers: [register],
  });

  app.use((req, res, next) => {
    res.on('finish', () => {
      httpRequests.inc({
        method: req.method,
        route: req.route ? req.route.path : req.path,
        status: res.statusCode,
      });
    });
    next();
  });

  app.get('/', (req, res) => {
    res.json({ service: 'oeson-microservice', message: 'Built with Claude & me' });
  });

  app.get('/health/live', (req, res) => res.json({ status: 'alive' }));
  app.get('/health/ready', (req, res) => res.json({ status: 'ready' }));

  app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  });

  return app;
}

module.exports = { createApp };
