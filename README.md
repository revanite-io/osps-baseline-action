# GitHub Action for OSPS Baseline

This repo provides a GitHub Action for running OSPS (Open Source Project Security) Baseline assessments on your GitHub repository. This action evaluates your repository against security controls defined in the [Open Source Project Security Baseline](https://baseline.openssf.org) and can optionally upload results to GitHub's Security tab as SARIF files.

## Features

- Automated security assessments against OSPS Baseline controls
- Multiple output formats: YAML, JSON, or SARIF
- Direct integration with GitHub Security tab via SARIF upload

## Results

<img width="720" height="512" alt="image" src="https://github.com/user-attachments/assets/1c5c0f6e-9f06-40cc-8fc9-a72b3f01d3a7" />

## Usage

### Basic Example

```yaml
name: OSPS Security Assessment

on:
  schedule:
    - cron: "0 9 * * 1"  # Weekly on Mondays at 9 AM UTC
  workflow_dispatch:  # Allow manual triggering

jobs:
  osps-assessment:
    runs-on: ubuntu-latest
    
    permissions:
      contents: read
      security-events: write  # Required for SARIF upload
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Open Source Project Security Baseline Scanner
        uses: revanite-io/osps-baseline-action@v1.0.0
        with:
            owner: ${{ github.repository_owner }}
            repo: ${{ github.event.repository.name }}
            token: ${{ secrets.PVTR_GITHUB_TOKEN }}
            catalog: "osps-baseline"
            upload-sarif: "true"
      
      - name: Upload Assessment Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: osps-assessment-results-${{ github.run_number }}
          path: evaluation_results/
          retention-days: 30
```

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `owner` | Repository owner (organization or user) | Yes | - |
| `repo` | Repository name | Yes | - |
| `token` | GitHub Personal Access Token with repo read permissions | Yes | - |
| `output-format` | Output format (`yaml`, `json`, or `sarif`) | No | `yaml` |
| `upload-sarif` | Upload results as SARIF to GitHub Security tab. When `true`, `output-format` is automatically set to `sarif` | No | `false` |

## Requirements

Your GitHub Personal Access Token needs **repository read permissions**. For public repositories, you can use the `repo` scope, or `public_repo` for public repos only. An additional check for multi-factor authentication will run if your token includes `admin:org` permissions.

### Creating a PAT

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate a new token with `repo` scope (or `public_repo` for public repositories)
3. Add the token as a secret in your repository (Settings → Secrets and variables → Actions)
4. Reference it by name in your workflow, such as `${{ secrets.PVTR_GITHUB_TOKEN }}`

## Output Formats

- **YAML (Default)**: Human-readable format, suitable for local review and CI/CD pipelines
- **JSON**: Machine-readable format, useful for programmatic processing and integration with other tools
- **SARIF**: Static Analysis Results Interchange Format, connects results to GitHub's Security tab

## FAQ

### Q: Can I use `GITHUB_TOKEN` instead of a Personal Access Token?

**A:** Unfortunately, no. For running the OSPS plugin against public repositories, the builtin CI token does not have access to make API calls.

### Q: Why isn't my SARIF file uploading to the Security tab?

**A:** There are several common reasons:

1. **Missing permissions**: Ensure your workflow includes `security-events: write` permission. Organization-level settings may also restrict security event uploads.
2. **Invalid SARIF format**: The action validates the SARIF file before upload. Check the workflow logs for any errors produced by the plugin
3. **Plugin crash:** Because of the reliance on API calls to collect data, the plugin occasionally encounters an error and needs to be re-run
4. **User Permissions**: If you are not authorized to view the security tab, it may have uploaded without your knowledge.

### Q: What if I get permission errors when accessing files?

**A:** The action automatically fixes file permissions after the Docker container runs. If you still encounter permission issues:

- Ensure the workflow has write access to the workspace
- Check that the `evaluation_results` directory is created and writable
- Review the workflow logs for specific permission error messages

### Q: Can I customize the maturity level being assessed?

**A:** Currently, the action assesses against "Maturity Level 1" by default. This is hardcoded in the action because higher maturity levels do not currently produce high-confidence results from the `pvtr-github-repo` plugin. You can use the plugin directly to access any assessments that are available.

### Q: How do I troubleshoot a failed assessment?

**A:** Follow these steps:

1. **Check workflow logs**: Review the full workflow output for error messages
2. **Verify token permissions**: Ensure your token has the required repository read access
3. **Check repository accessibility**: Confirm the repository exists and is accessible with the provided token
4. **Review artifact uploads**: Download and inspect the `evaluation_results` artifact for detailed logs
5. **Validate configuration**: Ensure all required inputs are provided correctly

## Contributing

Contributions are welcome! Please see our contributing guidelines for more information.

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [Privateer](https://github.com/privateerproj/privateer) - The core assessment engine
- [Gemara](https://github.com/ossf/gemara) - OSPS Baseline control definitions
- [OSPS Baseline](https://baseline.openssf.org) - Open Source Project Security Baseline specification
