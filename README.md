# VGS

![Build Status](https://github.com/vghn/vgs/workflows/CI/badge.svg)

Vlad's collection of libraries

## Install

```sh
# Via GIT:
git clone https://github.com/vghn/vgs.git ~/vgs

# Via GIT (as root):
sudo git clone https://github.com/vghn/vgs.git /opt/vgs

# Via WGet
wget -O- https://github.com/vghn/vgs/archive/master.tar.gz | tar xz
mv ./vgs-master ~/vgs
```

## Load

```sh
# Load VGS library (https://github.com/vghn/vgs)
# shellcheck disable=1090
. "${VGS_PATH:-${HOME}/vgs}/load.sh" || { echo 'VGS library is required' >&2; exit 1; }
```

## Sample scripts

Cron job to update every hour (10 minutes past)

```sh
cat << EOF > /etc/cron.d/vgs-update
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
10 * * * * root ( cd /opt/vgs && git fetch --all 2>&1 && git reset --hard origin/master 2>&1 ) | logger -it vgs-update
EOF
```

## Functions

Check the comment of each function

## Scripts

Check the comment of each script

## Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) file.

## License

Licensed under the Apache License, Version 2.0.
See [LICENSE](LICENSE) file.
