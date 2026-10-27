# Item schema

Native items.dat version 27 contains 16,434 parsed records. The simulator dataset
contains 16,508 records. IDs from different runtime namespaces are not counts of
unique canonical items. Native records include texture coordinates, sheet name,
render/action types and clothing slot. Runtime variants retain their own IDs.
An entry in the catalogue does not establish that every item behavior is complete.
Schema/truncation/duplicate validation must pass before replacing a generation.
