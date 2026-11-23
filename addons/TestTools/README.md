# Battering Ram: test tools (optional add-on)

Tools used to test Battering Ram (Blunt Leap). **Not part of the release, and not meant to stay installed**: while it is in the game, every thrown enemy's death shows a message on screen.

Needs Battering Ram 1.2.1 or later.

## What it adds

- **A message on screen for each thrown enemy's death**, about 2.5 s after it: the enemy's `#nnnnn`, how it died (for example "died from its impact (wall or ground), kill credited to V"), and what the game's loot check says.
- **Wall-kill test mode**, switched on from the CET console (`cet/cet_wall_kill_test.lua`). Every fully charged leap hit throws the enemy (alerted or not, no stagger or small-push roll) with the force you give, and leaves it with 1 health, so the wall or the ground kills it. Off by default, and off again after loading a save.
- **List of the last 10 thrown enemies that died**, from the CET console (`cet/cet_thrown_deaths.lua`).
- With "Write a log" on in Mod Settings: a "Game hit" line in the log for every hit V lands with a blunt weapon within 3 s of a stronger leap's start.

The CET lines in the main repository's `tools/` folder (`cet_body_check.lua`, `cet_set_dead.lua`) work with or without this add-on.

## Install

With the game closed, copy the folder `r6/scripts/BluntLeapTest` into the game's `r6/scripts` folder. Or unzip `BatteringRam-TestTools.zip` into the game folder (it also contains this README and the `cet` lines, which do nothing in the game folder).

## Remove

With the game closed, delete `r6/scripts/BluntLeapTest` from the game folder.

## How it hooks in

Redscript cannot add to or wrap a class that a mod defines itself. So the main mod calls a listener object (`BluntLeapTestListener`, which does nothing) at four points: the throw chance and force, a throw, and a thrown enemy's death. This add-on's own system (`BluntLeapTestSystem`) registers a listener of its own (`BluntLeapTestTools`) each time a save loads. Without the add-on, no listener is registered and nothing changes.
