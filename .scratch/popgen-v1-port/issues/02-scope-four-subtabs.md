Type: grilling
Status: resolved

## Question

Should all 4 core sub-tabs (F-statistics, Allelic diversity, PCA/
Projection, Outlier scan) be in scope for this map together, or should the
map prioritize/sequence a subset first (e.g. F-statistics + Allelic
diversity, which share the same hierfstat computation)?

## Answer

All 4 in scope together — the structural decisions this map is charting
(data source mapping, UI/layout translation, dependencies) apply
identically to all 4, so there's no benefit to splitting them at the
decision level. A suggested implementation rollout order can be documented
later in `/to-tickets`, not decided on this map.
