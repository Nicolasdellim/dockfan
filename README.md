# GroupDock

Say what GroupDock does in two or three sentences, for someone deciding whether to install it.

A Droplet for [Droppy](https://getdroppy.app), built with
[DroppyKit](https://getdroppy.app/docs/droppykit).

## What it does

- **The main thing.** Where it shows up (the shelf, beside the notch, its page
  in Droppy's Settings) and what the person sees there.
- **The next thing.** One bullet per feature, in the words of the person using
  it rather than the words of the code.

## How to use it

1. Open the shelf, press the grid button and pick GroupDock.
2. The next step, if there is one, such as what to set up first and where.

## Settings

What each setting on GroupDock's page in Droppy's Settings changes. Leave
this section out when there is nothing to set.

## Privacy

Why it needs each capability in `droplet.json`, what it stores and where, and
what leaves the Mac, if anything, and to whom. When nothing leaves the Mac, say
so.

## Credits

Code, artwork, sounds or data you did not make yourself: whose it is, its
licence and a link. Leave this section out when everything is yours.

## Developing

With the [DroppyKit](https://gitlab.com/droppyformac1/droppykit) scripts on
your `PATH`:

```bash
droppykit run        # open it in the development harness
droppykit build      # produce .build/Groupdock.droplet
droppykit validate   # the checks the Store runs
```

## License

MIT.
