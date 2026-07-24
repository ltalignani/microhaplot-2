Type: grilling
Status: resolved

## Question

After the two `.rds` files are produced, should the app hand off directly
into microhaplot (launch it in the same flow), or just report success?

## Answer

Static success message with the necessary next-step info (where the files
were written, how to open microhaplot); no automatic launch. The two apps
stay separate Shiny processes — auto-launching would mean juggling two
Shiny servers at once for limited UX gain.
