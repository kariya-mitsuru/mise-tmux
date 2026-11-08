--- mise tool plugin: build tmux from source
PLUGIN = {}

PLUGIN.name = "tmux"
PLUGIN.version = "0.1.0"
PLUGIN.description = "Build and install tmux from source (github.com/tmux/tmux)"
PLUGIN.author = "Mitsuru Kariya"
PLUGIN.license = "MIT"
PLUGIN.homepage = "https://github.com/tmux/tmux"

-- Checked by mise before install. Missing ones are reported / installed
-- according to the `system_deps` setting.
PLUGIN.systemDependencies = {
    { bin = "cc", packages = { apt = "gcc", dnf = "gcc", zypper = "gcc", pacman = "gcc", apk = "gcc" } },
    { bin = "tar", packages = { apt = "tar", dnf = "tar", zypper = "tar", pacman = "tar", apk = "tar" } },
    { bin = "make", packages = { apt = "make", dnf = "make", zypper = "make", pacman = "make", apk = "make", brew = "make" } },
    { bin = "pkg-config", packages = { apt = "pkg-config", dnf = "pkgconf-pkg-config", zypper = "pkg-config", pacman = "pkgconf", apk = "pkgconf", brew = "pkgconf" } },
    {
        pkgconfig = "ncursesw",
        packages = {
            apt = "libncurses-dev",
            dnf = "ncurses-devel",
            zypper = "ncurses-devel",
            pacman = "ncurses",
            apk = "ncurses-dev",
            brew = "ncurses",
        },
    },
    -- Only needed with the tool option libevent_version = "system"
    -- (by default libevent is downloaded and built with tmux).
    {
        pkgconfig = "libevent_core",
        optional = "libevent_version = \"system\"",
        packages = { apt = "libevent-dev", dnf = "libevent-devel", zypper = "libevent-devel", pacman = "libevent", apk = "libevent-dev", brew = "libevent" },
    },
}
