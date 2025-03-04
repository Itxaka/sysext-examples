This repo will generate latest docker images of k3s, tailscale, slack nebula, chef habitat, pulumi esc, incus, and sbctl wtih only the components ready to be consumed as systemd-sysext ready for builder.

This can be used either with [auroraboot](https://github.com/kairos-io/AuroraBoot) to generate a signed sysext or manually by unpacking the image with [luet](https://luet.io/) and using systemd-repart to build a signed sysextension.



# Using this repo

You can see the env vars that can be set when building the images under the shared.sh file:

 - `REPOSITORY`: repository to prepend the images tags with
 - `PUSH`: whether to push the images after building them or not
 - `KEEP_FILES`: whether to keep the files after building and pushing the image. This can be used with `PUSH=false` to just build the local files and a local image. This would leave a dir with the NAME-VERSION in the root of the repo ready to be used with `systemd-repart`
 - `FORCE`: whether to force the build of the files. Normally if the script sees the directory already created, it won't proceed further as it assumes that the sysext files were already generated. This var makes it so the dir is removed and recreated from scratch. Useful if the script failed and leaved files around or the download of artifacts broke and you want to redo the process.
 - `K3S_VERSION`: k3s version to build. This defaults to the latest available if not set.
 - `SBCTL_VERSION`: sbctl version to build. This defaults to the latest available if not set.
 - `TAILSCALE_VERSION`: tailscale version to build. This defaults to the latest available if not set.
 - `NEBULA_VERSION`: nebula version to build. This defaults to the latest available if not set.
 - `PULUMI_ESC_VERSION`: Pulumi esc version to build. This defaults to the latest available if not set.
 - `HABITAT_VERSION`: Chef Habitat version to build. This defaults to the latest available if not set.
 - `HABITAT_CHANNEL`: Chef Habitat channel to build. This defaults to the stable if not set.

It has three modes of operation:
 - `KEEP_FILES=true` and `PUSH=false`: This is the default method. It will generate the files locally but not build the docker image nor push it.
 - `KEEP_FILES=true` and `PUSH=true`: This will keep the files and also build the docker image and push it.
 - `KEEP_FILES=false` and `PUSH=true`: This will generate only the docker image and push it, not leaving anything around.

Notice that having `KEEP_FILES=false` and `PUSH=false` will not do anything and exit early.

# Using the generated OCI images with auroraboot


```bash
$ docker run \
-v "$PWD"/keys:/keys \
-v "$PWD":/build/ \
-v /var/run/docker.sock:/var/run/docker.sock \
--rm \
quay.io/kairos/auroraboot:latest sysext --private-key=/keys/PRIVATE_KEY --certificate=/keys/CERTIFICATE --output=/build NAME CONTAINER_IMAGE
```

So for example, if we pushed the sbctl:0.15.4 image to ttl.sh, we could run:

```bash
$ docker run \
-v "$PWD"/keys:/keys \
-v "$PWD":/build/ \
-v /var/run/docker.sock:/var/run/docker.sock \
--rm \
quay.io/kairos/auroraboot:latest sysext --private-key=/keys/PRIVATE_KEY --certificate=/keys/CERTIFICATE --output=/build svctl-0.15.4 ttl.sh/sbctl:0.15.4
```

And that would generate a sysext in the current dir signed with our keys and ready for consumption.



# Using the generated OCI images with luet + systemd-repart


We would first unpack the artifact with luet to get the plain artifacts inside the image

```bash
luet util unpack ttl.sh/sbctl:0.15.4 /tmp/sbctl-0.15.4
```

Then use systemd-repart to generate a signed sysextension:

```bash
$ systemd-repart -S -s /tmp/sbctl-0.15.4 sbctl-0.15.4.sysext.raw --private-key=PRIVATE_KEY --certificate=CERTIFICATE
```

And that would generate a sysext in the current dir signed with our keys and ready for consumption.

# Using the generated dirs with systemd-repart

This is the easiest way as it doesnt require pushing the image anywhere or pulling it, it just uses the generated files

```bash
$ KEEP_FILES=yes ./k3s.sh
Using version v1.31.1+k3s1
Downloading k3s
Creating symlinks
Copying service files
Creating extension.release.k3s-v1.31.1+k3s1 file with reload: true
[+] Building 0.3s (5/5) FINISHED                                                         docker:default
 => [internal] load build definition from Dockerfile                                               0.0s
 => => transferring dockerfile: 59B                                                                0.0s
 => [internal] load .dockerignore                                                                  0.0s
 => => transferring context: 51B                                                                   0.0s
 => [internal] load build context                                                                  0.2s
 => => transferring context: 68.36MB                                                               0.2s
 => CACHED [1/1] COPY . /                                                                          0.0s
 => exporting to image                                                                             0.0s
 => => exporting layers                                                                            0.0s
 => => writing image sha256:2dca5ee0924a0fa77b6009c7d98b0dd1add9717da60fd375a8d4bad94bc5d1ea       0.0s
 => => naming to ttl.sh/k3s:v1.31.1_k3s1                                                           0.0s
Done

$ systemd-repart -S -s  --private-key=PRIVATE_KEY --certificate=CERTIFICATE
```
```
