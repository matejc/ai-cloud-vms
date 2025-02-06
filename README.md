# AI + NVIDIA + NixOS

This serves as a quick setup to play around with AI on NVIDIA accelerator hardware.


## Usage

### Configuration

Basic per machine configuration is stored in git-crypt encrypted vars.nix.
In the following example we have two machines with names ai1 and ai2.

```nix
{
  machines = {
    ai1 = {
      user = "admin";  # non-root, but sudo enabled user on machine
      password = "some_password";  # root and `user` password
      authorizedKeys = [  # need to set this, otherwise you are locked out!
        "ssh-ed25519 ..."
      ];
      hostname = "ai1";  # hostname set internally
      ip = "...";  # ip where the machine's sshd is accessible
      format = "amazon";  # used for image format and additional hardware configuration
    };
    ai2 = {
      user = "admin";
      password = "some_other_password";
      authorizedKeys = [
        "ssh-ed25519 ..."
      ];
      hostname = "ai2";
      ip = "...";
      format = "gce";
    };
  };
}
```

### Image (amazon)

Build image:

```shell
nix build '.#packages.x86_64-linux.ai1'
```

Push image (use your own region, profile and bucket):

```shell
aws configure sso
export AWS_REGION=eu-central-1
export AWS_PROFILE=YOUR_AWS_PROFILE
nix run github:NixOS/amis#upload-ami -- --image-info ./result/nix-support/image-info.json --s3-bucket your_s3_bucket --prefix "nixos/"
```

AWS Bucket policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "vmie.amazonaws.com"
            },
            "Action": [
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::your_s3_bucket",
                "arn:aws:s3:::your_s3_bucket/*"
            ],
            "Condition": {
                "StringEquals": {
                    "aws:SourceAccount": "585466297447"
                }
            }
        }
    ]
}
```

AWS IAM policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket",
        "ec2:ImportImage"
      ],
      "Resource": "arn:aws:s3:::your_s3_bucket/*"
    }
  ]
}
```

### Incremental deploy

#### Deployment tool (deploy-rs)


You can install [deploy-rs](https://github.com/serokell/deploy-rs) the official way, or just by:

For Linux:

```shell
nix build '.#packages.x86_64-linux.deploy-rs' -o deploy-rs
```

Or for ARM MacOS:

```shell
nix build '.#packages.aarch64-darwin.deploy-rs' -o deploy-rs
```


#### Deploy

On any change to configuration of the (example: `ai1`) machine (`vars.nix` or `configuration.nix`):

```shell
./deploy-rs/bin/deploy '.#ai1'
```

Note: this might take a while on first run, and even more on deployment machines with different architecture
