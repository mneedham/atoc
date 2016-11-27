 # coding=utf-8

from neo4j.v1 import GraphDatabase, basic_auth

driver = GraphDatabase.driver("bolt://localhost", auth=basic_auth("neo4j", "neo"))
session = driver.session()

result = session.run("MATCH (s:Stop) WHERE NOT EXISTS (s.lat) RETURN s")
for record in result:
    stop_id = record["s"]["id"]
    result = session.run("""
        MATCH (s:Stop {id: {id} })

        OPTIONAL MATCH nextPath = (s)-[:NEXT|:WAIT*]->(next)
        WHERE EXISTS(NODES(nextPath)[-1].lat)

        OPTIONAL MATCH prevPath = (prev)-[:NEXT|:WAIT*]->(s)
        WHERE EXISTS(NODES(prevPath)[0].lat)

        RETURN prev, next
        LIMIT 1
    """, {"id": record["s"]["id"]})

    row = result.peek()
    if row["prev"] and not row["next"]:
        prev_location = row["prev"]
        p1 = {"latitude": prev_location["lat"] , "longitude": prev_location["lon"]}
        print row["prev"]

        session.run("""MATCH (stop:Stop {id: {id}}) SET stop.lat = {p1}.latitude, stop.lon = {p1}.longitude""",
        { "id": stop_id, "p1": p1 })
        
session.close()
