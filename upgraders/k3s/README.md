Updates the repo directory for a k3s release

Will:
 - Download the giver k3s version or latest found
 - Create the proper dirs under k3s-VERSION/usr/ (local/lib/systemd/system/, local/lib/extension-release.d, local/bin)
 - Create the proper symlinks to the k3s binary (kubectl, ctr and crictl)
 - Create tke k3s and k3s agent service files
 - Create the extension-release file

VARS for calling the script:

 - `FORCE`: Setting this to any value will force the creation fo the dir in the root repository for the given version. Usually the script will exit if there is an existing k3s-VERSION dir, but you can force it to remove the dir and redo it from scratch.
 - `K3S_VERSION`: Set the version to download from the `k3s-io/k3s/releases` repo. If empty defaults to the latest version provided by the github release API.