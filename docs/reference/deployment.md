# Documentation deployment

The MkDocs site is built and deployed by `.github/workflows/docs.yml`.

## Continuous integration

Pull requests targeting `main` run:

```bash
mkdocs build --strict
```

when the documentation, MkDocs configuration, documentation dependencies or the workflow itself change. This catches broken navigation, invalid configuration and other MkDocs warnings before merge.

## GitHub Pages deployment

After a documentation change is merged to `main`, the workflow:

1. checks out the repository;
2. installs Python and `requirements-docs.txt`;
3. builds the site into `site/` with strict validation;
4. uploads `site/` as a GitHub Pages artifact;
5. deploys the artifact to the `github-pages` environment.

The workflow can also be started manually from the **Actions** tab. Manual runs only deploy when they run against `main`.

## One-time repository setup

GitHub Pages must use **GitHub Actions** as its publishing source:

1. open **Settings → Pages**;
2. under **Build and deployment**, set **Source** to **GitHub Actions**.

The repository is private, so GitHub Pages availability also depends on the GitHub plan used by the repository owner.

## Published URL

The MkDocs configuration uses:

```text
https://sangimed.github.io/firstmate-homelab/
```

as the site URL.

## Local validation

The same strict build used in CI can be run locally:

```bash
make docs-build
```

For live preview:

```bash
make docs-serve
```
