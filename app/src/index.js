const { createApp } = require('./server');

const PORT = process.env.PORT || 8080;

createApp().listen(PORT, '0.0.0.0', () => {
  console.log(`Service listening on port ${PORT}`);
});
