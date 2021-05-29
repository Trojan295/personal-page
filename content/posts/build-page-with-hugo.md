+++
date = "2020-09-24"
title = "Build a static web page with Hugo and Amplify"
tags = [
    "static web page",
    "open source",
    "aws",
    "amplify",
    "hugo",
]
categories = [
    "Open source",
    "AWS"
]
+++

## Static website hosting

You most probably heard about static website hosting, static website generators and Github Pages or Netlify. After the boom of web technologies the backends got heavier and heavier, page loading times increased multiple times. You wanted to create a blog or portfolio website and you had to:

1. buy a server/VPS
2. buy/install a database
3. buy a domain
4. install the required backend software and configure it
5. ensure the system is patched
6. make backups

You either made this by yourself or bought a managed solution from some provider.

When the user interaction with the website is limited only to reading and only you are providing content for the website such solutions are a overkill. Inspired by the old times, when pages were only a bunch of HTML and CSS code, people created tools, where you can write the content you want to present, pick or create a theme and this gets compiled to HTML, CSS and (sometimes) Javascript.

You can store the code for your page in git, so backups are easy. As there is no server-side code execution or database, the surface for potential cyberattack is small. In this post I would like to show you, how I created this blog and hosted it using AWS Amplify. The repository for the project is [hosted on GitHub](https://github.com/Trojan295/personal-page)

## Hugo - static site generator

{{< figure
  src="/images/build-page-with-hugo/hugo-logo-wide.svg"
  target="_blank"
>}}

To manage the content and build the website I use [Hugo](https://gohugo.io/). It's a static site generator written in Golang and allows to write content in Markdown or HTML. It also has an theme engine, so you can use [themes created by other people](https://themes.gohugo.io/), extend them or prepare your own theme.

```bash
# create the project
$ hugo new site my-page
$ cd my-page
$ git init

# add 'hugo-developer-portfolio' theme
$ git submodule add https://github.com/adityatelange/hugo-PaperMod themes/papermod
echo 'theme = "papermoc"' >> config.toml
```

After you initialize the project you'll end up with a few directories and files:
- `config.toml` - Hugo configuration file. Here you defined the Hugo configuration, theme and theme parameters. You can find more information [here](https://gohugo.io/getting-started/configuration/)
- `content` - your page content, posts, etc. If you want to create a new page on your site or write a new blog post, you'll do this here
- `themes` - directory for themes
- `static` - directory for static content like images, videos, which will be served from the root path. Check [here](https://gohugo.io/content-management/static-files/) for more details
- `layouts` - directory for layouts for the pages. You store here templates for parts of the page, which Hugo fills with the content and combines together. In most cases you will use the layouts from the theme, but you can create new or override the theme provided layouts

You can find more information about the structure of the project [here](https://gohugo.io/getting-started/directory-structure/).

In my case I just picked the [PaperMod](https://themes.gohugo.io/hugo-papermod/), edited the template for the post (I wanted the share buttons on top) and adjusted the `config.toml`.

You can run a local server with hot-reload using
```bash
hugo server
```

To build the final static files run:
```bash
hugo
```
This will create a directory `public` with all the output files, which can be uploaded to a static website hosting.

## Hosting using AWS Amplify

AWS Amplify is a framework to build web and mobile apps, similar to Google Firebase. In my case I just used it's ability to host static sites and provide a simple CI/CD pipeline to deploy new static files in case a new commit is made.

So I went through [this guide](https://docs.aws.amazon.com/amplify/latest/userguide/getting-started.html) and created my Amplify app in AWS Console. Amplify automatically detected, that the repository contains an hugo project and created the `buildspec.yml` for me.

{{< figure
  src="/images/build-page-with-hugo/amplify-buildspec.png"
  link="/images/build-page-with-hugo/amplify-buildspec.png"
  target="_blank"
>}}

Right after was the pipeline started and after a few minutes my page was available.

{{< figure
  src="/images/build-page-with-hugo/amplify-build.png"
  link="/images/build-page-with-hugo/amplify-build.png"
  target="_blank"
>}}

I also added the domain I have registered in Route 53:
{{< figure
  src="/images/build-page-with-hugo/amplify-domain.png"
  link="/images/build-page-with-hugo/amplify-domain.png"
  target="_blank"
>}}

I also use the preview feature in Amplify. If a new PR is created in the source git repository, then Amplify deploys the code in a temporary environment, so you can check, if everything looks ok. What's neat, this is visible in GitHub as a PR check and you have there the link to the environment.

{{< figure
  src="/images/build-page-with-hugo/amplify-preview.png"
  link="/images/build-page-with-hugo/amplify-preview.png"
  target="_blank"
>}}

{{< figure
  src="/images/build-page-with-hugo/github-amplify-review.png"
  link="/images/build-page-with-hugo/github-amplify-review.png"
  target="_blank"
>}}

## Summary

I'm pretty happy with the experiance Hugo and Amplify provided. After you tweak the configuration of your Hugo project, you just need to write the content in Markdown and that's all. Amplify was a few-click-and-forget  My current workflow looks following:

1. Make a branch
2. Write the post
3. Create a PR
4. Check the preview environment in Amplify
5. Merge the PR
6. Check the post is available on the blog

I don't have to worry about any server maintenance, patching, database backups. The price is also low compared to buying a server ($0.15 per GB served), although I can imagine it could skyrocket, if you serve for eg. videos or large images and have a large user base.

## Read more

- [Hugo documentation](https://gohugo.io/documentation/)
- [AWS Amplify Console documentation](https://docs.aws.amazon.com/amplify/latest/userguide/welcome.html)
- [AWS Amplify documentation](https://docs.amplify.aws/)
- [Best static website hostings on Slant](https://www.slant.co/topics/2256/~best-static-website-hosting-provider)