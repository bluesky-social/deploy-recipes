# Atmosphere Deploy Recipes

This repo is designed for the Atmosphere community to contribute their own custom deployments for different pieces of the AT stack. We created it because over half of the pull requests we receive for the [pds](https://github.com/bluesky-social/pds/) repo are adding support for different environments that we can't commit to supporting upstream, and we wanted a central place to curate and share those!

There's lots of good writeups elsewhere on the web about PDS hosting:
- https://cprimozic.net/notes/posts/notes-on-self-hosting-bluesky-pds-alongside-other-services/
- https://benharri.org/bluesky-pds-without-docker/ 
- https://rafaeleyng.github.io/self-hosting-a-bluesky-pds-and-using-your-domain-as-your-handle
- https://char.lt/blog/2024/10/atproto-pds/
- https://whtwnd.com/fry69.dev/3lp54soakdk2d

You can use any of these as inspiration for documenting your own deployments.

Please contribute new deployments in a subdirectory of the repo root, containing your scripts plus a `README.md`. So, for example, a new recipe should include `/deploy-recipes/docker-on-arch-linux/README.md`.

## License

The deployment scripts in this repository are licensed under the Creative Commons Zero 1.0 Universal (CC-0) license. They may be copied directly in to other software projects without restriction or attribution. See `./LICENCE-CC0` for a full copy of the license text.

Note that dependencies (including AT SDKs) have their own licenses, which downstream projects need to respect.
