local file = require("file")

--- Re-run PostInstall if a previous build left no tmux binary.
function PLUGIN:MiseInstallSatisfied(ctx)
    if file.exists(file.join_path(ctx.path, "bin", "tmux")) then
        return true
    end
    return { satisfied = false, reason = "bin/tmux is missing" }
end
