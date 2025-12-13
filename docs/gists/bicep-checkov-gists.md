# Bicep & Checkov Command Gists

Practical everyday commands for validating and scanning infrastructure as code.

## Bicep Commands (Top 10)

### 1. Validate Main Template (Before Commit)
```bash
az bicep build --file infra/main.bicep --stdout > /dev/null
```
✅ **Use**: Pre-commit validation. Ensures syntax is correct and linting rules pass.

---

### 2. Validate All Modules
```bash
for module in infra/modules/*/*.bicep; do
  az bicep build --file "$module" --stdout > /dev/null && echo "✓ $module" || echo "✗ $module"
done
```
✅ **Use**: Batch validation of all module files. Shows which modules pass/fail.

---

### 3. Generate ARM Template from Bicep
```bash
az bicep build --file infra/main.bicep --outfile main.json
```
✅ **Use**: Create ARM template JSON for debugging or deployment review.

---

### 4. Build Parameter File to JSON
```bash
az bicep build-params --file infra/environments/dev.bicepparam --outfile dev.parameters.json
```
✅ **Use**: Generate final parameters JSON before deployment (dev/uat/prod).

---

### 5. Validate Single Module
```bash
az bicep build --file infra/modules/compute/function-app.bicep --stdout > /dev/null
```
✅ **Use**: Quick validation of a specific module after editing.

---

### 6. Build with Verbose Output (Debugging)
```bash
az bicep build --file infra/main.bicep
```
✅ **Use**: See full ARM template output for troubleshooting. Omit `--stdout` to save as JSON file.

---

### 7. Upgrade Bicep CLI
```bash
az bicep upgrade
```
✅ **Use**: Update to latest Bicep version (do before major changes).

---

### 8. Build Without Restoring External Modules
```bash
az bicep build --file infra/main.bicep --stdout --no-restore > /dev/null
```
✅ **Use**: Offline validation (skip external module downloads).

---

### 9. Validate Parameter File Syntax
```bash
az bicep build-params --file infra/environments/prod.bicepparam --outfile prod.parameters.json && echo "✓ Parameters valid"
```
✅ **Use**: Check if `.bicepparam` file is correctly formatted before deployment.

---

### 10. Build All Environments Parameters
```bash
for env in dev uat prod; do
  az bicep build-params --file infra/environments/$env.bicepparam --outfile $env.parameters.json
  echo "Generated $env.parameters.json"
done
```
✅ **Use**: Pre-generate all environment parameter files for deployment preview.

---

## Checkov Commands (Top 10)

### 1. Basic Scan of Bicep Files
```bash
checkov -d infra --framework bicep --skip-check CKV_AZURE_189
```
✅ **Use**: Everyday security scan. Skips known Checkov Bicep bug.

---

### 2. Scan with JSON Report
```bash
checkov -d infra --framework bicep --skip-check CKV_AZURE_189 -o json > checkov-report.json
```
✅ **Use**: Generate structured report for CI/CD or review.

---

### 3. Scan Specific Directory Only
```bash
checkov -d infra/modules --framework bicep --skip-check CKV_AZURE_189
```
✅ **Use**: Scan only modules (faster than full infra scan).

---

### 4. Scan Single File
```bash
checkov -f infra/main.bicep --framework bicep --skip-check CKV_AZURE_189
```
✅ **Use**: Validate specific file after changes.

---

### 5. Scan CRITICAL Severity Only
```bash
checkov -d infra --framework bicep --check-severity CRITICAL --skip-check CKV_AZURE_189
```
✅ **Use**: See only critical security issues (faster, less noise).

---

### 6. Scan and Suppress Warnings
```bash
checkov -d infra --framework bicep --skip-check CKV_AZURE_189 2>/dev/null
```
✅ **Use**: Clean output (hides error messages, shows results only).

---

### 7. Scan with Specific Checks Only
```bash
checkov -d infra --framework bicep --check CKV_AZURE_1,CKV_AZURE_2,CKV_AZURE_3
```
✅ **Use**: Run only specific security checks (e.g., compliance-related).

---

### 8. Scan and Save to CSV
```bash
checkov -d infra --framework bicep --skip-check CKV_AZURE_189 -o cli > checkov-results.txt
```
✅ **Use**: Export human-readable results to file.

---

### 9. Scan with Compact Output
```bash
checkov -d infra --framework bicep --skip-check CKV_AZURE_189 --compact
```
✅ **Use**: Minimal output, shows passed/failed counts only.

---

### 10. Scan All Frameworks (TF + Bicep)
```bash
checkov -d . --framework terraform,bicep --skip-check CKV_AZURE_189
```
✅ **Use**: Scan both Terraform and Bicep in same repository.

---

## Quick Reference: Pre-Commit Checklist

```bash
# 1. Validate Bicep
az bicep build --file infra/main.bicep --stdout > /dev/null

# 2. Run Checkov scan
checkov -d infra --framework bicep --skip-check CKV_AZURE_189 -o cli

# 3. Check all modules
for module in infra/modules/*/*.bicep; do
  az bicep build --file "$module" --stdout > /dev/null
done

# 4. Generate parameter JSONs
for env in dev uat prod; do
  az bicep build-params --file infra/environments/$env.bicepparam --outfile $env.parameters.json
done

echo "✓ All validations passed - ready to commit!"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Checkov: AttributeError on CKV_AZURE_189` | Use `--skip-check CKV_AZURE_189` in all Checkov commands |
| `Bicep: Module not found` | Ensure relative paths in `.bicep` files use `./` for local modules |
| `Build-params: bicepparam file not found` | Check file path matches environment name (dev/uat/prod) |
| `Checkov: No results` | Add `-o cli` or `-o json` to see output format |
| `Bicep: Linting warnings` | Check `bicepconfig.json` severity levels (warning vs error) |

---

## Integration with CI/CD

### GitHub Actions Example
```yaml
- name: Validate Bicep
  run: |
    az bicep build --file infra/main.bicep --stdout > /dev/null
    
- name: Run Checkov Scan
  run: |
    checkov -d infra --framework bicep --skip-check CKV_AZURE_189 -o json > checkov-results.json
    
- name: Generate Parameters
  run: |
    for env in dev uat prod; do
      az bicep build-params --file infra/environments/$env.bicepparam --outfile $env.parameters.json
    done
```

---

**Last Updated**: December 13, 2025
