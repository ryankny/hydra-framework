# hydra_loadingscreen

Customizable loading screen with manual shutdown. Displays server branding during initial game load, plays an exit animation, then hands off to the game.

## Dependencies
None (standalone resource).

## API
No exports. The loading screen runs as a `loadscreen` resource and shuts down automatically once the player session is active.

### Client
The client script waits for `NetworkIsSessionStarted()`, sends a shutdown animation message to the NUI, and calls `ShutdownLoadingScreenNui()`.

## Configuration
- `config/loadingscreen.js` -- JavaScript config object (`LOADING_CONFIG`). Customize `server.name`, background images, tips, colors, logo, and animation timing without touching HTML/CSS/JS.

## Files
- `nui/index.html`, `nui/css/loading.css`, `nui/js/loading.js`
- `nui/assets/logo.svg`
