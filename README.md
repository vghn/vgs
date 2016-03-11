# VGS  (UNDER DEVELOPMENT!)
  [![Circle CI](https://circleci.com/gh/vghn/vgs/tree/master.svg?style=svg)](https://circleci.com/gh/vghn/vgs/tree/master)

A collection of useful functions

## Install
- Via GIT:
```
sudo git clone https://github.com/vghn/vgs.git /opt/vgs
. /opt/vgs/load
```

- Via WGet
```
mkdir -p /opt/vgs
wget -qO- https://s3.amazonaws.com/vghn-vgs/vgs.tgz | sudo tar xvz -C /opt/vgs
. /opt/vgs/load
```

- Sample function to load the environment or download if needed
```
load_vgs_library(){
  local vgs_path vgs_url
  vgs_url='https://s3.amazonaws.com/vghn-vgs/vgs.tgz'

  if (( ${vgs_env_loaded:-0} != 1 )); then
    if [[ $EUID == 0 ]]; then
      vgs_path='/opt/vgs'
    else
      vgs_path="${HOME}/vgs"
    fi
    if [[ ! -s "${vgs_path}/load" ]]; then
      echo 'Downloading VGS Library'
      mkdir -p "$vgs_path" && \
      wget -qO- "$vgs_url" | tar xvz -C "$vgs_path"
    fi
    # shellcheck disable=SC1090
    . "${vgs_path}/load"
  fi
}
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
