# Dota Duel

A custom game for DOTA 2 that allows players to have 1v1 and 2v2 duels. If you want to play Dota Duel, subscribe to it on the [Steam Workshop][0].

# Development

To install Dota Duel for development purposes, first download the [DOTA 2 Workshop Tools][1]. Then, the `game` and `content` folders should merged with the corresponding folders in your DOTA 2 install. To launch the game for testing, launch the Workshop Tools and run `dota_launch_custom_game dota_duel duel1v1` in the console.

The scripts that control the behavior of the gamemode (rounds, rematches, stat tracking, etc.) are contained in `game/dota_addons/dota_duel/scripts`. All UI code and custom assets (e.g., the map) are contained in `content/dota_addons/dota_duel/`.

# Contributing

If you have encountered a bug while playing Dota Duel or have an idea for a change or a new feature, feel free to [open an issue][2]. Pull requests are welcome as well, but any changes to the gamemode or new features should be discussed on the issue tracker first.

# License

Licensed under the Apache License version 2.0 (see LICENSE or http://www.apache.org/licenses/LICENSE-2.0).


[0]: http://steamcommunity.com/sharedfiles/filedetails/?id=933598755
[1]: https://dota2.fandom.com/wiki/Dota_2_Workshop_Tools
[2]: https://github.com/pengowen123/dota_duel/issues