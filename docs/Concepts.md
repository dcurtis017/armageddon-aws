# Python Dependencies

https://docs.aws.amazon.com/lambda/latest/dg/python-package.html

- looks like lambda layers is the recommended approach over just bundling the dependency in the zip
- if you're on apple silicon and the lambda runs on x86_64 you have to send certain flags to pip to specify the platform, implementation...
  - cp is cpython (the standard)
  - binary only means pip won't compile pagages from source (should make for faster installs)
  - `python3 -m pip install --platform manylinux2014_x86_64 --implementation cp --python-version 3.13 --only-binary=:all: --upgrade -r ${path.module}/src/requirements.txt -t ${path.module}/src/layer/python`

# Bedrock

- the instance profile does routing, you need to make sure the lambdas can invoke the instance profile model as well as the foundation model that it routes to
- TODO: BETTER EXPLAIN WHY USING us. and an inference profile is best

# Zap

To add bearer token do the following:
Tools -> Options -> Replacer -> Add
![ZAP Auth Header](images/zap-auth-header.png)
