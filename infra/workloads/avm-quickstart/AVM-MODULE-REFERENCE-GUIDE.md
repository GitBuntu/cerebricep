# AVM Module Reference Guide

---

## What is AVM?

**AVM = Azure Verified Modules** - a collection of pre-built, Microsoft-maintained Bicep modules that deploy Azure resources following best practices.

Think of it as:
- 🏗️ **Building blocks** for Azure infrastructure
- ✅ **Pre-tested & certified** by Microsoft
- 📚 **Well-documented** with examples
- 🛡️ **WAF-aligned** (Well-Architected Framework security, reliability, performance)
- 🔄 **Versioned** so you control upgrades

**Example:** Instead of writing a 200-line Key Vault configuration yourself, you reference `br/public:avm/res/key-vault/vault:0.11.0` and get security best practices automatically.

[AVM](https://azure.github.io/Azure-Verified-Modules/usage/quickstart/bicep/)
---

## Why Use AVM?

| Benefit | Detail |
|---------|--------|
| **No Reinventing** | Microsoft maintains the module; you don't write/maintain it |
| **Best Practices Built-In** | Security, reliability, networking defaults are pre-configured |
| **IntelliSense Discovery** | Type `br/public:avm/` in VS Code and discover all modules |
| **Human-Readable Parameters** | Use role names instead of GUIDs (e.g., `'Key Vault Secrets Officer'` not `00000000-0000-0000-0000-000000000000`) |
| **Consistent Versioning** | Explicit versions (`vault:0.11.0`); upgrade when you're ready |
| **Tested at Scale** | Microsoft uses these internally; battle-tested |
| **Less Code to Maintain** | Focus on business logic, not low-level ARM/Bicep syntax |

---

## Do You Need ACR?

**Short answer: No.**

**ACR = Azure Container Registry** - used for storing Docker container images, not related to AVM.

### What you *actually* need for AVM:

1. ✅ **Bicep CLI** - comes with Azure CLI (to build/validate)
2. ✅ **VS Code Bicep Extension** - for IntelliSense discovery
3. ✅ **Azure CLI** - to deploy
4. ✅ **Azure Subscription** - the target environment

That's it. AVM modules are **public and free** in the Bicep Registry (`br/public:avm/`). No registry setup required.

### If you had a *private* module registry:

Then you'd need authentication to access it. But public AVM? No auth, no ACR—it's all built into the Bicep tooling.

---

## Understanding the Bicep Registry Reference Syntax

When using Azure Verified Modules (AVM), you'll see references like this:

```bicep
module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  ...
}
```

This guide breaks down what each part means.

---

## Breaking down the full reference:

```
br/public:avm/res/key-vault/vault:0.11.0
│  │       │  └─────┬─────┘ └├─┘ └─┬─┘  └────┬────┘
│  │       │         │        │    │         version
│  │       │         │        │    module name
│  │       │         │        resource category
│  │       │         module type (res/pattern/utility)
│  │       namespace (AVM)
│  registry name (public)
Bicep Registry
```

### Component Breakdown:

| Component | Example | Meaning |
|-----------|---------|---------|
| **br/** | `br/` | **Bicep Registry** - you're referencing a centralized module registry |
| **public** | `public:` | **Public Registry** - Microsoft-maintained modules accessible to everyone |
| **avm/** | `avm/` | **Azure Verified Modules** namespace - officially blessed modules |
| **Module Type** | `res/` | **Resource module** - deploys an Azure resource (also: `pattern/` or `utility/`) |
| **Service Category** | `key-vault/` | The Azure service being deployed (storage, compute, etc.) |
| **Module Name** | `vault` | Specific module name within that service |
| **Version** | `:0.11.0` | Semantic version of the module |

---

## The distinguishing parts:

The key that makes this an **AVM module from the public registry**:

### **`br/public:avm/`** (the magic)

- **`br/`** = You're using the **Bicep Registry** (not local file paths)
- **`public:`** = The **public registry** (Microsoft-maintained, not a private registry)
- **`avm/`** = The **AVM namespace** (Azure Verified Modules, not just any module)

Together, `br/public:avm/` means:

> *"Get this module from the public Bicep Registry, specifically from the Azure Verified Modules namespace"*

### Why this matters:

When you type `br/public:avm/` in VS Code:
- ✅ IntelliSense automatically discovers **all AVM modules**
- ✅ You get autocomplete suggestions for available services
- ✅ VS Code connects to the live AVM registry metadata
- ✅ Documentation and examples are instantly accessible

---

## For comparison:

### Local Module (cerebricep custom)
```bicep
module identity '../../modules/identity/user-assigned-identity.bicep' = {
  ...
}
```

**Characteristics:**
- ✓ File path reference
- ✓ Relative path from bicep file
- ✓ Team-maintained, customized for cerebricep
- ✓ No discovery, must know path
- ✓ Version control via Git

---

### Public AVM Module
```bicep
module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  ...
}
```

**Characteristics:**
- ✓ Registry reference (not file path)
- ✓ Microsoft-maintained, standardized
- ✓ WAF-aligned (security & reliability built-in)
- ✓ Discoverable via IntelliSense
- ✓ Semantic versioning (can upgrade independently)
- ✓ No local maintenance needed

---

### Private Registry Module (hypothetical)
```bicep
module custom 'br/mycompany:namespace/category/module:1.0.0' = {
  ...
}
```

**Characteristics:**
- ✓ Custom registry reference
- ✓ Company-maintained modules
- ✓ Internal registry (requires authentication)
- ✓ Similar discovery experience to public AVM
- ✓ Semantic versioning

---

## Quick Reference Table

| Aspect | Local File | Public AVM | Private Registry |
|--------|-----------|----------|-----------------|
| **Reference Type** | File path | Registry URL | Registry URL |
| **Location** | Local filesystem | Public Bicep Registry | Company registry |
| **Maintained By** | Team | Microsoft | Your organization |
| **Discovery** | Manual | IntelliSense + Registry | IntelliSense + Registry |
| **Versioning** | Git + file path | Semantic (explicit version) | Semantic |
| **Authentication** | None | None | Required |
| **WAF Alignment** | Custom | ✅ Yes | Optional |
| **Examples** | Limited | ✅ Comprehensive | Variable |

---

## How to Choose

- **Use Local Modules (like cerebricep's)** for:
  - Workload-specific customizations
  - Organization-specific patterns
  - Resource configurations not available in AVM

- **Use Public AVM for:**
  - Individual Azure services (Key Vault, Storage, etc.)
  - Best practices out-of-the-box
  - When a module exists that matches your needs
  - Reducing custom code maintenance

- **Use Both (the best practice):**
  - Orchestration layer calls custom modules
  - Custom modules reference AVM where appropriate
  - Keep custom modules focused on *business logic*, not low-level resource management

**Example from this workload:**
```bicep
// Custom module for identity (cerebricep-specific pattern)
module identity '../../modules/identity/user-assigned-identity.bicep' = { ... }

// AVM module for Key Vault (Microsoft-maintained standard)
module keyVault 'br/public:avm/res/key-vault/vault:0.11.0' = { ... }
```

---

## Next Steps

1. **Explore AVM Registry:** https://aka.ms/avm/moduleindex/bicep
2. **Find modules for your services:** Search for storage, databases, compute, etc.
3. **Try in VS Code:** Type `br/public:avm/` and explore with IntelliSense
4. **Review Examples:** Each AVM module includes usage examples in its GitHub repo
5. **Adopt gradually:** Use AVM for new deployments; refactor existing modules as needed
