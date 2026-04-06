return {
    -- GitHub repository (owner/repo)
    repository = 'ryankny/hydra-framework',

    -- Branch to track
    branch = 'master',

    -- Auto-update mode:
    --   'off'    = no update checks
    --   'notify' = check for updates and print to console (default)
    --   'auto'   = automatically git pull on server start if update available
    mode = 'notify',

    -- Check for updates on server start
    check_on_start = true,

    -- Periodic check interval in minutes (0 = disabled)
    -- Only applies when mode is 'notify'
    check_interval = 60,

    -- Print banner on start
    show_banner = true,
}
