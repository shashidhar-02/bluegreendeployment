import { test, expect } from '@playwright/test';

const BASE_URL = process.env.BASE_URL || 'http://localhost';

test.describe('Todo App E2E Tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(BASE_URL);
  });

  test('should load the application', async ({ page }) => {
    await expect(page).toHaveTitle(/Todo/i);
  });

  test('should display health check', async ({ page }) => {
    const response = await page.goto(`${BASE_URL}/health`);
    expect(response?.status()).toBe(200);
    
    const json = await response?.json();
    expect(json).toHaveProperty('status', 'ok');
  });

  test('should create a new todo via API', async ({ request }) => {
    const newTodo = {
      title: 'E2E Test Todo',
      description: 'Created via E2E test',
      completed: false
    };

    const response = await request.post(`${BASE_URL}/todos`, {
      data: newTodo
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.success).toBe(true);
    expect(data.data.title).toBe(newTodo.title);
  });

  test('should retrieve todos list', async ({ request }) => {
    const response = await request.get(`${BASE_URL}/todos`);
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data).toHaveProperty('success', true);
    expect(Array.isArray(data.data)).toBeTruthy();
  });

  test('should update a todo', async ({ request }) => {
    // Create todo
    const createRes = await request.post(`${BASE_URL}/todos`, {
      data: { title: 'Update Test', description: 'To be updated' }
    });
    const { _id } = (await createRes.json()).data;

    // Update todo
    const updateRes = await request.put(`${BASE_URL}/todos/${_id}`, {
      data: { completed: true }
    });

    expect(updateRes.ok()).toBeTruthy();
    const updated = await updateRes.json();
    expect(updated.data.completed).toBe(true);
  });

  test('should delete a todo', async ({ request }) => {
    // Create todo
    const createRes = await request.post(`${BASE_URL}/todos`, {
      data: { title: 'Delete Test', description: 'To be deleted' }
    });
    const { _id } = (await createRes.json()).data;

    // Delete todo
    const deleteRes = await request.delete(`${BASE_URL}/todos/${_id}`);
    expect(deleteRes.ok()).toBeTruthy();

    // Verify deletion
    const getRes = await request.get(`${BASE_URL}/todos/${_id}`);
    expect(getRes.status()).toBe(404);
  });

  test('should handle errors gracefully', async ({ request }) => {
    // Invalid todo creation
    const response = await request.post(`${BASE_URL}/todos`, {
      data: { description: 'Missing title' }
    });
    expect(response.status()).toBe(400);
  });

  test('should test blue environment', async ({ page }) => {
    const response = await page.goto(`${BASE_URL}/blue/health`);
    expect(response?.status()).toBe(200);
    
    const json = await response?.json();
    expect(json.version).toContain('blue');
  });

  test('should test green environment', async ({ page }) => {
    const response = await page.goto(`${BASE_URL}/green/health`);
    expect(response?.status()).toBe(200);
    
    const json = await response?.json();
    expect(json.version).toContain('green');
  });

  test('should verify load balancer health', async ({ page }) => {
    // Make multiple requests to verify load balancing
    for (let i = 0; i < 5; i++) {
      const response = await page.goto(`${BASE_URL}/health`);
      expect(response?.status()).toBe(200);
    }
  });
});

test.describe('Performance Tests', () => {
  test('should load within acceptable time', async ({ page }) => {
    const startTime = Date.now();
    await page.goto(BASE_URL);
    const loadTime = Date.now() - startTime;

    expect(loadTime).toBeLessThan(3000); // Should load within 3 seconds
  });

  test('should handle concurrent API calls', async ({ request }) => {
    const requests = Array(20).fill(null).map(() => 
      request.get(`${BASE_URL}/todos`)
    );

    const responses = await Promise.all(requests);
    responses.forEach(response => {
      expect(response.ok()).toBeTruthy();
    });
  });
});

test.describe('Blue-Green Deployment Tests', () => {
  test('should verify both environments are accessible', async ({ page }) => {
    const blueRes = await page.goto(`${BASE_URL}/blue/health`);
    const greenRes = await page.goto(`${BASE_URL}/green/health`);

    expect(blueRes?.ok()).toBeTruthy();
    expect(greenRes?.ok()).toBeTruthy();
  });

  test('should verify environment switching', async ({ page }) => {
    // Test default routing
    const defaultRes = await page.goto(`${BASE_URL}/health`);
    const defaultJson = await defaultRes?.json();

    // Verify we get a response from either blue or green
    expect(defaultJson).toHaveProperty('version');
  });
});
