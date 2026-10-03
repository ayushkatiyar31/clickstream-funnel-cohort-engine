import duckdb, pathlib

con = duckdb.connect("data/clickstream.duckdb")
con.execute(pathlib.Path("sql/00_ingest_sample.sql").read_text())
print("Done")