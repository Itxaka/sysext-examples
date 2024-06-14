Sysext examples


### Introduction

System extensions are a way to extend the system with additional files and directories that are mounted at boot time. System extension images may – dynamically at runtime — extend the /usr/ directory hierarchies with additional files. This is particularly useful on immutable system images where a /usr/ hierarchy residing on a read-only file system shall be extended temporarily at runtime without making any persistent modifications.


### Building system extensions

To build a system extension, you need to create a directory with the files you want to add to the system. Then you can use the `systemd-repart` tool to create a system extension image which is signed and verity protected.

```bash
$ systemd-repart -S -s SOURCE_DIR NAME.sysext.raw --private-key=PRIVATE_KEY --certificate=CERTIFICATE       
```

Note that the NAME has to match the name of the extension release. Check `k3s/v1.29.2+k3s1/usr/lib/extension-release.d/extension-release.k3s-v1.29.2+k3s1` to see the anme that the extension would need to have `k3s-v1.29.2+k3s1` in this case.


### Building the examples

```bash
$ systemd-repart -S -s k3s/v1.29.2+k3s1/ k3s-v1.29.2+k3s1.sysext.raw --private-key=PRIVATE_KEY --certificate=CERTIFICATE    
```

```bash
$ systemd-repart -S -s sbctl/0.14/ sbctl-0.14.sysext.raw --private-key=PRIVATE_KEY --certificate=CERTIFICATE    
```

### Verifying the sysextensions

You can use `systemd-dissect` to verify the sysextensions, the ID, ARCHITECTURE and the partitions that are included in the sysextension.

```bash
$ sudo systemd-dissect sbctl-0.14.sysext.raw
      Name: sbctl-0.14.sysext.raw
      Size: 21.0M
 Sec. Size: 512
     Arch.: x86-64

Image UUID: 351f0e17-35e5-42ff-bf09-8db65c756f7b
 sysext R.: ID=_any
            ARCHITECTURE=x86-64

    Use As: ✗ bootable system for UEFI
            ✗ bootable system for container
            ✗ portable service
            ✗ initrd
            ✓ sysext for system
            ✓ sysext for portable service
            ✗ sysext for initrd
            ✗ confext for system
            ✗ confext for portable service
            ✗ confext for initrd

RW DESIGNATOR      PARTITION UUID                       PARTITION LABEL        FSTYPE                AR>
ro root            4afae1e5-c73c-2f5a-acdc-3655ed91d4e0 root-x86-64            erofs                 x8>
ro root-verity     abea5f2f-214d-4d9f-83f8-ee69ca7614ba root-x86-64-verity     DM_verity_hash        x8>
ro root-verity-sig bdb3ee65-ed86-480c-a750-93015254f1a7 root-x86-64-verity-sig verity_hash_signature x8>
```