+++
date = "2020-10-19"
title = "Gaming on Linux? Is it possible in 2020?"
tags = [
    "linux",
    "gaming",
    "proton",
    "lutris",
    "glorious eggroll",
    "steam"
]
categories = [
    "Linux",
    "Gaming",
]
+++


![](/images/20201012-gaming-on-linux/header.jpg)

## Is gaming on Linux possible?

*tldr; Yes, it it! In many cases the user experience is like on Windows!*

The biggest issue I had with switching completely to a Linux based OS were games. Game studios do not really care about Linux support, as the market share for this OS is around 2%. Moreover, OpenGL, the graphics library supported in Linux, is not developer friendly, so they did not want to use it. Of course, there are some games with a native port, like the Total Wars and Tomb Raider series, but this is a minority.

Gamers tried to use compatibility layers like [Wine](https://www.winehq.org/) or [CrossOver](https://www.codeweavers.com/) to run Windows applications, but sometimes it did not work or the performance loss was too big. Thankfully, things changed with the creation of [Vulkan](https://wikipedia.org/wiki/Vulkan_(API)) and Valve's forked Wine: [Proton](https://github.com/ValveSoftware/Proton). In the meantime, an application called [Lutris](https://lutris.net/) appeared and thanks to the Linux gamer community, more and more games can be run on it with a satisfactory performance, sometimes even better!

In this article I would like to show you, how I play on Linux and present the different tools I use. At the end, you will see my benchmarks from different games, so you can develop your own opinion on this.

## Wine Is Not an Emulator

{{<
    image src="/images/20201012-gaming-on-linux/wine.png"
    class="alignleft"
>}}

The story started in 1993, when Bob Amstadt and Eric Youngdale released the first version of Wine. It is an compatibility layer for Microsoft Windows, which allows to run Windows binaries on Unix-like operating systems. What it does, it translates the Windows system calls to Unix system calls and provides various components like the registry, the directory structure and system libraries. You can think about the amount of reverse-engineering, which has been done, to create this piece of software, as Windows source code is not available publicly.

Wine uses something called **Wine prefixes** to create separate Wine configurations for the Windows components. You could ask: "Why would I need that? When I use Windows I only have one OS installation on my hard drive?". Right, but sometimes you can have conflicts between different DLL libraries or specific registry configuration. In Wine it more often became a problem, as it's only a reverse-engineered solution to create a runtime for Windows binaries. Often people had to use a specific version of some DLLs to run an applications and prefixes allow to create an isolated environment for these.

Wine is not focused on games, although it also supports translating DirectX calls into OpenGL. By the time I tried to use it for games in 2012 the results were not as great. It was hard to configure Wine and the prefixes, you had to manually add some DLLs or install some additional stuff like .NET frameworks. There was [PlayOnLinux](https://www.playonlinux.com/), which had scripts for many games and configured the Wine prefixes for you, but still, there were too many problems for me and I stayed on Windows.

## What is Proton?

{{<
    image src="/images/20201012-gaming-on-linux/protondb.svg"
    width="200px"
    class="alignleft"
    margin="10px"
>}}

Things changed a lot with Valve's contribution to the Linux community in 2017: **Proton** and **Steam Play**. According to Wikipedia, "Proton is a compatibility layer for Microsoft Windows games to run on Linux-based operating systems". Sound like Wine, right? In fact, Proton is a project forked from Wine, but focuses more on 3D graphics and sound libraries used in games. For example, it contains [dxvk](https://github.com/doitsujin/dxvk), which translates DirectX 9, 10 and 11 to Vulkan calls. Unfortunately, DirectX 12 is currently not supported, but there is work ongoing on [vkd3d](https://wiki.winehq.org/Vkd3d), which should bring DirectX 12 support.

Proton is integrated with Steam through Steam Play. It allows for a native-like experience for playing Steam games available only for Windows. Valve doesn't guarantee games will work, but from my experience most of the games do. A few examples are Skyrim, Divinity: Original Sin 2 and Monster Train, which was playable right from the release day.

On the webpage [ProtonDB](https://www.protondb.com/) you can check user reviews and ratings for the performance of games. Witcher 3, Skyrim and Elder Scrolls Online have the **Platinum** rating, which means they run perfectly out of the box with no or small differences compared to Windows. I use that page quite often before buying a new game, to verify, if I will be able to play it. It's also helpful to check the reviews, as people write, what's working, what's not and how to optimize the game.

{{<
    image src="/images/20201012-gaming-on-linux/steamplay.jpg"
    link="true"
>}}

## Glorious Eggroll

Even though Proton and SteamPlay is a huge improvement over Wine and it raised the gamer experience to an near Windows level, can be issues in some games. Valve focuses on stability and isn't shipping the latest Wine in Steam Play (currently the newest Steam included is 5.13-1), but as Proton is open source, the community is making their own patches and builds. The most popular build is [GloriousEggroll's Proton build](https://github.com/GloriousEggroll/proton-ge-custom). It's basically a Proton build with additional patches for some games and newer version of the components used in Proton.

Installing a new Proton build is very easy. You have to download the release package and put in `$HOME/.steam/root/compatibilitytools.d/`. It will automatically be available to select from a dropdown in Steam. As I'm too lazy for this, I have written a [Python script](https://gist.github.com/Trojan295/b5d2c7fe43914f49345e52b7d2570216) to manage the GE builds. :P

Why would you use the GE build? In some games the Steam included Proton has issues. I had to use Proton-5.9-GE-7-ST for Borderlands 3, because the default one does not support Media Foundation for now, which was required to play some in-game videos. You can get a frame rate increase of a few percent in some cases.

Currently on my PC I have:
- Steam included Proton builds
- Proton-5.9-GE-8-ST
- Proton-5.11-GE-3-MF
- Proton-5.6-GE-2

When running a new game, I always start with the newest Steam Proton and change only, if there are issues. In like 80% of cases "it just works™".

## Lutris

OK, Steam is a huge game library, but what about other launchers, like Battle.net, EA Origin, Epic Store Games? For this I have [Lutris](https://lutris.net/). If you remember PlayOnLinux, then Lutris is very similar. It's basically a manager and automated installer for many games.

{{<
    image src="/images/20201012-gaming-on-linux/lutris.jpg"
    link="true"
>}}

After you installed it, you can open the Lutris page for the game (let's take [ESO](https://lutris.net/games/the-elder-scrolls-online-tamriel-unlimited/) as example). There you can select one of the prepared installation modes (it could be a standalone installation, through Steam, Battle.net or other launchers). Basically people are writting installation scripts, which install the launcher, then the game, may preconfigure the Wine prefix somehow. In my experience it is not so polished like SteamPlay, but for popular games (like ESO or Overwatch) the scripts are well prepared and work out of the box. There is a comment section under each game, so if something's wrong, you can look there for help.

{{<
    image src="/images/20201012-gaming-on-linux/lutris-diablo3.jpg"
    link="true"
>}}

Lutris also supports custom Proton builds and uses the Steam directory in `$HOME/.steam/root/compatibilitytools.d/`, so you can use the same Proton builds in Steam and Lutris. In this case I also prefer the default Lutris Proton and use the GE only, if there are problems.

Through Lutris I'm playing:
- Elder Scrolls Online
- Minecraft
- Battle.net games: Overwatch and Diablo III

Special case: Epic Store Games. For this I use [https://github.com/derrod/legendary](https://github.com/derrod/legendary). It's a command line ESG replacement and works very good IMO:

```bash
# Capnip is the alias for Borderlands 3 in legendary
$ legendary install Capnip # install Borderlands 3
$ legendary launch Capnip  # run Borderlands 3
```

## Some benchmarks and comparison

To show you the differences in performance, I did a few benchmarks. The graphs compare the framerate, CPU and GPU load in Linux and Windows. For measuring the FPS I used [MangoHUD](https://github.com/flightlessmango/MangoHud) on Linux and MSI Afterburner on Windows.

My PC specs are:
- Mobo: MSI B450M MORTAR MAX
- CPU: Ryzen 7 3700X
- GPU: Palit GeForce RTX 2070 SUPER JetStream 8GB
- RAM: G.Skill Trident Z RGB, 32GB, 3600 MHz, CL16
- OS: Windows 10 and Pop_OS! 20.04

### Elder Scrolls Online, Ultra, 3440x1440p

I'm playing ESO on Lutris. It works without problems, there is a significant frame drop of around 20-30%, but the game is still enjoyable.

{{< chart id="eso_fps" title="FPS" data_file="eso_ultra_w1440p_fps" >}}
{{< chart id="eso_cpu" title="CPU load" data_file="eso_ultra_w1440p_cpu_load" ymax="100">}}
{{< chart id="eso_gpu" title="GPU load" data_file="eso_ultra_w1440p_gpu_load" ymax="100">}}

### Assassins Creed: Odyssey, Ultra, 3440x1440p

This one was surprising for me! On my PC the built-in benchmark shows 10% higher framerates on Linux! I verified the graphics setting and they were the same on both OSes. I'm not really sure how this is possible.

{{< chart id="aso_fps" title="FPS" data_file="assassins_creed_odyssey_ultra_w1440p_fps" >}}
{{< chart id="aso_cpu" title="CPU load" data_file="assassins_creed_odyssey_ultra_w1440p_cpu_load" ymax="100">}}
{{< chart id="aso_gpu" title="GPU load" data_file="assassins_creed_odyssey_ultra_w1440p_gpu_load" ymax="100">}}

### Shadow of the Tomb Raider, Ultra, 3440x1440p

This one has actually a native Linux port. When playing, I get a few more frames compared to running on Windows with DirectX 11. What I noticed here, the available display settings are different in each systems. On Linux there are no HDR and stereoscopy. IMO, nothing really important.

{{< chart id="sottr_fps" title="FPS" data_file="sottd_ultra_w1440p_fps" >}}
{{< chart id="sottr_cpu" title="CPU load" data_file="sottd_ultra_w1440p_cpu_load" ymax="100">}}
{{< chart id="sottr_gpu" title="GPU load" data_file="sottd_ultra_w1440p_gpu_load" ymax="100">}}

### Diablo III, Highest, 3440x1440p

Works without any problems, with a 20% FPS loss to Windows.
I installed Battle.net through Lutris and then Diablo III in the launcher.

{{< chart id="diablo3_fps" title="FPS" data_file="diablo_iii_ultra_w1440p_fps" >}}
{{< chart id="diablo3_cpu" title="CPU load" data_file="diablo_iii_ultra_w1440p_cpu_load" ymax="100">}}
{{< chart id="diablo3_gpu" title="GPU load" data_file="diablo_iii_ultra_w1440p_gpu_load" ymax="100">}}

### Overwatch, Epic, 3440x1440p

Like Diablo III, I installed it using Lutris. The performance is slightly better on Windows.

One thing to note is, that when you start the game it's going to compile some shaders and during that, the performance is much lower and there is a lot of clipping. You have to wait a few minutes, till this completes.

{{< chart id="ow_fps" title="FPS" data_file="overwatch_epic_w1440p_fps" >}}
{{< chart id="ow_cpu" title="CPU load" data_file="overwatch_epic_w1440p_cpu_load" ymax="100">}}
{{< chart id="ow_gpu" title="GPU load" data_file="overwatch_epic_w1440p_gpu_load" ymax="100">}}

### Company of Heroes 2, Highest, 3440x1440p

This game has a few problems, but is playable. It has a Linux native version, but you can't play multiplayer with Windows gamers as the version number is different, so I had to use SteamPlay. I also had to set the audio quality to low, as it was clipping. The game sometimes crashed for me at the begging of a match, which is annoying in multiplayer.

The framerate loss is huge, around 50%, but it's above 30 FPS, so playable for an RTS game.

{{< chart id="coh_fps" title="FPS" data_file="company_of_heroes_2_ultra_w1440p_fps" >}}
{{< chart id="coh_cpu" title="CPU load" data_file="company_of_heroes_2_ultra_w1440p_cpu_load" ymax="100">}}
{{< chart id="coh_gpu" title="GPU load" data_file="company_of_heroes_2_ultra_w1440p_gpu_load" ymax="100">}}

### DOOM, Ultra, 3440x1440p

Although DOOM hasn't a native port, it uses Vulkan as the graphics library, which explains comparable framerates on Windows and Linux. Playable without any problems.

{{< chart id="doom_fps" title="FPS" data_file="doom_ultra_w1440p_fps" >}}
{{< chart id="doom_cpu" title="CPU load" data_file="doom_ultra_w1440p_cpu_load" ymax="100">}}
{{< chart id="doom_gpu" title="GPU load" data_file="doom_ultra_w1440p_gpu_load" ymax="100">}}

### Warhammer 2: Total War

This has a native Linux port. Performance in the benchmark is similar, with a slight advantage on Windows.

{{< chart id="wh2tw_fps" title="FPS" data_file="whiitw_ultra_w1440p_fps" >}}
{{< chart id="wh2tw_cpu" title="CPU load" data_file="whiitw_ultra_w1440p_cpu_load" ymax="100">}}
{{< chart id="wh2tw_gpu" title="GPU load" data_file="whiitw_ultra_w1440p_gpu_load" ymax="100">}}

## Overall experience

In general I'm satisfied with gaming on Linux. Valve did a very good job with Proton and SteamPlay, which accelerated the progress in improving the overall gamer experience.
In addition with Proton GE and the Lutris launcher I have a very nice gaming station based on Pop_OS!. This distribution has Nvidia graphics drivers in the repository, so installing them is easy.
The performance is not the same like on Windows, the gap is in most cases a few percent, but that's OK for me.

Still, not everything is working. If you looks at the ["Fix Wanted" list on ProtonDB](https://www.protondb.com/explore?page=0&sort=fixWanted), you will see popular games like Valorant, Rainbox Six Siege, Destiny 2, PUBG and Black Desert not working. Recently GTA V broke and it was not playable for a few days. :(

Some other pain points I see:
- some anti-cheat systems do not work, especially those, which are working on the kernel level. EAC and BattleEye are not supported in Wine. Riot announced it plans to introduce a kernel-level anti-cheat system in League of Legends. In this case, without support of the developer, I don't think we can do much. Putting the compatibility issue aside: I personally don't like the idea of such low-level anti-cheat systems
- missing "gamer" software - overclocking/motherboard applications, controlling RGB, etc. For streaming there is [OBS](https://obsproject.com/). For FPS meter there is [MangoHUD](https://github.com/flightlessmango/MangoHud). Still, CPU, GPU, motherboard manufacturers don't port their apps to Linux and it's hard to control the RGB or overclock your system. Personally, I don't think they will, because the user base is too small. Hopefully the community will come up will some programs for that.

*Edit 21.10.2020: for overclocking there is [CoreCtrl](https://gitlab.com/corectrl/corectrl). Thanks [beko](https://beko.famkos.net/) for pointing me to the tool!*

If you want to try to switch to Linux, I recommend joining the Discord channel GamingOnLinux (https://discord.gg/PH66Gm) and following https://www.gamingonlinux.com/. You can seek there for help or find new mates for multiplayer games.

## Read more

- [List of Proton compatible games on Steam](https://store.steampowered.com/curator/33483305-Proton-Compatible/)
- [Linux game benchmarks](https://flightlessmango.com/)
- [ProtonDB](https://www.protondb.com/)
- [Lutris webpage](https://lutris.net/)
- [Glorious Eggroll Proton repository](https://github.com/GloriousEggroll/proton-ge-custom)