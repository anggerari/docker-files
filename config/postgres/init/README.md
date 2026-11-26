Drop `*.sql`, `*.sql.gz` or `*.sh` files here to run them the **first** time the
Postgres volume is created (e.g. to create extra databases or load a seed).

They are ignored by git on purpose. To re-run them, reset the volume:
`make clean` (this deletes all data).
