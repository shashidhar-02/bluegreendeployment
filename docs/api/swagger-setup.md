# Swagger API Documentation Setup

## Overview

The API documentation is generated using OpenAPI 3.0 specification and can be viewed through Swagger UI.

## Quick Start

### 1. Install Dependencies

```bash
npm install --save swagger-ui-express swagger-jsdoc yamljs
```

### 2. Add to Your Express App

Add this to your `server.js` or `app.js`:

```javascript
const swaggerUi = require('swagger-ui-express');
const YAML = require('yamljs');
const path = require('path');

// Load OpenAPI specification
const swaggerDocument = YAML.load(path.join(__dirname, 'docs/api/openapi.yaml'));

// Serve Swagger UI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: "Todo API Documentation"
}));

console.log('📚 API Documentation available at /api-docs');
```

### 3. Access Documentation

Start your server and navigate to:
- http://localhost:3000/api-docs (local development)
- http://your-domain.com/api-docs (production)

## Features

### Interactive API Testing
- Try out API endpoints directly from the documentation
- View request/response examples
- Test with different parameters

### Comprehensive Documentation
- All endpoints documented with descriptions
- Request/response schemas
- Error codes and examples
- Authentication requirements

### Version Information
- API version tracking
- Environment-specific URLs
- Change log

## OpenAPI Specification

The API is documented using OpenAPI 3.0 specification located at:
```
docs/api/openapi.yaml
```

### Key Sections

1. **Info**: API metadata, contact, license
2. **Servers**: Available API endpoints (dev, staging, prod)
3. **Tags**: Organized endpoint categories
4. **Paths**: All API endpoints with operations
5. **Components**: Reusable schemas and security definitions

## Updating Documentation

### Adding New Endpoints

1. Edit `docs/api/openapi.yaml`
2. Add new path under `paths:` section:

```yaml
paths:
  /your-new-endpoint:
    get:
      tags:
        - YourTag
      summary: Short description
      description: Detailed description
      responses:
        '200':
          description: Success response
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/YourSchema'
```

### Adding New Schemas

Add reusable schemas under `components/schemas:`:

```yaml
components:
  schemas:
    YourSchema:
      type: object
      properties:
        field1:
          type: string
        field2:
          type: integer
```

## Alternative: JSDoc Annotations

If you prefer documenting in code, use swagger-jsdoc:

### Installation

```bash
npm install --save swagger-jsdoc
```

### Setup

```javascript
const swaggerJsDoc = require('swagger-jsdoc');
const swaggerUi = require('swagger-ui-express');

const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Todo API',
      version: '1.0.0',
      description: 'Todo API with Blue-Green Deployment'
    },
    servers: [
      { url: 'http://localhost:3000', description: 'Development' }
    ]
  },
  apis: ['./routes/*.js', './models/*.js'] // Path to API files
};

const swaggerDocs = swaggerJsDoc(swaggerOptions);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocs));
```

### Document Routes with JSDoc

```javascript
/**
 * @swagger
 * /todos:
 *   get:
 *     tags:
 *       - Todos
 *     summary: Get all todos
 *     description: Retrieve a list of all todos
 *     responses:
 *       200:
 *         description: Successful operation
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Todo'
 */
app.get('/todos', async (req, res) => {
  // Implementation
});
```

## Docker Integration

Add Swagger UI to your Docker Compose setup:

```yaml
services:
  swagger-ui:
    image: swaggerapi/swagger-ui:latest
    container_name: todo-swagger-ui
    ports:
      - "8080:8080"
    environment:
      SWAGGER_JSON: /api/openapi.yaml
    volumes:
      - ./docs/api/openapi.yaml:/api/openapi.yaml:ro
    networks:
      - app-network
```

Access at http://localhost:8080

## CI/CD Integration

### Validate OpenAPI Spec in CI

Add to your Jenkins pipeline or GitHub Actions:

```bash
# Install validator
npm install -g @apidevtools/swagger-cli

# Validate spec
swagger-cli validate docs/api/openapi.yaml
```

### Jenkins Stage

```groovy
stage('Validate API Docs') {
    steps {
        sh '''
            npm install -g @apidevtools/swagger-cli
            swagger-cli validate docs/api/openapi.yaml
        '''
    }
}
```

### GitHub Actions

```yaml
- name: Validate OpenAPI Spec
  run: |
    npm install -g @apidevtools/swagger-cli
    swagger-cli validate docs/api/openapi.yaml
```

## Export Options

### Generate Static HTML

```bash
# Install redoc-cli
npm install -g redoc-cli

# Generate static documentation
redoc-cli bundle docs/api/openapi.yaml -o docs/api/api-docs.html
```

### Generate Postman Collection

```bash
# Install openapi-to-postmanv2
npm install -g openapi-to-postmanv2

# Convert to Postman format
openapi2postmanv2 -s docs/api/openapi.yaml -o postman-collection.json
```

## Best Practices

### 1. Keep Documentation in Sync
- Update OpenAPI spec when adding/modifying endpoints
- Include in code review process
- Validate in CI/CD pipeline

### 2. Use Examples
- Provide realistic request/response examples
- Include edge cases and error scenarios
- Document all possible response codes

### 3. Describe Parameters
- Clear parameter descriptions
- Specify required vs optional
- Include validation rules (min/max, patterns)

### 4. Version Your API
- Use semantic versioning
- Document breaking changes
- Maintain version history

### 5. Security Documentation
- Document authentication methods
- Specify required permissions
- Include security best practices

## Troubleshooting

### Swagger UI Not Loading

1. Check file path:
```javascript
const swaggerDocument = YAML.load(path.join(__dirname, 'docs/api/openapi.yaml'));
console.log('Loaded swagger doc:', swaggerDocument ? 'Success' : 'Failed');
```

2. Verify YAML syntax:
```bash
yamllint docs/api/openapi.yaml
```

3. Check console for errors:
```javascript
app.use('/api-docs', (req, res, next) => {
  console.log('Swagger UI accessed');
  next();
}, swaggerUi.serve, swaggerUi.setup(swaggerDocument));
```

### Invalid OpenAPI Spec

```bash
# Validate spec
swagger-cli validate docs/api/openapi.yaml

# Bundle (resolve $refs)
swagger-cli bundle docs/api/openapi.yaml -o bundled.yaml
```

### CORS Issues

```javascript
const cors = require('cors');
app.use('/api-docs', cors(), swaggerUi.serve, swaggerUi.setup(swaggerDocument));
```

## Additional Resources

- [OpenAPI Specification](https://spec.openapis.org/oas/v3.0.3)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)
- [swagger-jsdoc Documentation](https://github.com/Surnet/swagger-jsdoc)
- [ReDoc](https://github.com/Redocly/redoc) - Alternative documentation UI

## Support

For issues or questions:
- Check the [OpenAPI Guide](https://swagger.io/docs/specification/about/)
- Review [Swagger UI Configuration](https://swagger.io/docs/open-source-tools/swagger-ui/usage/configuration/)
- Consult [swagger-jsdoc Examples](https://github.com/Surnet/swagger-jsdoc/tree/master/examples)
