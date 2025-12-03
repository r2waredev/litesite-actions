# Litesite Deploy Action

A GitHub composite action for deploying static sites to the Litesite platform.

## Usage

```yaml
- name: Deploy to Litesite
  uses: reidransom/litesite-actions@v1
  with:
    api_key: ${{ secrets.LITESITE_API_KEY }}
    site: 'your-site-slug'
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api_key` | Yes | - | API key for authentication with Litesite |
| `site` | Yes | - | Site identifier (slug) |

## Outputs

| Output | Description |
|--------|-------------|
| `archive_name` | Name of the created archive |
| `s3_key` | S3 key where the archive was uploaded |

## Deployment Target

All deployments are sent to `https://r2ware.dev`.

## Example Workflow

```yaml
name: Deploy Site

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for git archive

      - name: Deploy to Litesite
        uses: reidransom/litesite-actions@v1
        with:
          api_key: ${{ secrets.LITESITE_API_KEY }}
          site: 'mysite'
```

## What It Does

1. Creates a git archive of your repository
2. Uploads the archive to S3 via pre-signed URL from the Litesite API
3. Triggers the Litesite platform to extract, build, and deploy your site
4. Provides deployment status and outputs

## Requirements

- Git repository must be initialized and have at least one commit
- Valid API key with permissions to deploy to the specified site
- Network access to https://r2ware.dev
- The runner must have `bash`, `curl`, `git`, `jq`, and `ca-certificates` installed (standard on `ubuntu-latest`)
