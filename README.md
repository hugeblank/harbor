# harbor
Containerizing application environment for ComputerCraft. 

## Installation:

For the standalone harbor API:
`pastebin run ivRuuLSH`

For the harbor API and a kit of tools to use it with:
`pastebin run ivRuuLSH extras`

## API Usage: 
`mountTable`: creates a fs API bound to the Harbor VFS tree passed in
- **Parameters**
  - _table_: HVFS tree
- **Returns**
  - _table_: filesystem API

`mountString`: creates a fs API bound to the serialized HVFS tree passed in
- **Parameters**
  - _string_: serialized HVFS tree
- **Returns**
  - _table_: filesystem API

`mountFile`: creates a fs API bound to the HVFS tree contained in the file passed in
- **Parameters**
  - _string_: path to a file containing a HVFS tree
- **Returns**
  - _table_: filesystem API

`convert`: generates a HVFS tree with the root starting at the path passed in
- **Parameters**
  - _string_: path to directory to be converted
- **Returns**
  - _table_: HVFS tree

`revert`: takes a fs API tied to a harbor object and converts it into a directory structure with the root being the path
- **Parameters**
  - _table_: Harbor fs API
  - _string_: Path to dump contents
- **Returns**
  - _boolean_: Whether the operation succeeded or not
