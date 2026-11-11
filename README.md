# Dockfan

Dockfan keeps several apps in one stack of the Dock. Click the stack and the
apps spread out in the Dock's own fan, with its animation, then close like any
other stack. Your Dock stays short, and a whole suite is one click away.

A Droplet for [Droppy](https://getdroppy.app), built with
[DroppyKit](https://getdroppy.app/docs/droppykit).

## What it does

- **Stacks of apps in the Dock.** Each group is a stack beside the Trash. It
  opens as a fan, a grid or a list, exactly like the Dock's own folders,
  because it is one: the animation and the way it closes are macOS's.
- **An editor for your groups.** Name a group, add apps from the Mac or drag
  them from Finder, reorder them, and see the stack in a live preview before it
  reaches the Dock.
- **Changes that land at once.** Apps you add, remove or reorder show up in a
  docked stack right away. A new name, opening, icon or order is applied with
  one click, which reloads the Dock for about a second.
- **Suggestions.** Dockfan offers ready-made groups from the suites already on
  your Mac: Adobe, Microsoft Office, Apple iWork, your browsers, the utilities.

## How to use it

1. Open Droppy's Settings, go to Dockfan's page and click **Open Dockfan**, or
   set a keyboard shortcut for it on Droppy's Shortcuts page.
2. Click **Create a group**, or start from a suggestion.
3. Add apps with **Add apps** or by dragging them from Finder, and drag the
   rows to order them. The first app sits right above the Dock and on top of
   the closed stack.
4. In **Style**, choose how the stack opens, its icon in the Dock, the order
   and whether names show “.app”.
5. Click **Add to Dock**.

To remove a stack, use **Remove from Dock** in the editor, or drag it out of
the Dock as usual: Dockfan notices.

## Settings

Dockfan's page in Droppy's Settings opens the editor and lists your groups with
whether each is in the Dock.

## Privacy

- **global-shortcuts**: an optional keyboard shortcut that opens the editor.
- Dockfan keeps its groups in its own folder in Droppy's container: a
  `groups.json` file, and one folder of Finder aliases per group, which is
  what the Dock shows.
- To put a stack in the Dock, Dockfan adds it to the Dock's preferences
  (`com.apple.dock`, `persistent-others`) and reloads the Dock. Before each
  change it keeps a copy of those preferences in its folder, the ten latest.
- Nothing leaves the Mac.
