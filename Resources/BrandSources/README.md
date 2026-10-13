# Provider logos

The app bundles the provider marks so it does not download images at runtime.

- Claude: the [official Claude icon](https://claude.com/icon.png), also served by [Claude's asset CDN](https://assets.claude.com/95a868946ac8a31e5ff832e2899f294aa368b836.png).
- Codex: the OpenAI knot SVG from the [official Codex documentation](https://developers.openai.com/codex/). It matches the mark on the [Codex app icon](https://images.ctfassets.net/kftzwdyauwt9/77tJ5U1tgxHMZflZ5m4Z24/ace4d8b6ad200d87ebcb69c466344343/Blossom_4k_Icon_1.png) served on the [official Codex page](https://openai.com/codex/).

`Codex.svg` preserves the original path. The PNG in `Sources/UsageBar/Resources/Logos` is rendered at 256 pixels:

```sh
magick -background none Resources/BrandSources/Codex.svg Sources/UsageBar/Resources/Logos/Codex.png
```

The Codex image uses template rendering to match the system appearance. Claude retains its original orange color.
The names and marks belong to their respective owners.
