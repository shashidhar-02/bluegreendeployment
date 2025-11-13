const request = require('supertest');
const mongoose = require('mongoose');

// Import app (adjust path as needed)
let app;
let server;

describe('Todo API Integration Tests', () => {
  beforeAll(async () => {
    // Connect to test database
    const mongoUri = process.env.MONGO_TEST_URI || 'mongodb://localhost:27017/todoapp_test';
    await mongoose.connect(mongoUri);
    
    // Import app after DB connection
    app = require('../../src/index');
  });

  afterAll(async () => {
    await mongoose.connection.dropDatabase();
    await mongoose.connection.close();
    if (server) server.close();
  });

  beforeEach(async () => {
    // Clean database before each test
    const collections = mongoose.connection.collections;
    for (const key in collections) {
      await collections[key].deleteMany();
    }
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const res = await request(app)
        .get('/health')
        .expect(200);

      expect(res.body).toHaveProperty('status', 'ok');
      expect(res.body).toHaveProperty('version');
    });
  });

  describe('POST /todos', () => {
    it('should create a new todo', async () => {
      const newTodo = {
        title: 'Test Todo',
        description: 'Test Description',
        completed: false
      };

      const res = await request(app)
        .post('/todos')
        .send(newTodo)
        .expect(201);

      expect(res.body).toHaveProperty('success', true);
      expect(res.body.data).toHaveProperty('title', newTodo.title);
      expect(res.body.data).toHaveProperty('_id');
    });

    it('should fail without title', async () => {
      const invalidTodo = {
        description: 'Test Description'
      };

      await request(app)
        .post('/todos')
        .send(invalidTodo)
        .expect(400);
    });

    it('should handle duplicate titles gracefully', async () => {
      const todo = {
        title: 'Duplicate Todo',
        description: 'First'
      };

      await request(app).post('/todos').send(todo).expect(201);
      await request(app).post('/todos').send(todo).expect(201); // Allow duplicates or expect 409
    });
  });

  describe('GET /todos', () => {
    beforeEach(async () => {
      // Create test todos
      const todos = [
        { title: 'Todo 1', description: 'Desc 1', completed: false },
        { title: 'Todo 2', description: 'Desc 2', completed: true },
        { title: 'Todo 3', description: 'Desc 3', completed: false }
      ];

      for (const todo of todos) {
        await request(app).post('/todos').send(todo);
      }
    });

    it('should return all todos', async () => {
      const res = await request(app)
        .get('/todos')
        .expect(200);

      expect(res.body).toHaveProperty('success', true);
      expect(res.body.data).toHaveLength(3);
    });

    it('should filter by completion status', async () => {
      const res = await request(app)
        .get('/todos?completed=true')
        .expect(200);

      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].completed).toBe(true);
    });

    it('should support pagination', async () => {
      const res = await request(app)
        .get('/todos?page=1&limit=2')
        .expect(200);

      expect(res.body.data).toHaveLength(2);
    });
  });

  describe('GET /todos/:id', () => {
    let todoId;

    beforeEach(async () => {
      const res = await request(app)
        .post('/todos')
        .send({ title: 'Test Todo', description: 'Test' });
      todoId = res.body.data._id;
    });

    it('should return a specific todo', async () => {
      const res = await request(app)
        .get(`/todos/${todoId}`)
        .expect(200);

      expect(res.body.data).toHaveProperty('_id', todoId);
      expect(res.body.data).toHaveProperty('title', 'Test Todo');
    });

    it('should return 404 for non-existent todo', async () => {
      const fakeId = new mongoose.Types.ObjectId();
      await request(app)
        .get(`/todos/${fakeId}`)
        .expect(404);
    });

    it('should return 400 for invalid ID format', async () => {
      await request(app)
        .get('/todos/invalid-id')
        .expect(400);
    });
  });

  describe('PUT /todos/:id', () => {
    let todoId;

    beforeEach(async () => {
      const res = await request(app)
        .post('/todos')
        .send({ title: 'Test Todo', description: 'Test', completed: false });
      todoId = res.body.data._id;
    });

    it('should update a todo', async () => {
      const updates = {
        title: 'Updated Todo',
        completed: true
      };

      const res = await request(app)
        .put(`/todos/${todoId}`)
        .send(updates)
        .expect(200);

      expect(res.body.data).toHaveProperty('title', 'Updated Todo');
      expect(res.body.data).toHaveProperty('completed', true);
    });

    it('should return 404 for non-existent todo', async () => {
      const fakeId = new mongoose.Types.ObjectId();
      await request(app)
        .put(`/todos/${fakeId}`)
        .send({ title: 'Updated' })
        .expect(404);
    });
  });

  describe('DELETE /todos/:id', () => {
    let todoId;

    beforeEach(async () => {
      const res = await request(app)
        .post('/todos')
        .send({ title: 'Test Todo', description: 'Test' });
      todoId = res.body.data._id;
    });

    it('should delete a todo', async () => {
      await request(app)
        .delete(`/todos/${todoId}`)
        .expect(200);

      // Verify it's deleted
      await request(app)
        .get(`/todos/${todoId}`)
        .expect(404);
    });

    it('should return 404 for non-existent todo', async () => {
      const fakeId = new mongoose.Types.ObjectId();
      await request(app)
        .delete(`/todos/${fakeId}`)
        .expect(404);
    });
  });

  describe('Error Handling', () => {
    it('should handle database connection errors', async () => {
      await mongoose.connection.close();
      
      const res = await request(app)
        .get('/todos')
        .expect(500);

      expect(res.body).toHaveProperty('success', false);
      
      // Reconnect for cleanup
      const mongoUri = process.env.MONGO_TEST_URI || 'mongodb://localhost:27017/todoapp_test';
      await mongoose.connect(mongoUri);
    });

    it('should handle malformed JSON', async () => {
      await request(app)
        .post('/todos')
        .set('Content-Type', 'application/json')
        .send('{"invalid json')
        .expect(400);
    });
  });

  describe('Performance', () => {
    it('should handle concurrent requests', async () => {
      const requests = [];
      for (let i = 0; i < 10; i++) {
        requests.push(
          request(app)
            .post('/todos')
            .send({ title: `Todo ${i}`, description: `Desc ${i}` })
        );
      }

      const results = await Promise.all(requests);
      results.forEach(res => {
        expect(res.status).toBe(201);
      });
    });

    it('should respond within acceptable time', async () => {
      const start = Date.now();
      await request(app).get('/todos').expect(200);
      const duration = Date.now() - start;

      expect(duration).toBeLessThan(500); // Should respond within 500ms
    });
  });
});
