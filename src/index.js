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

// Security & Parsing Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Handle malformed JSON payloads gracefully with 400 Bad Request
app.use((err, req, res, next) => {
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({
      success: false,
      message: 'Invalid JSON payload',
      error: err.message,
    });
  }
  return next(err);
});

// Rate Limiting Middleware
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => req.path === '/health' || process.env.NODE_ENV === 'test',
  handler: (req, res) => {
    res.status(429).json({
      success: false,
      error: 'Too many requests, please try again later.',
      retryAfter: req.rateLimit ? req.rateLimit.resetTime : undefined,
    });
  },
});

app.use(limiter);

// Todo Schema & Model
const todoSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  description: {
    type: String,
    default: '',
    trim: true,
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

const Todo = mongoose.models.Todo || mongoose.model('Todo', todoSchema);

// Helper to connect to MongoDB
async function connectDB(uri = MONGODB_URI) {
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }
  return mongoose.connect(uri);
}

// Helper to validate MongoDB ObjectId
function isValidObjectId(id) {
  return mongoose.Types.ObjectId.isValid(id) && String(new mongoose.Types.ObjectId(id)) === String(id);
}

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
        delete: 'DELETE /todos/:id',
      },
    },
    documentation: 'See README.md and docs/api/openapi.yaml for full API documentation',
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  const isConnected = mongoose.connection.readyState === 1;
  res.json({
    status: 'ok',
    healthy: true,
    version: APP_VERSION,
    timestamp: new Date().toISOString(),
    mongodb: isConnected ? 'connected' : 'disconnected',
    database: isConnected ? 'connected' : 'disconnected',
  });
});

// GET /todos - Get all todos (supports ?completed=true|false and ?page=1&limit=10)
app.get('/todos', async (req, res) => {
  try {
    const filter = {};
    if (req.query.completed !== undefined) {
      filter.completed = req.query.completed === 'true' || req.query.completed === true;
    }

    let query = Todo.find(filter).sort({ createdAt: -1 });

    if (req.query.limit !== undefined || req.query.page !== undefined) {
      const page = Math.max(1, parseInt(req.query.page, 10) || 1);
      const limit = Math.max(1, Math.min(100, parseInt(req.query.limit, 10) || 10));
      const skip = (page - 1) * limit;
      if (typeof query.skip === 'function') {
        query = query.skip(skip);
      }
      if (typeof query.limit === 'function') {
        query = query.limit(limit);
      }
    }

    const todos = await query;
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
    const { title, description, completed } = req.body || {};

    if (!title || typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Title is required',
      });
    }

    const todo = new Todo({
      title: title.trim(),
      description: description !== undefined ? String(description).trim() : '',
      completed: Boolean(completed),
    });

    const savedTodo = await todo.save();
    return res.status(201).json({
      success: true,
      version: APP_VERSION,
      data: savedTodo,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Error creating todo',
      error: error.message,
    });
  }
});

// GET /todos/:id - Get a single todo by id
app.get('/todos/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid todo ID format',
      });
    }

    const todo = await Todo.findById(req.params.id);

    if (!todo) {
      return res.status(404).json({
        success: false,
        message: 'Todo not found',
      });
    }

    return res.json({
      success: true,
      version: APP_VERSION,
      data: todo,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Error fetching todo',
      error: error.message,
    });
  }
});

// PUT /todos/:id - Update a single todo by id
app.put('/todos/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid todo ID format',
      });
    }

    const { title, description, completed } = req.body || {};
    const updateData = {
      updatedAt: Date.now(),
    };

    if (title !== undefined) updateData.title = title;
    if (description !== undefined) updateData.description = description;
    if (completed !== undefined) updateData.completed = completed;

    const todo = await Todo.findByIdAndUpdate(req.params.id, updateData, {
      new: true,
      runValidators: true,
    });

    if (!todo) {
      return res.status(404).json({
        success: false,
        message: 'Todo not found',
      });
    }

    return res.json({
      success: true,
      version: APP_VERSION,
      data: todo,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Error updating todo',
      error: error.message,
    });
  }
});

// DELETE /todos/:id - Delete a single todo by id
app.delete('/todos/:id', async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid todo ID format',
      });
    }

    const todo = await Todo.findByIdAndDelete(req.params.id);

    if (!todo) {
      return res.status(404).json({
        success: false,
        message: 'Todo not found',
      });
    }

    return res.json({
      success: true,
      version: APP_VERSION,
      message: 'Todo deleted successfully',
      data: todo,
    });
  } catch (error) {
    return res.status(500).json({
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

// Start server only when executed directly
if (require.main === module) {
  connectDB()
    .then(() => console.log(`MongoDB connected successfully [${APP_VERSION}]`))
    .catch((err) => console.error('MongoDB connection error:', err));

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Todo API [${APP_VERSION}] is running on port ${PORT}`);
  });
}

app.Todo = Todo;
app.connectDB = connectDB;
module.exports = app;
