# realm-discord-spritebot

Lua script that renders sprites in the RotMG style. Can appear in a Discord server as a bot.

Only tested on Windows.

## Setup

Install Luvit and ImageMagick.

If you want to run the bot, then also install Discordia and create a file named `bot.token` and in there, write `Bot my.token` and nothing else, where `my.token` is the token of your bot account.

## Local usage

`manual.lua [file...]`

Alternativaly, drag and drop files onto `manual.bat`

Alternatively, run `shell:sendto` and create a shortcut to `"path\to\luvit.exe" -i "path\to\manual.lua"` (substituting with your paths). Name the shortcut something like `spritebot (&S)`. Right-click files, choose `Send To` and `spritebot (S)` or, assuming the accelerator key for Send To is `n`, type `ns`.

You will be asked for options. You'll have to read about them from the code for now.

## Bot usage

`bot.bat`

The file `conf.json` contains the guild and channel whitelist, outside of which the bot will not respond to anything.
