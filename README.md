# VGS  (UNDER DEVELOPMENT!)
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
wget -qO- https://s3.amazonaws.com/vghn-vgs/vgs-latest.tgz | sudo tar xvz -C /opt/vgs
. /opt/vgs/load
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
    EX: VGS_MY_VARIBALE; KEEP THESE TO A MINIMUM!

## License
Licensed under the Apache License, Version 2.0.
