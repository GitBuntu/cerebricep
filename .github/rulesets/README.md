# Repository Rulesets

This directory contains JSON-based rulesets that define branch protection and repository policies. These rulesets help protect important branches and enforce quality standards across the repository.

## Overview

Rulesets define whether collaborators can delete or force push and set requirements for any pushes, such as passing status checks or a linear commit history.

## Available Rulesets

### 1. Main Branch Protection (`main-branch-protection.json`)

**Applies to:** `main` branch

**Protections:**
- ✅ Requires pull request with 1 approval before merging
- ✅ Requires code owner review
- ✅ Dismisses stale reviews on push
- ✅ Requires "Validate Bicep Templates" status check to pass
- ℹ️ Does not require strict status checks (allows merging without re-running checks after base branch updates for flexibility)
- ✅ Blocks deletion of the branch
- ✅ Blocks force pushes
- ✅ Requires linear commit history

**Purpose:** Ensures all changes to the main branch go through proper review and validation processes.

### 2. CI/CD and Infrastructure Protection (`protect-cicd-infrastructure.json`)

**Applies to:** `main` and `develop` branches

**Protected Paths:**
- `.github/workflows/*` - GitHub Actions workflow files
- `.github/rulesets/*` - Ruleset definitions
- `infra/environments/prod.bicepparam` - Production infrastructure parameters
- `bicepconfig.json` - Bicep configuration

**Protections:**
- ✅ Requires pull request with 1 approval for protected paths
- ✅ Requires code owner review
- ✅ Dismisses stale reviews on push to ensure reviews remain valid after changes
- ✅ Restricts direct pushes to critical files

**Purpose:** Prevents unauthorized or accidental changes to CI/CD pipelines and critical infrastructure configurations.

### 3. Release Branch Protection (`release-branch-protection.json`)

**Applies to:** `release/*` and `hotfix/*` branches

**Protections:**
- ✅ Requires pull request with 2 approvals before merging (higher bar than main)
- ✅ Requires code owner review
- ✅ Dismisses stale reviews on push
- ✅ Requires "Validate Bicep Templates" status check to pass
- ✅ Enforces strict status check policy (must be up-to-date with base branch)
- ✅ Blocks deletion of the branch
- ✅ Blocks force pushes
- ✅ Requires linear commit history

**Purpose:** Provides extra protection for release and hotfix branches that may be deployed to production.

## Bypass Actors

All rulesets allow repository administrators (actor_id: 5) to bypass the rules in emergency situations. Use this capability responsibly.

## How to Import Rulesets

These rulesets can be imported into your GitHub repository:

1. Navigate to your repository's **Settings** → **Rules** → **Rulesets**
2. Click **New ruleset** → **Import a ruleset**
3. Select the JSON file from this directory
4. Review the settings and activate

Alternatively, use the GitHub API to programmatically import rulesets.

## Customization

To customize these rulesets for your needs:

1. Edit the JSON files in this directory
2. Adjust the `conditions.ref_name.include` patterns to match your branch naming conventions
3. Modify rule parameters to match your workflow requirements
4. Add or remove rules as needed

## Resources

- [GitHub Docs: Managing Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [GitHub Ruleset Recipes](https://github.com/github/ruleset-recipes)
- [Creating Rulesets for a Repository](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)

## Notes

- Rulesets are more flexible and powerful than classic branch protection rules
- Multiple rulesets can apply to the same branch
- Rulesets can be set to "Evaluate" mode for testing before enforcement
- Always test rulesets in a non-production environment first
