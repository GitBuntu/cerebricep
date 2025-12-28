# Branch Protection with Repository Rulesets

This guide explains how to import and use the repository rulesets defined in `.github/rulesets/` to protect your important branches.

## What are Repository Rulesets?

Repository rulesets are a powerful feature in GitHub that allow you to:
- Define whether collaborators can delete or force push to branches
- Set requirements for pushes (status checks, linear history, etc.)
- Enforce pull request reviews and approvals
- Protect specific files or directories from unauthorized changes
- Apply rules to multiple branches using patterns

Rulesets are more flexible and powerful than classic branch protection rules.

## Available Rulesets

This repository includes three pre-configured rulesets:

### 1. Main Branch Protection
- **File:** `.github/rulesets/main-branch-protection.json`
- **Target:** `main` branch
- **Key protections:**
  - Requires 1 PR approval
  - Requires code owner review
  - Blocks deletion and force pushes
  - Requires linear commit history
  - Requires "Validate Bicep Templates" status check

### 2. CI/CD and Infrastructure Protection
- **File:** `.github/rulesets/protect-cicd-infrastructure.json`
- **Target:** `main` and `develop` branches
- **Protected paths:**
  - `.github/workflows/*`
  - `.github/rulesets/*`
  - `infra/environments/prod.bicepparam`
  - `bicepconfig.json`

### 3. Release Branch Protection
- **File:** `.github/rulesets/release-branch-protection.json`
- **Target:** `release/*` and `hotfix/*` branches
- **Key protections:**
  - Requires 2 PR approvals (higher than main)
  - Strict status check policy
  - Blocks deletion and force pushes

## How to Import Rulesets

### Method 1: GitHub Web UI

1. Go to your repository on GitHub
2. Click **Settings** → **Rules** → **Rulesets**
3. Click **New ruleset** → **Import a ruleset**
4. Upload the JSON file from `.github/rulesets/`
5. Review the configuration
6. Set the enforcement to "Active" (or "Evaluate" for testing)
7. Click **Create**

### Method 2: GitHub API

Use the GitHub REST API to programmatically import rulesets:

```bash
# Set variables
REPO_OWNER="your-org"
REPO_NAME="cerebricep"
RULESET_FILE=".github/rulesets/main-branch-protection.json"

# Import ruleset
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/$REPO_OWNER/$REPO_NAME/rulesets \
  --input "$RULESET_FILE"
```

### Method 3: Terraform (Infrastructure as Code)

You can also manage rulesets with Terraform:

```hcl
resource "github_repository_ruleset" "main_protection" {
  name        = "Main Branch Protection"
  repository  = "cerebricep"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  rules {
    pull_request {
      required_approving_review_count = 1
      require_code_owner_review      = true
      dismiss_stale_reviews_on_push  = true
    }
    
    deletion = true
    non_fast_forward = true
    required_linear_history = true
  }

  bypass_actors {
    actor_id    = 5  # Repository admin role
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }
}
```

## Testing Rulesets

Before enforcing rulesets, test them in "Evaluate" mode:

1. Import the ruleset with enforcement set to "Evaluate"
2. Monitor the insights to see which operations would be blocked
3. Adjust rules as needed
4. Switch to "Active" enforcement when ready

## Bypass Permissions

All rulesets allow repository administrators to bypass rules. This should only be used:
- In emergency situations
- For critical hotfixes
- When rule adjustments are needed

**Important:** Bypass actions are logged and auditable.

## Customizing Rulesets

To adapt rulesets for your workflow:

1. Edit the JSON files in `.github/rulesets/`
2. Adjust branch patterns in `conditions.ref_name.include`
3. Modify rule parameters to match your requirements
4. Test changes in a non-production environment first

### Common Customizations

**Change approval count:**
```json
"pull_request": {
  "parameters": {
    "required_approving_review_count": 2  // Change from 1 to 2
  }
}
```

**Add more branches:**
```json
"conditions": {
  "ref_name": {
    "include": [
      "refs/heads/main",
      "refs/heads/develop",
      "refs/heads/staging"  // Add new branch
    ]
  }
}
```

**Add status checks:**
```json
"required_status_checks": [
  { "context": "Validate Bicep Templates" },
  { "context": "Security Scan" }  // Add new check
]
```

## Best Practices

1. **Start with main branch:** Protect your primary branch first
2. **Test in evaluate mode:** Use evaluate mode before full enforcement
3. **Document exceptions:** Keep track of when and why bypass was used
4. **Review regularly:** Audit rulesets quarterly to ensure they still serve your needs
5. **Educate team:** Make sure all contributors understand the rules
6. **Monitor compliance:** Use GitHub Insights to track rule effectiveness

## Troubleshooting

### Status check not found
- Ensure the workflow job name matches the status check context exactly
  - The context name comes from the workflow job name (e.g., `jobs.validate.name`)
  - You can explicitly set it using the `name` field in the job definition
- Check that the workflow runs on pull requests
- Verify the status check has completed at least once on a PR

### File path restriction not working
- Verify file paths use the correct format
- Remember that wildcards follow specific patterns (`*` for single level, `**` for recursive)

### Bypass not working
- Confirm the actor_id corresponds to the correct role
- Check repository permissions

## Resources

- [GitHub Docs: Managing Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [GitHub Ruleset Recipes](https://github.com/github/ruleset-recipes)
- [GitHub REST API: Rulesets](https://docs.github.com/en/rest/repos/rules)

## Support

For questions or issues with rulesets:
1. Check the [troubleshooting section](#troubleshooting)
2. Review the [GitHub Rulesets documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
3. Open an issue in this repository
