# Contribute

[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

Bug reports and pull requests are welcome.
This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct (see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) file).

1. Open an issue to discuss proposed changes
2. Fork the repository
3. Create your feature branch: `git checkout -b my-new-feature`
4. Commit your changes: `git commit -am 'Add some feature'`
5. Push to the branch: `git push origin my-new-feature`
6. Submit a pull request :D

**Working on your first Pull Request?** You can learn how from this *free* series [How to Contribute to an Open Source Project on GitHub](https://egghead.io/series/how-to-contribute-to-an-open-source-project-on-github)

## Guidelines

- Respect the style described at <http://wiki.bash-hackers.org/scripting/style>

- Use [ShellCheck](http://www.shellcheck.net/about.html) to verify your code

- Each function should be prefixed with the name of the project and script:
  `vgs_{script_name}_{function_name}`
  EX: `vgs_aws_install_cli()` (where aws.sh is the filename)

- Each function should be documented in this format:

```sh
# NAME: name_of_function
# DESCRIPTION: A description of what it does
# USAGE: name_of_function {param1} {param2}
# PARAMETERS:
#   1) describe each parameter (if any)
```

- If the script exports a variable it should be prefixed with the name of the
  script, all in capital letters with underscores.
  EX: `VGS_MY_VARIABLE`; KEEP THESE TO A MINIMUM!
