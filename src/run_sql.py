import sys, time, pathlib, duckdb

con = duckdb.connect("data/clickstream.duckdb")
con.execute("SET TimeZone='UTC'")
# con.execute("SET memory_limit='5GB'")   # uncomment if you have 8 GB RAM

for path in sys.argv[1:]:
    print("Running", path, "...")
    start = time.time()
    con.execute(pathlib.Path(path).read_text())
    print(f"  finished in {time.time() - start:.0f}s")