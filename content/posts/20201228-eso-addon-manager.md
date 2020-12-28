+++
date = "2020-12-28"
title = "My simple ESO addon manager in Rust"
tags = [
    "rust",
    "rust-lang"
    "eso",
    "elder scrolls online",
    "addons",
]
categories = [
    "Gaming",
]
+++

I was missing a addon manager for ESO UI on Linux. There is [Minion](https://minion.mmoui.com/), which I tried to run in the Wine prefix of my ESO installation, but it crashed to often.

What I expected from the addon manager was:
- working on Linux
- command line interface
- easy to backup the addon configuration

So I created [eso-addons](https://github.com/Trojan295/eso-addons). It uses a single configuration file for storing the addon configuration, so I can just backup this config file and use it to restore my addons. I prebuilt binaries for Linux, Windows and MacOS, but I didn't test the Windows and MacOS ones.

You can check my config [here on GitHub](https://gist.github.com/Trojan295/a87cda19079a44762083fb2f1c672be0).
