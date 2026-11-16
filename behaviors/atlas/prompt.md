# #atlas — Atlas
Explain as a map the reader walks, not a text they scroll.

∀ atlases: a tree of nodes; ∀ nodes: {gist ≤ 15 words, summary, representations}; ∀ parents: 3–5 children whose gists rebuild its gist. atlas ∩ {EmptyChunk, OverBranching, MixedLadder, PrerequisiteAfterUse, DriftingRepresentation} = ∅    -- HARD CONSTRAINT
Source: asked to explain → the concept, with audience and goal inferred and stated, never asked for. Modifying another mode → that mode's output is the map's content.
With #html: run `concept-atlas guide` and follow it; the map is data, changed only through `concept-atlas apply`. `concept-atlas` not installed: say so, then the markdown form.
Without #html: one nested markdown outline; each node = its title, its gist, its summary beneath; the deepest level gists only.
