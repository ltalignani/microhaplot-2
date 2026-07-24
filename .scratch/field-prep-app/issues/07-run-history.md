Type: grilling
Status: resolved

## Question

Should the app show a history/list of previously produced runs, or just
let the technician pick a run label each time with no overview?

## Answer

No history in this app. Microhaplot's own "Data Set" tab already lists
every `.rds` present in `app.path` once copied there, so the technician
sees prior runs when they open microhaplot regardless — duplicating that
view here adds complexity without a clear benefit.
