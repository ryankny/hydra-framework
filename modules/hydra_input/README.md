# hydra_input

Modal input dialogs, confirmations, and multi-field forms. Supports text, number, password, select, checkbox, and textarea field types. One dialog at a time.

## Dependencies
- `hydra_core`
- `hydra_ui`

## API

### Hydra.Input.Show(options, cb)
Open a multi-field input dialog. `options.fields` is an array of field definitions with `type`, `label`, `name`, `placeholder`, `required`, `default`, `min`, `max`, and `options` (for select). Callback receives the result table or `nil` if cancelled.

### Hydra.Input.Confirm(title, message, cb)
Show a simple yes/no confirmation dialog. Callback receives `true` or `false`.

### Hydra.Input.Close()
Programmatically close the active dialog (triggers cancel callback).

## Exports
- `InputShow(options, cb)`
- `InputConfirm(title, message, cb)`
- `InputClose()`

## Events
- `hydra:input:show` -- Open an input dialog from another resource or server event.
- `hydra:input:result` -- Fired locally (and optionally to server) with the input result.

## Keybinds
- ESC closes the active dialog.

## Configuration
No dedicated config file. Theming is inherited from `hydra_ui`.
