--- No url is returned: mise downloads nothing and PostInstall builds from source.
--- (Extracting the source straight into the install dir would leave the build
--- tree mixed with the installed files.)
function PLUGIN:PreInstall(ctx)
    return { version = ctx.version }
end
