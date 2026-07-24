Type: grilling
Status: resolved

## Question

The VCF typically defines a reusable amplicon panel across many
campaigns/runs. Should this map decide a reuse mechanism (pick a
previously-used VCF instead of re-uploading), or is a plain `fileInput`
each run enough for now?

## Answer

Plain `fileInput` each run. A VCF-library/reuse mechanism is explicitly
deferred: the longer-term direction is a shared reference amplicon panel
used for identification/genotyping-by-comparison, where users add their
own data against that panel — a distinct, larger future feature. See the
map's "Out of scope".
