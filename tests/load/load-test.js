import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 200 }, // Ramp up to 200 users
    { duration: '5m', target: 200 }, // Stay at 200 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.01'],   // Error rate must be below 1%
    errors: ['rate<0.1'],              // Custom error rate
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost';

// Helper function to create random todo
function getRandomTodo() {
  return {
    title: `Todo ${Math.random().toString(36).substring(7)}`,
    description: `Description ${Math.random().toString(36).substring(7)}`,
    completed: Math.random() > 0.5
  };
}

export default function () {
  // Test 1: Health check
  let res = http.get(`${BASE_URL}/health`);
  check(res, {
    'health check status is 200': (r) => r.status === 200,
    'health check has status ok': (r) => JSON.parse(r.body).status === 'ok',
  });
  errorRate.add(res.status !== 200);
  sleep(1);

  // Test 2: Get todos list
  res = http.get(`${BASE_URL}/todos`);
  check(res, {
    'get todos status is 200': (r) => r.status === 200,
    'todos response has success': (r) => JSON.parse(r.body).success === true,
  });
  errorRate.add(res.status !== 200);
  sleep(1);

  // Test 3: Create new todo
  const newTodo = getRandomTodo();
  res = http.post(`${BASE_URL}/todos`, JSON.stringify(newTodo), {
    headers: { 'Content-Type': 'application/json' },
  });
  check(res, {
    'create todo status is 201': (r) => r.status === 201,
    'create todo returns id': (r) => JSON.parse(r.body).data._id !== undefined,
  });
  errorRate.add(res.status !== 201);

  // Save todo ID for further operations
  let todoId;
  if (res.status === 201) {
    todoId = JSON.parse(res.body).data._id;
  }
  sleep(1);

  // Test 4: Get specific todo
  if (todoId) {
    res = http.get(`${BASE_URL}/todos/${todoId}`);
    check(res, {
      'get todo status is 200': (r) => r.status === 200,
      'get todo returns correct id': (r) => JSON.parse(r.body).data._id === todoId,
    });
    errorRate.add(res.status !== 200);
    sleep(1);

    // Test 5: Update todo
    const updates = { completed: true };
    res = http.put(`${BASE_URL}/todos/${todoId}`, JSON.stringify(updates), {
      headers: { 'Content-Type': 'application/json' },
    });
    check(res, {
      'update todo status is 200': (r) => r.status === 200,
      'todo is marked completed': (r) => JSON.parse(r.body).data.completed === true,
    });
    errorRate.add(res.status !== 200);
    sleep(1);

    // Test 6: Delete todo
    res = http.del(`${BASE_URL}/todos/${todoId}`);
    check(res, {
      'delete todo status is 200': (r) => r.status === 200,
    });
    errorRate.add(res.status !== 200);
  }

  sleep(2);
}

// Smoke test configuration
export const smokeTest = {
  executor: 'constant-vus',
  vus: 10,
  duration: '1m',
};

// Stress test configuration
export const stressTest = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 100 },
    { duration: '2m', target: 200 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 300 },
    { duration: '5m', target: 300 },
    { duration: '2m', target: 400 },
    { duration: '5m', target: 400 },
    { duration: '10m', target: 0 },
  ],
};

// Spike test configuration
export const spikeTest = {
  stages: [
    { duration: '10s', target: 100 },
    { duration: '1m', target: 100 },
    { duration: '10s', target: 1400 },
    { duration: '3m', target: 1400 },
    { duration: '10s', target: 100 },
    { duration: '3m', target: 100 },
    { duration: '10s', target: 0 },
  ],
};
