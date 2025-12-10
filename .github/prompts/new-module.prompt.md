---
agent: 'agent'
description: 'Scaffold a new Bicep module'
tools: ['edit', 'search']
---

# Create New Bicep Module

## Instructions

Create a new Bicep module following project patterns.

### Template Structure
```bicep
// Module: {moduleName}
// Purpose: {description}

@description('Azure region for deployment')
param location string

@description('Tags to apply to resources')
param tags object

// Resources here

// Outputs
output resourceId string = resource.id
output resourceName string = resource.name
```

### Checklist
- [ ] Added to appropriate folder under `/infra/modules/`
- [ ] Parameters have `@description` decorators
- [ ] Includes `location` and `tags` parameters
- [ ] Outputs resource ID and name
- [ ] Integrated into `main.bicep`
- [ ] Added environment-specific params if needed