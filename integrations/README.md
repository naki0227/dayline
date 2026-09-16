# Integrations

Native and remote connector adapters live here. Connectors accept an approved
ActionProposal and return typed results. Authentication, authorization, retries,
safe logging, and external error mapping stay at this boundary.

`MacContextKit` is a local native source adapter rather than a remote connector. It
reads only completed shell-command metadata and Chrome visit metadata when the source
is explicitly enabled, then emits strict v1 ContextEvents. It never owns the Rust FFI
or database path.
