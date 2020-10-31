+++
date = "2020-10-31"
title = "Pre-compile shader cache in Steam. How to improve performance for some games"
tags = [
    "path of exile",
    "poe",
    "linux",
    "steam",
    "shader cache",
    "precompile",
]
categories = [
    "Linux",
    "Gaming",
]
+++

In some shader heavy OpenGL and Vulkan games you can experience shuttering, when running the game for the first time. An example is Overwatch or Path of Exile.

What's happening in the first minutes of the game is shader cache pre-compilation. It's a process of compiling shader code into GPU instructions .The final cache code is dependent on the specific GPU you have, so this cannot be baked into the game files.

As said above, normally the cache is built, when running the game, but in Steam you can trigger it manually. In my case it removed the shuttering in Path of Exile.

To perform it launch Steam from the terminal using:
```bash
steam -console
```

This will open the Steam client with a new menu option next to your profile name:
{{<
    figure
    src="/images/20201031-steam-shader-precompile/steam_console.png"
    link="/images/20201031-steam-shader-precompile/steam_console.png"
>}}

There you can use the following command to trigger a shader cache pre-compilation:
```bash
shader_build <app_id>
shader_build 238960     # for Path of Exile
```

The cache is stored in `.steam/steam/steamapps/shadercache/<app_id>`. Watching the overall size of the directory can tell you, if the shaders were compiled. For Path of Exile I have currently 185 MB of cache files. **I had to launch the game and play a few minutes, before `shader_build` was able to build the cache shader files.**

```bash
$ pwd
/home/damian/.steam/steam/steamapps/shadercache/238960
$ du -lh
164M	./nvidiav1/GLCache/7dccdb8912afcd6839eeade90f7db1fc/940801954b37b742
164M	./nvidiav1/GLCache/7dccdb8912afcd6839eeade90f7db1fc
164M	./nvidiav1/GLCache
164M	./nvidiav1
8,0K	./DXVK_state_cache
22M	./fozpipelinesv4
4,0K	./fozmediav1
185M	.
```
