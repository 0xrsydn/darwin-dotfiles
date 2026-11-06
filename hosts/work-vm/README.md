# work-vm

A NixOS machine in OrbStack on the MacBook. The Cloudflare One client, Docker
and work repos live here, so company traffic and code stay off macOS.

```
Mac
├─ terminal / editor ──ssh──▶ work-vm@orb   (tmux, editors, git, docker)
├─ work-browser ──SOCKS──▶ work-vm.orb.local:1080 ──Cloudflare One──▶ company
└─ http://work-vm.orb.local:<port> ◀── dev servers in the VM
```

## Create (once)

```bash
orb create nixos work-vm
# OrbStack writes /etc/nixos/orbstack.nix; hosts/work-vm/orbstack.nix is a copy.
orb -m work-vm nixos-rebuild switch --sudo --flake ~/Development/dotfiles#work-vm
```

The flake only sees files that git tracks, so `git add` new files before
rebuilding.

## Update

Edit the flake on the Mac, then rerun the `nixos-rebuild` command above.

## Enroll the Cloudflare One client (once)

```bash
orb -m work-vm
warp-cli --accept-tos registration new <team-name>   # prints a login URL
```

1. Open the URL in a Mac browser and sign in with company SSO.
2. On the success page, copy the `com.cloudflare.warp://...` link instead of
   opening it.
3. Finish the enrollment and connect:

```bash
warp-cli registration token "com.cloudflare.warp://..."
warp-cli connect
warp-cli status              # expect: Connected
warp-cli registration show   # expect: the company team name
```

The company's "clean restart" step maps to `orb restart work-vm`.

## Git identity (once)

The repo is public, so the work identity stays inside the VM:

```bash
git config --file ~/.config/git/work-identity user.name  "<name>"
git config --file ~/.config/git/work-identity user.email "<work email>"
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519   # add the .pub to GitLab
```

Keep repos under `~/code` on the VM's own disk, not under `/Users`.

## Browse company sites

Run `work-browser` on the Mac. It opens a separate Brave profile
(`~/.local/share/brave-work`) that sends traffic and DNS through the VM.

## Forward Mac tools through the VM

The VM's SOCKS proxy accepts connections from the Mac only (firewall rule on
OrbStack's host address `192.168.139.3`). Docker containers on the Mac are
refused, so they cannot reach the company network.

- One command: `work-proxy curl https://internal.example.com`. It sets
  `ALL_PROXY`/`HTTPS_PROXY` to `socks5h://work-vm.orb.local:1080`. curl, git
  over HTTPS and Go programs honor it; Node `fetch` and Python `requests` do not.
- SSH to company servers: add a block to `~/.ssh/config` (not this public
  repo, so internal hostnames stay private):

  ```
  Host *.internal.example.com
    ProxyJump work-vm@orb
  ```

- A GUI tool without proxy support (pgAdmin, DBeaver):
  `ssh -N -L 5432:db.internal.example.com:5432 work-vm@orb`, then connect to
  `localhost:5432`.

Never share the proxy beyond this Mac (for example over Tailscale).

## Known limits

- OrbStack machines share a kernel with OrbStack's Docker, mount the Mac home
  folder, and can run Mac commands through `mac`. This is not strong isolation.
- `/etc/resolv.conf` is managed by OrbStack. If the client cannot set DNS after
  `warp-cli connect`, that is the first place to look.
