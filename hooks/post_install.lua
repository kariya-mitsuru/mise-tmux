local cmd = require("cmd")
local file = require("file")
local http = require("http")

-- Same defaults as the mise-plugins/mise-tmux asdf plugin.
local DEFAULT_LIBEVENT_VERSION = "2.1.12"
local DEFAULT_LIBEVENT_CONFIG = "--disable-openssl"
local DEFAULT_CONFIG = "--disable-utf8proc"

local function sh_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function opt(options, key)
    local v = options and options[key]
    if v == nil or v == "" then
        return nil
    end
    return tostring(v)
end

local function download(url, dest, work)
    print("Downloading " .. url)
    local err = http.download_file({ url = url }, dest)
    if err ~= nil then
        cmd.exec("rm -rf " .. sh_quote(work))
        error("download failed: " .. url .. ": " .. tostring(err))
    end
end

--- Downloads the tmux release tarball (and libevent unless the system one is
--- used) to a temporary directory and builds them into the install dir.
---
--- The version is a release (3.8), or "ref:<git ref>" (ref:master,
--- ref:<commit sha>) to build any branch, tag or commit from the git source,
--- which needs autoconf, automake and bison.
---
--- Tool options (mise.toml):
---   configure_options          tmux configure args (default "--disable-utf8proc")  TMUX_EXTRA_CONFIGURE_OPTIONS
---   extra_configure_options    appended after configure_options (or its default)
---   libevent_version           bundled libevent version (default "2.1.12"),
---                              or "system" to link the system libevent
---   libevent_configure_options libevent configure args (default "--disable-openssl")  LIBEVENT_EXTRA_CONFIGURE_OPTIONS
---   jobs                       make -j value (default: nproc)
function PLUGIN:PostInstall(ctx)
    local version = ctx.runtimeVersion
    local prefix = ctx.rootPath
    local options = ctx.options or {}

    local config = opt(options, "configure_options") or DEFAULT_CONFIG
    local extra = opt(options, "extra_configure_options")
    if extra then
        config = config .. " " .. extra
    end
    local libevent_version = opt(options, "libevent_version") or DEFAULT_LIBEVENT_VERSION
    local libevent_config = opt(options, "libevent_configure_options") or DEFAULT_LIBEVENT_CONFIG
    local bundle_libevent = libevent_version ~= "system"
    if bundle_libevent and not libevent_version:match("^[%d%.]+$") then
        error("libevent_version must be a version number or \"system\": " .. libevent_version)
    end

    local jobs = opt(options, "jobs")
        or cmd.exec("nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1"):match("%d+")
        or "1"
    if not jobs:match("^%d+$") then
        error("jobs must be a number: " .. jobs)
    end

    -- Note: pcall cannot wrap http.* calls in mise's Lua runtime, so cleanup
    -- is done explicitly on download errors and by a shell trap below.
    local work = cmd.exec("mktemp -d"):gsub("%s+$", "")
    local ref = version:match("^ref:(.+)$")
    local tmux_url
    if ref then
        -- tmux@ref:<branch|tag|commit>: GitHub source archive (needs autogen.sh)
        if not ref:match("^[%w%._/-]+$") then
            cmd.exec("rm -rf " .. sh_quote(work))
            error("invalid git ref: " .. ref)
        end
        tmux_url = "https://github.com/tmux/tmux/archive/" .. ref .. ".tar.gz"
    else
        tmux_url = "https://github.com/tmux/tmux/releases/download/" .. version .. "/tmux-" .. version .. ".tar.gz"
    end
    download(tmux_url, file.join_path(work, "tmux.tar.gz"), work)
    if bundle_libevent then
        download(
            "https://github.com/libevent/libevent/releases/download/release-"
                .. libevent_version .. "-stable/libevent-" .. libevent_version .. "-stable.tar.gz",
            file.join_path(work, "libevent.tar.gz"),
            work
        )
    end

    local q_prefix = sh_quote(prefix)
    local lines = {
        "set -e",
        "work=" .. sh_quote(work),
        "trap 'rm -rf \"$work\"' EXIT",
        -- run_step <log> <command...>: keep the output quiet unless it fails
        "run_step() { log=\"$work/$1\"; shift; \"$@\" >\"$log\" 2>&1 || { tail -n 50 \"$log\" >&2; exit 1; }; }",
        "cd \"$work\"",
    }
    local tmux_env = ""
    if bundle_libevent then
        print("Building libevent " .. libevent_version .. " (configure " .. libevent_config .. ")")
        table.insert(lines, "mkdir libevent && tar -xzf libevent.tar.gz -C libevent --strip-components=1")
        table.insert(lines, "cd libevent")
        table.insert(lines, "run_step libevent-configure.log ./configure --prefix=" .. q_prefix .. " " .. libevent_config)
        table.insert(lines, "run_step libevent-make.log make -j " .. jobs)
        table.insert(lines, "run_step libevent-install.log make install")
        -- libevent's helper script is not part of tmux; keep it off PATH
        table.insert(lines, "rm -f " .. q_prefix .. "/bin/event_rpcgen.py")
        table.insert(lines, "cd \"$work\"")
        local inc = sh_quote("-I" .. prefix .. "/include")
        local lib = sh_quote("-L" .. prefix .. "/lib -Wl,-rpath," .. prefix .. "/lib")
        local pkg = sh_quote(prefix .. "/lib/pkgconfig")
        tmux_env = "CFLAGS=" .. inc .. " LDFLAGS=" .. lib .. " PKG_CONFIG_PATH=" .. pkg .. " "
    end

    print("Building tmux " .. version .. " (configure " .. config .. ", make -j " .. jobs .. ")")
    table.insert(lines, "mkdir tmux && tar -xzf tmux.tar.gz -C tmux --strip-components=1")
    table.insert(lines, "cd tmux")
    if ref then
        table.insert(lines, "run_step tmux-autogen.log sh autogen.sh")
    end
    table.insert(lines, "run_step tmux-configure.log env " .. tmux_env .. "./configure --prefix=" .. q_prefix .. " " .. config)
    table.insert(lines, "run_step tmux-make.log make -j " .. jobs)
    table.insert(lines, "run_step tmux-install.log make install")
    cmd.exec(table.concat(lines, "\n"))

    if not file.exists(file.join_path(prefix, "bin", "tmux")) then
        error("build finished but bin/tmux was not installed")
    end
end
