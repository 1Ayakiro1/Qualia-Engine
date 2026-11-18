# `.qwork` workspace format

`.qwork` is a portable ZIP package for a Qualia workspace. It is declarative:
it contains graph data and host-owned visibility state, but never executable
module code, credentials, process IDs, or runtime values.

## Package layout

```text
manifest.json
workspace/project.json
workspace/entities.json
workspace/variables.json
workspace/state.json
```

`manifest.json` has `format: "qualia-workspace-folder"`, `version: 1`, the
document schema version, workspace identity, and the paths above.

`workspace/project.json` is the existing version-1 `qualia-workspace` package:
it contains `project`, optional `revision`, and declarative `dependencies`.
The graph in `project` is bounded to 500 nodes, 8,000 links, and 200
annotations. Node IDs are instance IDs; module slugs are package identities.

`entities.json` is a readable index of node IDs and module metadata. It is
redundant by design and must not override `project.json`. `variables.json`
contains per-instance settings. `state.json` contains host-owned visibility
and activation preferences only.

## Validation

The read-only CLI validator checks the package without Flutter or module code:

```sh
python3 tools/validate_qwork.py workspace.qwork
python3 tools/validate_qwork.py --json workspace.qwork
```

The validator rejects unknown format/version, unsafe ZIP paths, oversized
archives, malformed JSON, duplicate/missing node IDs, unknown ports,
self-links, missing link endpoints, and graph-limit violations. Import still
performs the host-side `WorkspaceProject` validation and resolves installed
module descriptors; package metadata cannot install or execute a module.
