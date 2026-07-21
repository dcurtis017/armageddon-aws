# armageddon-aws

This repository is broken into labs meant to demonstrate competency in various AWS domains.

# Labs

|Lab|Title|
|12|WAF Analyzer|

# To Dos Lab 12

- [x] Produce Bad Data with Zap
- [x] Produce bad data with vpn
- [ ] Run WAF Analyzer every 10 minutes
- [ ] Run threat detection agent every 15 minutes

# To Do Lab 12a

- [ ] Create lambda for soar-response-agent
- [ ] Update threat correlation agent to put finding id in event bridge default bus
- [ ] Create event bus rule to trigger soar-response-agent lambda
- [ ] Create sns topic to send message to

# To Do General

- [ ] Try with zap and vpn set to colombia
- [ ] Separate each lambda and it's parts into separate .tf files

# Zap

To add bearer token do the following:
Tools -> Options -> Replacer -> Add
![ZAP Auth Header](images/zap-auth-header.png)

# Testing

1. Make some bad requests
1. Manually trigger WAF Analyzer
1. Manually trigger Threat Correlation Agent (this will publish to event bridge which will trigger the soar response agent)
1. check soar response agent ran
1. Manaully trigger executive dashboard agent

# Python Dependencies

https://docs.aws.amazon.com/lambda/latest/dg/python-package.html

- looks like lambda layers is the recommended approach over just bundling the dependency in the zip
- if you're on apple silicon and the lambda runs on x86_64 you have to send certain flags to pip to specify the platform, implementation...
  - cp is cpython (the standard)
  - binary only means pip won't compile pagages from source (should make for faster installs)
  - `python3 -m pip install --platform manylinux2014_x86_64 --implementation cp --python-version 3.13 --only-binary=:all: --upgrade -r ${path.module}/src/requirements.txt -t ${path.module}/src/layer/python`
