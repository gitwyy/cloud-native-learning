const request = require('supertest');
const app = require('../src/app');

describe('Sample CI/CD App', () => {
  
  describe('GET /', () => {
    it('should return welcome message with app info', async () => {
      const response = await request(app).get('/');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('message');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('hostname');
      expect(response.body.message).toContain('Hello from CI/CD Pipeline!');
    });
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app).get('/health');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  describe('GET /ready', () => {
    it('should return readiness status', async () => {
      const response = await request(app).get('/ready');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'ready');
      expect(response.body).toHaveProperty('timestamp');
    });
  });

  describe('GET /api/info', () => {
    it('should return API information', async () => {
      const response = await request(app).get('/api/info');
      
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('version');
      expect(response.body).toHaveProperty('description');
      expect(response.body).toHaveProperty('endpoints');
      expect(Array.isArray(response.body.endpoints)).toBe(true);
    });
  });

  describe('GET /api/users', () => {
    it('should return list of users', async () => {
      const response = await request(app).get('/api/users');
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
      expect(response.body[0]).toHaveProperty('id');
      expect(response.body[0]).toHaveProperty('name');
      expect(response.body[0]).toHaveProperty('email');
    });
  });

  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const newUser = {
        name: 'Charlie',
        email: 'charlie@example.com'
      };

      const response = await request(app)
        .post('/api/users')
        .send(newUser);
      
      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('name', newUser.name);
      expect(response.body).toHaveProperty('email', newUser.email);
    });

    it('should return 400 for missing name', async () => {
      const invalidUser = {
        email: 'test@example.com'
      };

      const response = await request(app)
        .post('/api/users')
        .send(invalidUser);
      
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });

    it('should return 400 for missing email', async () => {
      const invalidUser = {
        name: 'Test User'
      };

      const response = await request(app)
        .post('/api/users')
        .send(invalidUser);
      
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('error');
    });
  });

  describe('404 handling', () => {
    it('should return 404 for unknown routes', async () => {
      const response = await request(app).get('/unknown-route');
      
      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('error', 'Route not found');
    });
  });

});
