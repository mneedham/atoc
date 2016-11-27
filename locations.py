# coding=utf-8

from neo4j.v1 import GraphDatabase, basic_auth
import csv

driver = GraphDatabase.driver("bolt://localhost", auth=basic_auth("neo4j", "neo"))
session = driver.session()

query = """
with {p1} AS p1,
     {p2} AS p2
WITH p1, p2, distance(point(p1), point(p2)) / 6371000 AS δ, {f} AS f
WITH p1, p2, δ,
     sin((1-f) * δ) / sin(δ) AS a,
     sin(f * δ) / sin(δ) AS b
WITH radians(p1.latitude) AS φ1, radians(p1.longitude) AS λ1,
     radians(p2.latitude) AS φ2, radians(p2.longitude) AS λ2,
     a, b
WITH a * cos(φ1) * cos(λ1) + b * cos(φ2) * cos(λ2) AS x,
     a * cos(φ1) * sin(λ1) + b * cos(φ2) * sin(λ2) AS y,
     a * sin(φ1) + b * sin(φ2) AS z
RETURN degrees(atan2(z, sqrt(x^2 + y^2))) AS lat, degrees(atan2(y,x)) AS lon
"""

missing_locations = {}

result = session.run("MATCH (s:Stop) WHERE NOT EXISTS (s.lat) RETURN s")
for record in result:
    stop_id = record["s"]["id"]
    rows = session.run("""
        MATCH (s:Stop {id: {id} })

        OPTIONAL MATCH nextPath = (s)-[:NEXT|:WAIT*]->(next)
        WHERE EXISTS(next.lat)

        OPTIONAL MATCH prevPath = (prev)-[:NEXT|:WAIT*]->(s)
        WHERE EXISTS(prev.lat)

        WITH s, prev, next,
             reduce(acc = 0, rel in filter(r in rels(nextPath) WHERE TYPE(r) = 'NEXT') | acc + rel.time) AS nextDistance,
             reduce(acc = 0, rel in filter(r in rels(prevPath) WHERE TYPE(r) = 'NEXT') | acc + rel.time) AS prevDistance

        WITH s, prev, next, prevDistance, nextDistance
        LIMIT 1

        MATCH (s)-[:AT]->(location)
        RETURN location, s, prev, next, prevDistance, nextDistance
    """, {"id": stop_id})

    row = rows.peek()

    if row["prev"] and row["next"]:
        f = row["prevDistance"] * 1.0 / (row["prevDistance"] + row["nextDistance"])
        prev_location = row["prev"]
        next_location = row["next"]
        p1 = {"latitude": prev_location["lat"] , "longitude": prev_location["lon"]}
        p2 = {"latitude": next_location["lat"] , "longitude": next_location["lon"]}

        if p1 != p2:
            location = row["location"]

            lat_long_row = session.run(query, { "f": f, "p1": p1, "p2": p2 }).peek()
            missing_locations[location["code"]] = {"lat": lat_long_row["lat"], "lon": lat_long_row["lon"]}

session.close()

with open("data/extrapolatedLatLons.csv", "w") as locations_file:

    writer = csv.writer(locations_file, delimiter = ",")
    writer.writerow(["code","lat","lon"])

    for code in missing_locations:
        print code, missing_locations[code]
        writer.writerow([code, missing_locations[code]["lat"], missing_locations[code]["lon"]])
