const express = require('express');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 8080;

// Enable collection of default metrics
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ register: client.register });

// Custom metrics
const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

const httpDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 10]
});

// Middleware to track metrics
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels = {
      method: req.method,
      route: req.route ? req.route.path : req.path,
      status_code: res.statusCode,
    };
    httpRequestCounter.inc(labels);
    httpDuration.observe(labels, duration);
  });
  next();
});

// Main application routes
app.get('/', (req, res) => {
  res.json({
    status: 'healthy',
    message: 'Welcome to ${{ values.name }}!',
    description: '${{ values.description }}',
    timestamp: new Date()
  });
});

app.get('/api/users', (req, res) => {
  res.json([
    { id: 1, name: 'Alice' },
    { id: 2, name: 'Bob' },
  ]);
});

// Expose /metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', client.register.contentType);
  res.send(await client.register.metrics());
});

app.listen(port, () => {
  console.log(`${{ values.name }} listening at http://localhost:${port}`);
});
