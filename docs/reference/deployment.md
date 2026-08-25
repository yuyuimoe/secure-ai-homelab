# Documentation deployment

The MkDocs site is built and deployed by `.github/workflows/docs.yml`.

## Continuous integration

Pull requests targeting `main` run:

```bash
mkdocs build --strict
```

when the documentation, MkDocs configuration, documentation dependencies or the workflow itself change. This catches broken navigation, invalid configuration and other MkDocs warnings before merge.

MkDocs is intentionally constrained to the current 1.x line in `requirements-docs.txt`:

```text
mkdocs>=1.6,<2
```

This avoids an accidental upgrade to the incompatible MkDocs 2.0 line.

## GitHub Pages deployment

After a documentation change is merged to `main`, the workflow:

1. checks out the repository;
2. installs Python and `requirements-docs.txt`;
3. runs `actions/configure-pages` to load the repository's Pages configuration;
4. builds the site into `site/` with strict validation;
5. uploads `site/` as a GitHub Pages artifact;
6. deploys the artifact to the `github-pages` environment.

The workflow can also be started manually from the **Actions** tab. Manual runs only deploy when they run against `main`.

## One-time repository setup

GitHub requires Pages to be enabled once before `actions/deploy-pages` can create a deployment.

Open **Settings → Pages** and, under **Build and deployment**, set **Source** to **GitHub Actions**.

This repository setting cannot be enabled by the workflow's standard `GITHUB_TOKEN`. GitHub's `configure-pages` action only supports automatic enablement when it is given a separate token with repository administration and Pages write permissions.

If Pages is not enabled, the deployment API returns `404 Not Found` even when the MkDocs build and Pages artifact upload succeed.

The repository is private, so GitHub Pages availability also depends on the GitHub plan used by the repository owner.

## Published URL

The MkDocs configuration uses:

```text
https://sangimed.github.io/firstmate-homelab/
```

as the site URL. After a successful deployment, GitHub also exposes the generated URL in the `github-pages` environment and under **Settings → Pages**.

## Local validation

The same strict build used in CI can be run locally:

```bash
make docs-build
```

For live preview:

```bash
make docs-serve
```
