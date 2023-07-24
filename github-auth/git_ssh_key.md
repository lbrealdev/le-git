# Github Authentication - Github SSH Keys (Authentication Key)

### Set up SSH authentication Key

After adding a new SSH authentication key to your account on GitHub.com, you can reconfigure any local repositories to use SSH. For more information, see [Managing remote repositories](https://docs.github.com/en/get-started/getting-started-with-git/managing-remote-repositories#switching-remote-urls-from-https-to-ssh).

Generating a new SSH key:
```shell
ssh-keygen -t ed25519 -C "your_email@example.com"
```
*NOTE:* You can press enter for all prompts or configure it your way.

Add private key to the authentication agent:
```shell
ssh-add
```
*NOTE:* This step is a reference to that point in the [github documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent).

Check your `.ssh` directory:
```shell
ls -lthr $HOME/.ssh
```

You should see these two files:
```txt
id_ed25519.pub
id_ed25519
```

The `id_ed25519.pub` is your public key, this is the key that must be defined in your **Github Settings** - [SSH and GPG keys](https://github.com/settings/keys).

The `id_ed25519` is your private key, once generated, you should not take any action on it, just keep it safe.



