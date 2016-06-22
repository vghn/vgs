# VGS  (UNDER DEVELOPMENT!)
  [![Circle CI](https://circleci.com/gh/vghn/vgs/tree/master.svg?style=svg)](https://circleci.com/gh/vghn/vgs/tree/master)

A collection of useful functions

## Install
- Via GIT:
```
git clone https://github.com/vghn/vgs.git ~/vgs
```
- Via GIT (as root):
```
sudo git clone https://github.com/vghn/vgs.git /opt/vgs
```
- Via WGet
```
wget -O- https://github.com/vghn/vgs/archive/master.tar.gz | tar xz
```

## Load
```
. ~/vgs/load
```

## Sample scripts
- Cron job to update every hour (10 minutes past)
```
cat << EOF > /etc/cron.d/vgs-update
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
10 * * * * root ( cd /opt/vgs && git fetch --all 2>&1 && git reset --hard origin/master 2>&1 ) | logger -it vgs-update
EOF
```

## Functions
Check the comment of each function

## Bugs
Please report any bugs to https://github.com/vghn/vgs/issues

## Contributing:
If you see how we can improve the script:
1. Open an issue to discuss proposed changes
2. Fork the repository
3. Create your feature branch: `git checkout -b my-new-feature`
4. Commit your changes: `git commit -am 'Add some feature'`
5. Push to the branch: `git push origin my-new-feature`
6. Submit a pull request :D

Guidelines:

  - Respect the style described at http://wiki.bash-hackers.org/scripting/style

  - Use [ShellCheck](http://www.shellcheck.net/about.html) to verify your code

  - Each function should be prefixed with the name of the project and script:
    `vgs_{script_name}_{function_name}`
    EX: `vgs_aws_install_cli()` (where aws.sh is the filename)

  - Each function should be documented in this format:

    ```
    # NAME: name_of_function
    # DESCRIPTION: A description of what it does
    # USAGE: name_of_function {param1} {param2}
    # PARAMETERS:
    #   1) describe each parameter (if any)
    ```

  - If the script exports a variable it should be prefixed with the name of the
    script, all in capital letters with underscores.
    EX: VGS_MY_VARIABLE; KEEP THESE TO A MINIMUM!

## License
Licensed under the Apache License, Version 2.0.
