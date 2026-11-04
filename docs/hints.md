# Hints (progressive — try to only read as far as you need)

**Flag 1** — View page source on `/`.

**Flag 2** — A generic staff-login guess works here too; it also gets
you the download link for `relay-client`. The same password works
somewhere else too — somewhere that gives you an actual shell.

**Flag 3** — `relay` isn't reachable from outside at all — you need a
real foothold first. SSH to Web itself (same username/password as the
login page) and fetch `relay-client` from there. Run `strings` on the
binary. You'll see a magic word, some command names, and a usage
string. Try the simplest command with no extra arguments:
`./relay-client relay 9099 VERSION`.

**Flag 4** — One command needs an auth token. `strings` shows you
*something* that looks like one — read the comment near it carefully.
The real one isn't readable as plain text; `objdump -d` on the function
that builds it will show you both the obfuscation and the key.

**Flag 5** — Once you have the real token, one more command accepts a
free-form argument and does something with it server-side. Try reading
a file first, not writing one.

**Flag 6/7** — This container isn't the only one on its network, but
you can't reach the others directly — they're not published, and you
don't have a shell, only the ability to run one command at a time
through the protocol. Is there a shared filesystem path both might be
watching?

**Flag 8** — Once you're executing inside the OTHER container (not
Relay), check what's mounted that doesn't belong to a normal container
at all: `ls -la /var/run/`. If `docker` works (remember to set
`DOCKER_API_VERSION` if your client complains about version mismatch),
you don't just have this container anymore.

**Flag 9** — `docker ps` shows you what's already running. `docker run`
lets you create something that was never running before — including
with a volume mount nothing else in this box ever had.

**Flag 10** — You already found something that looked like flavor
text, back when you first got code execution on Relay. It wasn't.
