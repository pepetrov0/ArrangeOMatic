<div align="center">
  <img src="assets/logo.svg" width="92" alt="ArrangeOMatic logo">
</div>

# ArrangeOMatic

*Packs and clusters your bag items into tidy grid blocks — bags, bank and guild bank, laid out the way your bag windows actually look.*

![World of Warcraft WotLK 3.3.5a](https://img.shields.io/static/v1?style=flat-square&label=WoW&message=WotLK%203.3.5a&color=a335ee)
![Addon version](https://img.shields.io/static/v1?style=flat-square&label=addon&message=v1.1&color=2ea043)
![Lua 5.1](https://img.shields.io/static/v1?style=flat-square&label=Lua&message=5.1&color=000080)

⭐ If you find this addon useful, star it on GitHub — it helps others discover it!

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [How it works](#how-it-works)

---

ArrangeOMatic is a lightweight organizer addon for the Wrath of the Lich King client. It draws the usable slots of your containers as grids — one per bag window with the stock Blizzard UI, or one combined grid if you use a single-window bag addon — and re-packs your items into compact blocks: several stacks of the same item stay together, single items are grouped by category, and free space is pushed out of the way: towards the bottom of each window and, in the stock UI, into your first bags — right where your newest loot tends to pile up.

> [!NOTE]
> Built for the 3.3.5a client (Interface 30300). It uses only the standard Blizzard item APIs — a single Lua file, no libraries, no dependencies.

## Features

- **Grid packing** – every group of items is laid out as a near-square block; free space always collects towards the bottom of each window.
- **Follows your bag layout** – two window modes, stored with your settings:
  - **`ui default`** – the stock Blizzard windows, arranged exactly as they appear: each bag is its own 4-column grid, the main bank is a 7×4 grid, bank bags are 4 columns each. Clusters that fit your largest bag go whole into the first window (in fill order) that keeps them in one block; anything larger is always split over several bags (the main bank doesn't count as a bag), with the pieces filling in the usual order — last bag first — so the main bank receives items only once every bank bag is full. The free space ends up in the backpack and your first bags: right where new loot lands.
  - **`ui single`** – all of your bags (or the whole bank) as one combined N-column grid, for single-window bag addons.
- **Bags, bank and guild bank** – the backpack, all bag slots, the bank (including bank bags) and any guild bank tab you can open. Specialized bags (quivers, herb bags, ammo pouches…) and the keyring are left untouched.
- **Smart clusters** – items occupying several slots (e.g. 8× Dreaming Glory) form one block; remaining single-stack items are grouped by type/subtype, or by broad type only — your choice.
- **Hearthstone pinned** – when arranging your bags, the Hearthstone always ends up in the first cell of the top row of the first window being filled: the top-left of your last bag with the default UI, the left end of the combined grid with a single-window bag addon.
- **Safe execution** – every move is verified before and after; the run aborts cleanly if something changes mid-sort instead of shuffling items around. Cancel any time with `/aom stop`.
- **Saved settings** – window mode, grid width and grouping mode are stored per account.

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
| `/aom stop` | Cancel an arrangement in progress |

Example session (with the default `ui` setting):

```text
/aom
ArrangeOMatic: bags: 80 slots, 5 bag windows, 21 clusters, 36 moves...
ArrangeOMatic: 25/36 moves
ArrangeOMatic: done.
```

(In `ui single` the same line reports the combined grid instead, e.g. `bags: 80 slots, 10 columns, ...`.)

> [!NOTE]
> With the default `ui` the Blizzard windows have fixed widths — 4 columns per bag, 7×4 for the main bank — so `/aom columns` has no effect there (the addon reminds you). The guild bank never uses it either: its grid width is fixed at 7 (see *How it works*).

> [!TIP]
> Using a single-window bag addon (Bagnon & friends)? Run `/aom ui single` once and set the width to match it, e.g. `/aom columns 12` — the combined grid was the addon's original behaviour and has become opt-in with this version. If the sort feels too fine-grained, `/aom groups type` produces fewer, bigger groups.

> [!IMPORTANT]
> `/aom bank` and `/aom gbank` only work while the corresponding window is open. On guild bank tabs where you lack deposit rights, moves can fail — the addon warns you up front.

## How it works

All general-purpose slots of the target container are read as **one linear list** — the backpack followed by bags 1–4, or the 28 main bank slots followed by the 7 bank bags — and that list is then mapped onto the windows you actually see. The mapping depends on `/aom ui`:

- **`ui default`** (the default) – the list is split back into its bags and **each window is drawn as its own grid**, with a cluster never straddling two windows. The window geometry matches the 3.3.5a Blizzard frames exactly: inventory bags are 4 columns with the last slot in the bottom-right cell and slot 1 at the top-left of a short, right-aligned top row (i.e. slots read left-to-right, top-to-bottom — the opposite way round to the combined grid below); the main bank is its own 7×4 grid with slot 1 top-left, and bank bags are drawn like inventory bags. Clusters are handed out largest cluster first: a cluster that fits the largest bag goes whole into the first window in fill order that still keeps it as one solid block (or, if none can, into the window where it fits cleanest); a cluster larger than the largest bag is **always split** over several bags — the main bank doesn't count when working out the largest bag, so a group of 25 items is broken up instead of sitting whole in the 28-slot main bank. The pieces fill the bags in the usual fill order (last bag first; the main bank only receives pieces once every bank bag is full), staying in the bags they already sit in where possible for fewer moves. Since the fill order runs back to front, the free space ends up in the backpack and your first bags — or, on the bank, the main bank: exactly where newly looted items land. Each window is then packed from the top-left, so free cells collect at the bottom of each window.
- **`ui single`** – the list is drawn as **one grid with N columns** the way single-window bag addons draw it: slot 1 is the bottom-right cell, higher slots continue leftward and upward, and when the slot count isn't a multiple of N the top row is the short one, aligned to the right. Packing starts at the last slot — the left end of that top row — and advances toward the first, so empty cells end up at the bottom/front of the combined grid. (In this mode the bank forms one grid too: the 28 main slots and the 7 bank bags share it.) This was the addon's original mode.

Because the assignment of clusters to windows depends only on the item counts — never on where items currently sit — running the command again on an already-arranged set of bags makes no moves at all.

Two simple clustering rules are applied, largest cluster first:

1. every item whose itemID occupies two or more slots forms **one cluster**;
2. all remaining single-stack items are grouped into **one cluster per category** (type/subtype, or just type with `/aom groups type`).

Each cluster is then laid out as a block whose bounding box is as close to square as possible:

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

The layout is turned into a short list of two-slot swaps, executed a few per second through the standard pickup API. Each swap is verified against the items that were there before, so if the contents change while sorting, an item lock never clears, or the window is closed, the run aborts with a chat message instead of guessing — just run the command again and it finishes the job. Two stacks of the same itemID are never swapped directly (the game would merge them); they trade destinations instead. If the container is too full to keep a cluster as one solid block, the addon tells you and splits it as compactly as possible.

Guild bank tabs are drawn column by column (14 columns × 7 rows in 3.3.5a), so for `/aom gbank` the grid width is fixed at 7 — one model row per window column, kept transposed — regardless of your settings.

> [!NOTE]
> The layout planner is pure Lua with zero game-API calls, and `ArrangeOMatic.BuildMoves(...)` is exposed globally, so layouts can be unit-tested outside the game client.
