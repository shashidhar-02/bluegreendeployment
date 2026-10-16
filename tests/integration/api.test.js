const { describe, it, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Check if node_modules/express is installed (e.g. after npm ci in CI/CD)
let hasExpress = false;
try {
  require.resolve('express');
  hasExpress = true;
} catch {
  hasExpress = false;
}

describe('Repository Structure & Configuration Integrity', () => {
  const rootDir = path.resolve(__dirname, '../..');

  it('has valid package.json with required scripts and MIT license', () => {
    const pkg = JSON.parse(fs.readFileSync(path.join(rootDir, 'package.json'), 'utf8'));
    assert.equal(pkg.name, 'todo-api');
    assert.equal(pkg.license, 'MIT');
    assert.ok(pkg.scripts.start);
    assert.ok(pkg.scripts.test);
    assert.ok(pkg.scripts.lint);
  });

  it('has valid Grafana dashboard JSON definitions', () => {
    const dashboardsDir = path.join(rootDir, 'monitoring/grafana/provisioning/dashboards');
    const files = fs.readdirSync(dashboardsDir).filter((f) => f.endsWith('.json'));
    assert.ok(files.length >= 2, 'Expected at least 2 Grafana dashboard JSON files');
    for (const file of files) {
      const content = fs.readFileSync(path.join(dashboardsDir, file), 'utf8');
      const parsed = JSON.parse(content);
      assert.ok(parsed.title, `Dashboard ${file} is missing a title`);
      assert.ok(Array.isArray(parsed.panels), `Dashboard ${file} panels must be an array`);
    }
  });

  it('has required open-source community health files', () => {
    const requiredFiles = [
      'README.md',
      'LICENSE',
      'CONTRIBUTING.md',
      'CODE_OF_CONDUCT.md',
      'SECURITY.md',
      'CHANGELOG.md',
      '.gitignore',
      '.dockerignore',
      'Dockerfile',
      'docker-compose.yml',
    ];
    for (const file of requiredFiles) {
      assert.ok(
        fs.existsSync(path.join(rootDir, file)),
        `Missing required open-source file: ${file}`
      );
    }
  });
});

describe('Todo API HTTP Endpoints (Unit & Functional Suite)', { skip: !hasExpress }, () => {
  let app;
  let server;
  let baseUrl;
  let store = [];

  before(async () => {
    process.env.NODE_ENV = 'test';
    process.env.APP_VERSION = 'blue';
    app = require('../../src/index');
    const { Todo } = app;

    // Mock Mongoose Todo model methods for fast, isolated in-memory testing
    Todo.find = (filter = {}) => {
      let results = [...store];
      if (filter.completed !== undefined) {
        results = results.filter((t) => t.completed === filter.completed);
      }
      const chain = {
        _results: results,
        sort() {
          this._results.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
          return this;
        },
        skip(n) {
          this._results = this._results.slice(n);
          return this;
        },
        limit(n) {
          this._results = this._results.slice(0, n);
          return this;
        },
        then(resolve, reject) {
          return Promise.resolve(this._results).then(resolve, reject);
        },
      };
      return chain;
    };

    Todo.prototype.save = async function saveMock() {
      const doc = {
        _id: this._id ? String(this._id) : '507f1f77bcf86cd799439011',
        title: this.title,
        description: this.description || '',
        completed: Boolean(this.completed),
        createdAt: this.createdAt || new Date(),
        updatedAt: this.updatedAt || new Date(),
      };
      store.push(doc);
      return doc;
    };

    Todo.findById = async (id) => store.find((t) => String(t._id) === String(id)) || null;

    Todo.findByIdAndUpdate = async (id, updateData) => {
      const idx = store.findIndex((t) => String(t._id) === String(id));
      if (idx === -1) return null;
      store[idx] = { ...store[idx], ...updateData };
      return store[idx];
    };

    Todo.findByIdAndDelete = async (id) => {
      const idx = store.findIndex((t) => String(t._id) === String(id));
      if (idx === -1) return null;
      const [removed] = store.splice(idx, 1);
      return removed;
    };

    await new Promise((resolve) => {
      server = app.listen(0, '127.0.0.1', () => {
        const { port } = server.address();
        baseUrl = `http://127.0.0.1:${port}`;
        resolve();
      });
    });
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
  });

  beforeEach(() => {
    store = [];
  });

  it('GET /health returns status ok and version', async () => {
    const res = await fetch(`${baseUrl}/health`);
    assert.equal(res.status, 200);
    const body = await res.json();
    assert.equal(body.status, 'ok');
    assert.equal(body.version, 'blue');
  });

  it('POST /todos creates a new todo and validates title', async () => {
    const createRes = await fetch(`${baseUrl}/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title: 'Write unit tests', description: 'Verify CI' }),
    });
    assert.equal(createRes.status, 201);
    const created = await createRes.json();
    assert.equal(created.success, true);
    assert.equal(created.data.title, 'Write unit tests');

    const badRes = await fetch(`${baseUrl}/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ description: 'Missing title' }),
    });
    assert.equal(badRes.status, 400);
  });

  it('GET /todos lists todos and supports filtering & pagination', async () => {
    store.push(
      { _id: '507f1f77bcf86cd799439011', title: 'Task 1', completed: false, createdAt: new Date() },
      { _id: '507f1f77bcf86cd799439012', title: 'Task 2', completed: true, createdAt: new Date() },
      { _id: '507f1f77bcf86cd799439013', title: 'Task 3', completed: false, createdAt: new Date() }
    );

    const allRes = await fetch(`${baseUrl}/todos`);
    const allBody = await allRes.json();
    assert.equal(allRes.status, 200);
    assert.equal(allBody.data.length, 3);

    const completedRes = await fetch(`${baseUrl}/todos?completed=true`);
    const completedBody = await completedRes.json();
    assert.equal(completedBody.data.length, 1);
    assert.equal(completedBody.data[0].title, 'Task 2');

    const pagedRes = await fetch(`${baseUrl}/todos?page=1&limit=2`);
    const pagedBody = await pagedRes.json();
    assert.equal(pagedBody.data.length, 2);
  });

  it('GET, PUT, DELETE /todos/:id handle valid, non-existent, and invalid ObjectIds', async () => {
    const validId = '507f1f77bcf86cd799439011';
    const missingId = '507f1f77bcf86cd799439099';
    store.push({ _id: validId, title: 'Initial', completed: false });

    const invalidRes = await fetch(`${baseUrl}/todos/invalid-id`);
    assert.equal(invalidRes.status, 400);

    const notFoundRes = await fetch(`${baseUrl}/todos/${missingId}`);
    assert.equal(notFoundRes.status, 404);

    const updateRes = await fetch(`${baseUrl}/todos/${validId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title: 'Updated', completed: true }),
    });
    assert.equal(updateRes.status, 200);
    const updated = await updateRes.json();
    assert.equal(updated.data.title, 'Updated');
    assert.equal(updated.data.completed, true);

    const deleteRes = await fetch(`${baseUrl}/todos/${validId}`, { method: 'DELETE' });
    assert.equal(deleteRes.status, 200);
  });

  it('returns 400 on malformed JSON and 404 on unknown routes', async () => {
    const badJsonRes = await fetch(`${baseUrl}/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{"broken": ',
    });
    assert.equal(badJsonRes.status, 400);

    const notFoundRes = await fetch(`${baseUrl}/unknown-endpoint`);
    assert.equal(notFoundRes.status, 404);
  });
});
