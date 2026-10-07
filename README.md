<div align="center">
  <img src="assets/logo.svg" width="92" alt="ArrangeOMatic logo">
</div>

# ArrangeOMatic

*Packs and clusters your bag items on a tidy N-column grid — bags, bank and guild bank.*

![World of Warcraft WotLK 3.3.5a](https://img.shields.io/static/v1?style=flat-square&label=WoW&message=WotLK%203.3.5a&color=a335ee)
![Addon version](https://img.shields.io/static/v1?style=flat-square&label=addon&message=v1.0&color=2ea043)
![Lua 5.1](https://img.shields.io/static/v1?style=flat-square&label=Lua&message=5.1&color=000080)

⭐ If you find this addon useful, star it on GitHub — it helps others discover it!

[Features](#features) • [Installation](#installation) • [Usage](#usage) • [How it works](#how-it-works)

---

ArrangeOMatic is a lightweight organizer addon for the Wrath of the Lich King client. It turns all usable slots of a container into one grid and re-packs your items into compact blocks: several stacks of the same item stay together, single items are grouped by category, and free space is pushed to the bottom of the grid, right where your newest loot tends to pile up.

> [!NOTE]
> Built for the 3.3.5a client (Interface 30300). It uses only the standard Blizzard item APIs — a single Lua file, no libraries, no dependencies.

## Features

- **Grid packing** – every group of items is laid out as a near-square block; free space always collects at the bottom/front of the container.
- **Bags, bank and guild bank** – the backpack, all bag slots, the bank (including bank bags) and any guild bank tab you can open. Specialized bags (quivers, herb bags, ammo pouches…) and the keyring are left untouched.
- **Smart clusters** – items occupying several slots (e.g. 8× Dreaming Glory) form one block; remaining single-stack items are grouped by type/subtype, or by broad type only — your choice.
- **Hearthstone pinned** – when arranging your bags, the Hearthstone always ends up in the first cell of the top row, where it's easy to find.
- **Safe execution** – every move is verified before and after; the run aborts cleanly if something changes mid-sort instead of shuffling items around. Cancel any time with `/aom stop`.
- **Saved settings** – grid width and grouping mode are stored per account.

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
| `/aom columns <n>` | Set the grid width to `<n>` columns (1–40, saved; default 10) |
| `/aom groups subtype` | Group single items by type and subtype (default) |
| `/aom groups type` | Group single items by broad type only |
| `/aom stop` | Cancel an arrangement in progress |

Example session:

```text
/aom
ArrangeOMatic: bags: 80 slots, 10 columns, 21 clusters, 36 moves...
ArrangeOMatic: 25/36 moves
ArrangeOMatic: done.
```

> [!TIP]
> Using a larger bag addon? Raise the grid width to match it, e.g. `/aom columns 12`. If the sort feels too fine-grained, `/aom groups type` produces fewer, bigger groups.

> [!IMPORTANT]
> `/aom bank` and `/aom gbank` only work while the corresponding window is open. On guild bank tabs where you lack deposit rights, moves can fail — the addon warns you up front.

## How it works

All general-purpose slots of the target container are read as **one linear list** and drawn as a grid the way bag windows do it: slot 1 is the bottom-right cell, higher slots continue leftward and upward, and when the slot count isn't a multiple of N the top row is the short one, aligned to the right. Packing starts at the last slot — the left end of that top row — and advances toward the first, so empty cells end up at the bottom of the grid.

Two simple clustering rules are applied, largest cluster first:

1. every item whose itemID occupies two or more slots forms **one cluster**;
2. all remaining single-stack items are grouped into **one cluster per category** (type/subtype, or just type with `/aom groups type`).

Each cluster is then laid out as a block whose bounding box is as close to square as possible:

```text
┌───┬───┬───┬───┐
│   │ # │ p │ p │
├───┼───┼───┼───┤
│ h │ h │ p │ p │
├───┼───┼───┼───┤
│ h │ s │ s │   │
├───┼───┼───┼───┤
│   │   │   │   │
└───┴───┴───┴───┘

# Hearthstone (pinned)   p potion stacks   h herb stacks   s single items   · free slot
```

*(Illustrative layout with 4 columns.)*

The layout is turned into a short list of two-slot swaps, executed a few per second through the standard pickup API. Each swap is verified against the items that were there before, so if the contents change while sorting, an item lock never clears, or the window is closed, the run aborts with a chat message instead of guessing — just run the command again and it finishes the job. Two stacks of the same itemID are never swapped directly (the game would merge them); they trade destinations instead. If the container is too full to keep a cluster as one solid block, the addon tells you and splits it as compactly as possible.

Guild bank tabs are drawn column by column (14 columns × 7 rows in 3.3.5a), so for `/aom gbank` the grid width is fixed at 7 — one model row per window column, kept transposed — regardless of your `columns` setting.

> [!NOTE]
> The layout planner is pure Lua with zero game-API calls, and `ArrangeOMatic.BuildMoves(...)` is exposed globally, so layouts can be unit-tested outside the game client.