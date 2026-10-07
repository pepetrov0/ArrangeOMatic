<div align="center">
  <img src="assets/logo.svg" width="92" alt="ArrangeOMatic logo">
</div>

# ArrangeOMatic

*Packs and clusters your bag items into tidy grid blocks — bags, bank and guild bank, laid out the way your bag windows actually look.*

![World of Warcraft WotLK 3.3.5a](https://img.shields.io/static/v1?style=flat-square&label=WoW&message=WotLK%203.3.5a&color=a335ee)
![Addon version](https://img.shields.io/static/v1?style=flat-square&label=addon&message=v1.2&color=2ea043)
![Lua 5.1](https://img.shields.io/static/v1?style=flat-square&label=Lua&message=5.1&color=000080)

⭐ If you find this addon useful, star it on GitHub — it helps others discover it!

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [How it works](#how-it-works)

---

ArrangeOMatic is a lightweight organizer addon for the Wrath of the Lich King client. It draws the usable slots of your containers as grids — one per bag window with the stock Blizzard UI, or one combined grid if you use a single-window bag addon — and re-packs your items into compact blocks: several stacks of the same item stay together, single items are grouped by category, and free space is pushed out of the way: towards the bottom of each window and, in the stock UI, into your first bags — right where your newest loot tends to pile up.

> [!NOTE]
> Built for the 3.3.5a client (Interface 30300). It uses only the standard Blizzard item APIs — a single Lua file, no libraries, no dependencies.

## Features

- **Grid packing** – every group of items is laid out as a near-square block; free space always collects towards the bottom of each window.
- **Stack packing** – before arranging, partial stacks of the same item are combined — bags, bank and guild bank alike: the fullest stack is topped up from the emptiest ones, so at most one partial stack per item is left. Each merge is a regular pick-up-and-drop run through the same checks as every other move (a remainder left on the cursor goes straight back to the slot it came from), and the emptied slots count as free space right away. `/aom pack off` turns packing off, `/aom pack on` turns it back on (on by default).
- **Follows your bag layout** – two window modes, stored with your settings:
  - **`ui default`** – the stock Blizzard windows, arranged exactly as they appear: each bag is its own 4-column grid, the main bank is a 7×4 grid, bank bags are 4 columns each. Clusters that fit your largest bag go whole into the first window (in fill order) that keeps them in one block; anything larger is always split over several bags (the main bank doesn't count as a bag), with the pieces filling in the usual order — last bag first — so the main bank receives items only once every bank bag is full. The free space ends up in the backpack and your first bags: right where new loot lands.
  - **`ui single`** – all of your bags (or the whole bank) as one combined N-column grid, for single-window bag addons.
- **Bags, bank and guild bank** – the backpack, all bag slots, the bank (including bank bags) and any guild bank tab you can open. Specialized bags (quivers, herb bags, ammo pouches…) and the keyring are left untouched.
- **Smart clusters** – items occupying several slots (e.g. 8× Dreaming Glory) form one block; remaining single-stack items are grouped by type/subtype, or by broad type only — your choice.
- **Hearthstone pinned** – when arranging your bags, the Hearthstone always ends up in the first cell of the top row of the first window being filled: the top-left of your last bag with the default UI, the left end of the combined grid with a single-window bag addon.
- **Safe execution** – every move, arrangement move or stack merge alike, is verified before and after; the run aborts cleanly if something changes mid-sort instead of shuffling items around. Cancel any time with `/aom stop`.
- **Saved settings** – window mode, grid width, grouping and stack-packing settings are stored per account.

## Installation

Copy (or clone) the addon into your client's `Interface/AddOns` directory — the folder must be named exactly `ArrangeOMatic`:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── ArrangeOMatic/
            ├── ArrangeOMatic.toc
            └── ArrangeOMatic.lua
```

Then restart the client (or use `/reload` while in game). Settings are stored per account in `WTF/Account/<your account>/SavedVariables/ArrangeOMatic.lua`.

## Usage

Type in any chat input:

| Command | Description |
| --- | --- |
| `/aom` or `/arrangeomatic` | Arrange your bags |
| `/aom bank` | Arrange the bank — the bank window must be open |
| `/aom gbank` | Arrange the guild bank tab you're currently viewing |
| `/aom ui default` | Follow the stock Blizzard UI: one grid per bag window (default) |
| `/aom ui single` | Treat all of your bags as one combined grid (for single-window bag addons) |
| `/aom ui` | Show the current setting |
| `/aom columns <n>` | Set the combined-grid width to `<n>` columns (1–40, saved; default 10) — used by `ui single` only |
| `/aom groups subtype` | Group single items by type and subtype (default) |
| `/aom groups type` | Group single items by broad type only |
| `/aom pack on\|off` | Stack packing: combine partial stacks of the same item before arranging (default on) — `/aom pack` alone shows the current setting |
| `/aom stop` | Cancel an arrangement in progress |

Example session (with the default `ui` setting):

```text
/aom
ArrangeOMatic: bags: 80 slots, 5 bag windows, 21 clusters, 36 moves (4 stack merges)...
ArrangeOMatic: 25/36 moves
ArrangeOMatic: done.
```

(In `ui single` the same line reports the combined grid instead, e.g. `bags: 80 slots, 10 columns, ...`.) The figure in parentheses is how many partial stacks it will merge first; with `/aom pack off` it reads `(0 stack merges)`.

> [!NOTE]
> Stack packing needs an item's maximum stack size, which the client only knows once it has seen that item. Items whose info hasn't been cached yet are left untouched for that run — run `/aom` again and they're packed too.

> [!NOTE]
> With the default `ui` the Blizzard windows have fixed widths — 4 columns per bag, 7×4 for the main bank — so `/aom columns` has no effect there (the addon reminds you). The guild bank never uses it either: its grid width is fixed at 7 (see *How it works*).

> [!TIP]
> Using a single-window bag addon (Bagnon & friends)? Run `/aom ui single` once and set the width to match it, e.g. `/aom columns 12` — the combined grid was the addon's original behaviour and has become opt-in with this version. If the sort feels too fine-grained, `/aom groups type` produces fewer, bigger groups.

> [!IMPORTANT]
> `/aom bank` and `/aom gbank` only work while the corresponding window is open. On guild bank tabs where you lack deposit rights, moves can fail — the addon warns you up front.

## How it works

All general-purpose slots of the target container are read as **one linear list** — the backpack followed by bags 1–4, the 28 main bank slots followed by the 7 bank bags, or the 98 slots of the open guild bank tab — and mapped onto the windows you actually see (`ui default`: one grid per bag; `ui single`: one combined grid). With stack packing on, partial stacks are merged first; arranging then runs on the packed result. Every itemID occupying two or more slots forms **one cluster**, laid out as a block as close to square as possible; remaining single-stack items are grouped by category (type/subtype, or just type with `/aom groups type`), largest clusters first:

```text
bag 2 — the last bag, filled first    bag 1                 backpack — loot lands here
┌───┬───┬───┬───┐                     ┌───┬───┬───┬───┐     ┌───┬───┬───┬───┐
│ # │ p │ p │ · │                     │ h │ h │ s │ s │     │ · │ · │ · │ · │
├───┼───┼───┼───┤                     ├───┼───┼───┼───┤     ├───┼───┼───┼───┤
│ p │ p │ p │ · │                     │ h │ h │ s │ · │     │ · │ · │ · │ · │
├───┼───┼───┼───┤                     ├───┼───┼───┼───┤     ├───┼───┼───┼───┤
│ p │ p │ p │ o │                     │ · │ · │ · │ · │     │ · │ · │ · │ · │
├───┼───┼───┼───┤                     ├───┼───┼───┼───┤     ├───┼───┼───┼───┤
│ o │ o │ o │ o │                     │ · │ · │ · │ · │     │ · │ · │ · │ · │
└───┴───┴───┴───┘                     └───┴───┴───┴───┘     └───┴───┴───┴───┘

# Hearthstone (pinned)   p potion stacks   h herb stacks   s single items   · free slot
```

*(A real layout produced by the planner in `ui default`, three bags shown in fill order — last bag first. The Hearthstone is pinned to the top-left cell of the last bag; the largest clusters take it and the remaining bags in turn, and the backpack ends up empty: that's where new loot lands.)*

The plan depends only on the item counts — never on where the items currently sit — so running the command again on an already-arranged set of bags makes no moves at all. The layout is turned into a short list of two-slot swaps, executed a few per second through the standard pickup API, each verified before and after: two stacks of the same itemID are never swapped directly (the game would merge them) — they trade destinations instead. If the contents change while sorting, an item lock never clears, or the window is closed, the run aborts with a chat message — run the command again and it finishes the job. A cluster that can't sit in a window as one solid block is split as compactly as possible, with a chat note.

Guild bank tabs are drawn column by column (14 columns × 7 rows in 3.3.5a), so `/aom gbank` always uses a fixed 7-column grid, whatever your settings say.

> [!NOTE]
> The layout planner is pure Lua with zero game-API calls; `ArrangeOMatic.BuildMoves(...)` and `ArrangeOMatic.BuildMerges(...)` (the stack packing) are both exposed globally, so layouts and stack merges can be unit-tested outside the game client.
