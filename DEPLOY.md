# Deploy: GitHub + Cloudflare Pages

Lean In is a static SPA (`ssr: false`). `npm run generate` builds it into **`dist/`**
(Nitro preset `cloudflare-pages-static`, pinned in `nuxt.config.js`). The output holds
`index.html`, `_nuxt/*`, `mediapipe/*` (wasm, copied from `node_modules` by `postinstall`),
`models/face_landmarker.task`, plus `_headers` and `_redirects` for Pages.

Settings at a glance:

| Setting | Value |
|---|---|
| Build command | `npm run generate` |
| Output directory | `dist` |
| Node | 22 (`.nvmrc`; or env var `NODE_VERSION=22`) |
| Install | automatic (`npm ci`; `.npmrc` sets `legacy-peer-deps=true`) |

Check locally first (optional):

```sh
npm ci
npm run generate
ls dist            # index.html _nuxt mediapipe models _headers _redirects ...
```

---

## A. Put the code on GitHub

Decide: **repo name** (e.g. `lean-in`) and **private or public**.

With the GitHub CLI:

```sh
gh auth login                      # only if `gh auth status` says the token is invalid
git switch main                    # push from main so it becomes the default branch
gh repo create lean-in --private --source . --remote origin --push
# use --public instead of --private for a public repo
```

Then push the other branches you want previews for:

```sh
git push -u origin chore/deploy
git push -u origin look/deep-sea feature/emotions feature/gestures   # when they exist
```

Without the CLI: on github.com click **New repository**, name it, choose private/public,
do **not** add a README/.gitignore/licence, then:

```sh
git remote add origin git@github.com:<you>/lean-in.git
git push -u origin main
```

---

## B. Deploy to Cloudflare Pages

### Option 1: Git integration (recommended, gives per-branch previews)

1. dash.cloudflare.com -> **Workers & Pages** -> **Create** -> **Pages** tab -> **Connect to Git**.
2. Authorise GitHub, pick the `lean-in` repo (grant access to it if it is private).
3. Build settings:
   - Production branch: `main`
   - Framework preset: **None** (or Nuxt.js, then overwrite the fields below)
   - Build command: `npm run generate`
   - Build output directory: `dist`
   - Environment variables: `NODE_VERSION` = `22` (optional, `.nvmrc` already says 22)
4. **Save and Deploy**. Production URL: `https://<project>.pages.dev`.

**Preview deployments:** every push to any other branch builds automatically and gets its
own URL, `https://<branch>.<project>.pages.dev` (slashes become dashes, e.g.
`look-deep-sea.<project>.pages.dev`, `feature-emotions.<project>.pages.dev`,
`feature-gestures.<project>.pages.dev`), plus a unique URL per commit. Control which branches
build under **Settings -> Builds & deployments -> Preview deployments**. Previews are public
by default; protect them with Cloudflare Access if needed.

### Option 2: Direct upload with Wrangler (no Git connection, no auto previews)

```sh
npm run generate
npx wrangler login                                            # opens a browser once
npx wrangler pages project create lean-in --production-branch main   # first time only
npx wrangler pages deploy dist --project-name lean-in
# preview of a branch:
npx wrangler pages deploy dist --project-name lean-in --branch look-deep-sea
```

`npx wrangler` downloads Wrangler on first use (it is not a project dependency).
A project created by direct upload cannot later be switched to Git integration; create a new
project for that.

---

## Troubleshooting

- **`Cannot read properties of null (reading 'edgesOut')` during `npm install`/`npm ci`**:
  npm 11 peer-dependency resolver bug. `.npmrc` sets `legacy-peer-deps=true`; make sure that
  file is committed. Locally you can also run `npm ci --legacy-peer-deps`.
- **Head tracking never starts, 404 on `/mediapipe/vision_wasm_internal.wasm`**: the
  `mediapipe/` folder is created by `postinstall` and is gitignored. Run `npm ci` (or
  `npm install`) before `npm run generate`; in Pages this happens automatically. If installs
  run with `--ignore-scripts`, run `npm run postinstall` by hand.
- **Camera prompt never appears / `getUserMedia` undefined**: the camera only works in a secure
  context. `*.pages.dev` and `http://localhost` are fine; a LAN IP over plain HTTP is not.
  Also check the browser's site permissions. The mouse/scroll fallback works regardless.
- **"File too large" on upload**: Pages allows 25 MiB per file and 20,000 files. The largest
  file today is `mediapipe/vision_wasm_internal.wasm` at ~12.9 MiB, 27 files / ~44 MB in total.
- **Wrong output directory / blank deploy**: the output is `dist`, not `.output/public`.
- **Old wasm or model after a deploy**: `/mediapipe/*` and `/models/*` are cached for one day
  (`public/_headers`); hard-reload, or rename the file when replacing it.
