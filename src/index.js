const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://mongodb:27017/todoapp';
const APP_VERSION = process.env.APP_VERSION || 'blue';

// Middleware
app.use(helmet()); // Secure HTTP headers
app.use(cors());
app.use(express.json());

// Rate Limiting Middleware
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
  legacyHeaders: false, // Disable the `X-RateLimit-*` headers
  keyGenerator: (req, res) => {
    return req.ip || req.connection.remoteAddress; // Use IP for rate limiting
  },
  skip: (req, res) => {
    // Skip rate limiting for health checks
    return req.path === '/health';
  },
  handler: (req, res) => {
    res.status(429).json({
      error: 'Too many requests',
      retryAfter: req.rateLimit.resetTime
    });
  }
});

app.use(limiter);

// MongoDB Connection
mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log(`MongoDB connected successfully [${APP_VERSION}]`))
.catch((err) => console.error('MongoDB connection error:', err));

// Todo Schema
const todoSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    default: '',
  },
  completed: {
    type: Boolean,
    default: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

const Todo = mongoose.model('Todo', todoSchema);

// Root endpoint - Landing page
app.get('/', (req, res) => {
  res.json({
    message: 'Todo API - Blue-Green Deployment',
    version: APP_VERSION,
    status: 'running',
    endpoints: {
      health: '/health',
      todos: {
        getAll: 'GET /todos',
        getOne: 'GET /todos/:id',
        create: 'POST /todos',
        update: 'PUT /todos/:id',
        delete: 'DELETE /todos/:id'
      }
    },
    documentation: 'See README.md for full API documentation'
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    version: APP_VERSION,
    timestamp: new Date().toISOString(),
    mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
  });
});

// GET /todos - Get all todos
app.get('/todos', async (req, res) => {
  try {
    const todos = await Todo.find().sort({ createdAt: -1 });
    res.json({
      success: true,
      count: todos.length,
      version: APP_VERSION,
      data: todos,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching todos',
      error: error.message,
    });
  }
});

// POST /todos - Create a new todo
app.post('/todos', async (req, res) => {
  try {
    const { title, description, completed } = req.body;

    if (!title) {
      return res.status(400).json({
        success: false,
        message: 'Title is required',
      });
    }

    const todo = new Todo({
      title,
      description,
      completed: completed || false,
    });

    const savedTodo = await todo.save();
    res.status(201).json({
      success: true,
      version: APP_VERSION,
      data: savedTodo,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error creating todo',
      error: error.message,
    });
  }
});

// GET /todos/:id - Get a single todo by id
app.get('/todos/:id', async (req, res) => {
  try {
    const todo = await Todo.findById(req.params.id);

    if (!todo) {
      return res.status(404).json({
        success: false,
        message: 'Todo not found',
      });
    }

    res.json({
      success: true,
      version: APP_VERSION,
      data: todo,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error fetching todo',
      error: error.message,
    });
  }
});

// PUT /todos/:id - Update a single todo by id
app.put('/todos/:id', async (req, res) => {
  try {
    const { title, description, completed } = req.body;
    const updateData = {
      updatedAt: Date.now(),
    };

    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (completed !== undefined) updateData.completed = completed;

    const todo = await Todo.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true, runValidators: true }
    );

    if (!todo) {
      return res.status(404).json({
        success: false,
        message: 'Todo not found',
      });
    }

    res.json({
      success: true,
      version: APP_VERSION,
      data: todo,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error updating todo',
      error: error.message,
    });
  }
});

// DELETE /todos/:id - Delete a single todo by id
app.delete('/todos/:id', async (req, res) => {
  try {
    const todo = await Todo.findByIdAndDelete(req.params.id);

    if (!todo) {
      return res.status(404).json({
        success: false,
        message: 'Todo not found',
      });
    }

    res.json({
      success: true,
      version: APP_VERSION,
      message: 'Todo deleted successfully',
      data: todo,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error deleting todo',
      error: error.message,
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Todo API [${APP_VERSION}] is running on port ${PORT}`);
});
