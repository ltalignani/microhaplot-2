Type: prototype
Status: open
Blocked by: 11, 12, 14

## Question

Design a UI wireframe for the full flow: folder picker (mechanism decided
in [folder-picker mechanism](11-folder-picker-mechanism.md)) → TSV/VCF
upload → upfront batch validation results (including chromosome-mismatch
reporting per
[chromosome-comparison mechanism](14-chromosome-comparison-mechanism.md))
→ extraction with a live progress bar (reflecting the async architecture
decided in [async execution architecture](12-async-execution-architecture.md))
→ success message with next-step info. English UI, no run history, no
`n.jobs` control exposed — per the decisions already recorded on the map.
Use `/prototype` to raise the fidelity of this discussion with the user
before it's considered resolved.
