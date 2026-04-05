# hydra_context

Radial and list-based context menus with nested sub-menus, icons, descriptions, disabled items, and server event triggers. Single menu at a time with back-navigation stack.

## Dependencies
- `hydra_core`
- `hydra_ui`

## API

### Hydra.Context.Show(menu)
Display a context menu. `menu` contains `title`, `type` (`'list'` or `'radial'`), and `items` array. Each item can have `label`, `description`, `icon`, `disabled`, `event`, `serverEvent`, `args`, `submenu` (registered menu id), and `onSelect` callback.

### Hydra.Context.Register(id, menu) / Unregister(id)
Register or remove a named menu for quick access and sub-menu navigation.

### Hydra.Context.ShowRegistered(id)
Open a previously registered menu by its ID.

### Hydra.Context.Hide() / IsOpen()
Close the menu or check if one is open.

## Exports
- `ContextShow(menu)`, `ContextShowRegistered(id)`
- `ContextRegister(id, menu)`, `ContextUnregister(id)`
- `ContextHide()`, `IsContextOpen()`

## Keybinds
- ESC closes the menu (or navigates back if in a sub-menu).

## Configuration
No dedicated config file. Theming is inherited from `hydra_ui`.
