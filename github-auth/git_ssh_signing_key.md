# GitHub Authentication - GitHub SSH Keys (Signing Key)

**NOTE:** If you came from the `[GitHub SSH Keys (Authentication Key)](https://github.com/lbrealdev/le-git/blob/master/github-auth/git_ssh_key.md) guide, proceed from the following step.

// to do

### Set up SSH keys

Generating a new SSH key:
```shell
ssh-keygen -t ed25519 -C "your_email@example.com"
```
**NOTE:** You can press enter for all prompts or configure it your way.

Add private key to the authentication agent:
```shell
ssh-add
```
**NOTE:** This step is a reference to that point in the [github documentation](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent).

Check your `~/.ssh` directory:
```shell
ls -lthr ~/.ssh
```

You should see these two files:
```txt
id_ed25519.pub
id_ed25519
```

The `id_ed25519.pub` is your public key, this is the key that must be defined in your **Github Settings** - [SSH and GPG keys](https://github.com/settings/keys).

The `id_ed25519` is your private key, once generated, you should not take any action on it, just keep it safe.

Once the new SSH keys are generated, you can add them to your Github account in the following ways:

- [Web Broser](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account?tool=webui)
- [GitHub CLI](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account?tool=cli)

### Add SSH keys via Web Browser - Signing Key

Go to [SSH and GPG keys](https://github.com/settings/keys) in Github Settings panel:


![new-ssh-key](./docs/images/new-ssh-key.jpg)


Within the Keys panel, click in [New SSH key](https://github.com/settings/ssh/new) to create a new key:


![add-new-ssh-key-signing-key](./docs/images/add-new-ssh-key-sign-key.jpg)


- In the `Title` field add a name for your SSH key, I recommend something similar to this:

>
>      Github SSH Signing Key
>

- In the `Key Type` field, select `Signing Key`.

- In the `Key` field, add the value of `~/.ssh/id_ed25519.pub`, which is something like this:

Run:
```shell
cat ~/.ssh/id_ed25519.pub
```

Public key output example:
```txt
ssh-ed25519 XXXXX your_email@example.com
```

**NOTE:** In the `Key` field we always put the value of the public key, it's something a little confusing, but it's well documented.

### Add SSH keys via GitHub CLI - Signing Key

// to do
