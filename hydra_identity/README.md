# hydra_identity

Character creation, selection, and appearance system. Provides multi-character support with a full NUI flow for selecting, creating, customizing appearance, and deleting characters.

## Dependencies
- `hydra_core`
- `hydra_data`
- `hydra_ui`
- `hydra_players`

## API

### Client
- `Hydra.Identity.Show(data)` -- Open the identity UI with character list.
- `Hydra.Identity.Hide()` -- Close the identity UI.
- `Hydra.Identity.SwitchScreen(screen, data)` -- Navigate between `'selection'`, `'creation'`, `'appearance'`.

### NUI Callbacks
- `identity:selectCharacter` -- Select and spawn a character.
- `identity:startCreation` / `identity:submitCreation` / `identity:finishCreation`
- `identity:deleteCharacter` / `identity:backToSelection`
- `identity:changeSex` / `identity:updateAppearance` / `identity:rotatePed`

## Events
- `hydra:identity:showSelection` -- Server triggers character selection screen.
- `hydra:identity:characterLoaded` -- Character loaded, appearance applied, player spawned.
- `hydra:identity:characterCreated` / `hydra:identity:characterDeleted`
- `hydra:identity:error` -- Server reports an error to the NUI.

## Configuration
- `config/identity.lua` -- Nationalities list, creation options, max characters, spawn locations.
