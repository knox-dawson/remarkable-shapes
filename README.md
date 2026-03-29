# remarkable-scenes-ruby

Standalone Ruby repo for generating uploadable `.rmdoc` files for reMarkable tablets.

## Relationship to Drawj2d

The Java repo `remarkable-scenes` contains:

- `ReMarkablePage.java`
- `ReMarkableAPIrmdoc.java`

Those started as code derived from the Drawj2d-side writer classes, but they now live in your own repo and are independent from future Drawj2d changes.

That means:

- yes, your Java repo is independent of Drawj2d for `.rm` / `.rmdoc` generation
- yes, you can use your own repo instead of Drawj2d for this work

This Ruby repo takes the same approach:

- it is self-contained
- it does not require Drawj2d
- it owns its own `.rm` and `.rmdoc` writing logic

## Layout

- `lib/remarkable/io`
  low-level `.rm` and `.rmdoc` writing
- `lib/remarkable/shapes`
  reusable drawing helpers
- `lib/remarkable/scenes`
  named scenes
- `bin/generate_scene`
  generic scene-name runner

## Run

```bash
cd /home/bmb/rmlines_research/remarkable-scenes-ruby
ruby bin/generate_scene --help
ruby bin/generate_scene us-flag out/us-flag.rmdoc
ruby bin/generate_scene greenland-flag out/greenland-flag.rmdoc
ruby bin/generate_scene shape-sampler out/shape-sampler.rmdoc
```

## Why Ruby may fit you better

If your main task is:

- define reusable geometry helpers
- write small scene scripts
- generate output files

then Ruby is a reasonable fit. It is less ceremony-heavy than Java for this kind of scripting work.

The main tradeoff is that you lose the benefit of reusing Java classes from Drawj2d directly, but since you asked for independence from Drawj2d, that is acceptable here.

