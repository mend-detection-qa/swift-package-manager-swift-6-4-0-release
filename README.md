# spm640-plugin-dedup-tree-structure

## Feature exercised

Tests two interacting tree-structure behaviors introduced in Swift
Package Manager 6.4.0: plugin dependency chain traversal and
duplicate-module deduplication across the merged dependency graph.

## Context

Swift Package Manager 6.4.0 changed how `swift package
show-dependencies --format json` surfaces plugin dependency subtrees.
Prior to this release the Mend Unified Agent (UA) resolver could
silently drop dependency nodes that were reachable only through a
build tool plugin or command plugin target. The 6.4.0 resolver
also clarified duplicate module resolution rules when the same module
name is exported by multiple packages (e.g. `Logging` from both
`swift-log` direct usage and a plugin's dependency).

## Dependency graph

```
PluginDedupProbe (root)
├── [main]  NIO          (swift-nio 2.65.0)
│           └── swift-atomics 1.2.0
│           └── swift-collections 1.1.4
│           └── swift-system 1.3.0
├── [main]  Logging      (swift-log 1.6.1)    ← shared (diamond leg 1)
│
├── [dev]   SwiftFormatBuildPlugin (build tool plugin target)
│           ├── swift-format 510.1.0
│           │   └── swift-syntax 600.0.1      ← transitive of swift-format
│           └── Logging (swift-log 1.6.1)     ← shared (diamond leg 2)
│
└── [dev]   NickSwiftFormatPlugin (command plugin target)
            └── SwiftFormat 0.54.3
```

Key observation: `swift-log` is reachable from two paths:
1. Directly declared as a root dependency for `NetworkLib`.
2. As a direct dependency of the `SwiftFormatBuildPlugin` target.

Mend must emit **one** `swift-log` entry, with `group: "main"`
(production wins over dev). Duplicating the entry or assigning
`group: "dev"` are both test failures.

## Expected dependency tree

See `expected-tree.json`. Key expectations:

- All 8 packages appear exactly once in the flat `packages` map.
- `swift-log` has `group: "main"` (not `"dev"`).
- `swift-format`, `swift-syntax`, `SwiftFormat` have `group: "dev"`.
- `swift-nio`, `swift-atomics`, `swift-collections`, `swift-system`
  have `group: "main"`.
- `root.dependencies` lists the 5 packages declared directly in
  `Package.swift`: `NIO`, `Logging`, `swift-format`, `SwiftSyntax`,
  `SwiftFormat`.
- `NIO` entry has `dependencies: ["Atomics", "Collections", "SystemPackage"]`
  (swift-nio's real transitive products).
- `swift-format` entry has `dependencies: ["SwiftSyntax"]`.
- `Logging` entry has `dependencies: []`.
- Plugin-only packages (`swift-format`, `SwiftSyntax`, `SwiftFormat`)
  are not surfaced as root-level direct deps to consumers — they are
  listed under `root.dependencies` only because the root Package.swift
  declared them; their `group` reflects the plugin target usage.

## Mend Unified Agent behavior under test

The UA's primary resolution path is:

```
swift package show-dependencies --format json
```

The output is a recursive `SwiftShowDependencies` tree. From Swift
6.4.0 onwards, plugin targets' subtrees appear as child nodes of the
root in that JSON. The UA's stack-based DFS must:

1. Traverse into plugin subtrees (previously optional / skipped).
2. Apply `DependencyInfoUtils.buildHierarchyTreeDeduped` to collapse
   the `swift-log` node that appears in both walks.
3. Assign `group: "dev"` to nodes reachable ONLY through plugin
   targets, and `group: "main"` to nodes reachable through any
   production target (production wins).

Probe encodes the expected CORRECT output so downstream comparison
can flag any regression.

## Mend config

Bucket A — `.whitesource` pins `swift: "6.4.0"`. SPM has no dynamic
version detection from `Package.swift`, so the toolchain must be
pinned explicitly to keep the transitive set reproducible.

`configMode: "AUTO"` — no `whitesource.config` ships with this probe.
The UA's built-in auto-detection handles `swift.resolveDependencies`.

## Probe metadata

| Field              | Value                                     |
|--------------------|-------------------------------------------|
| pattern            | spm640-plugin-dedup-tree-structure        |
| pm                 | spm                                       |
| pm_version_tested  | 6.4.0                                     |
| schema_version     | 1.2                                       |
| swift_tools_version| 6.0                                       |
| generated_at       | 2026-09-15T07:31:37Z                      |
| resolver_sha       | e54d25262b6ecc76f25c720b2f4c76bc4c7cc1a7 |
| resolver_fetched   | 2026-09-15T07:31:37Z                      |
| target             | local                                     |
