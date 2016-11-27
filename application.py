#!/usr/bin/env python
# -*- encoding: utf-8 -*-

from bottle import get, run, static_file, template
from neo4j.v1 import GraphDatabase, basic_auth

driver = GraphDatabase.driver("bolt://localhost", auth=basic_auth("neo4j", "neo"))

@get('/css/<filename:re:.*\.css>')
def get_css(filename):
    return static_file(filename, root="static", mimetype="text/css")


@get('/images/<filename:re:.*\.png>')
def get_image(filename):
    return static_file(filename, root="static", mimetype="image/png")


@get("/")
def get_index():
    """ Index page.
    """
    return template("index")

@get("/journeys/<from_station>/<to_station>/<time>")
def get_journey(from_station, to_station, time):
    query = """
        MATCH (:Station {name: {from} })<-[:AT]-(start:OutPlatform)
        WITH start
        WHERE start.timeSecondsSinceStartOfDay > (toFloat({time})*60*60)
        WITH start
        ORDER BY start.timeSecondsSinceStartOfDay
        LIMIT 1
        MATCH (finish:Station {name: {to}})
        CALL training.markAStar(start, finish, 'NEXT>|WAIT>|AT>', 'time', 'lat', 'lon') YIELD path, weight
        WITH path ORDER BY weight  LIMIT 1
        UNWIND [x in nodes(path) WHERE x:Stop | x ] AS stop
        MATCH (route)-[:HAS_STOP|:PASSED_THROUGH]->(stop)-[:AT]->(location)
        RETURN stop, location, route
    """

    # CALL apoc.algo.aStar(start, finish, 'NEXT>|WAIT>|AT>', 'time', 'lat', 'lon') YIELD path, weight

    session = driver.session()
    stops = []
    for record in session.run(query, {"from": from_station, "to": to_station, "time": time}):
        stops.append(record)

    return template("journey", from_station = from_station, to_station = to_station, stops = stops)

@get("/locations/<location>")
def get_location(location):
    query = """
        MATCH (location:Location {code: {code} })<-[:AT]-(firstPlatform:OutPlatform)
        WHERE NOT (firstPlatform)<-[:WAIT]-(:OutPlatform)
        WITH firstPlatform
        MATCH path = (firstPlatform)-[:WAIT*]->(next)
        WHERE NOT (next)-[:WAIT]->()
        UNWIND NODES(path) AS platform
        MATCH (route)-[:HAS_STOP|:PASSED_THROUGH]->(platform)
        RETURN platform, route
    """

    session = driver.session()
    platforms = []
    for record in session.run(query, {"code": location}):
        platforms.append(record)

    return template("location", platforms = platforms, location = location)

@get("/routes/<route_id>")
def get_route(route_id):
    query = """
        MATCH (route:Route {id: {route_id} })-[:HAS_STOP|:PASSED_THROUGH]->(platform)
        RETURN platform, [label IN LABELS(platform) WHERE NOT label = "Stop"][0] AS type
        ORDER BY platform.position, type
    """

    session = driver.session()
    platforms = []
    for record in session.run(query, {"route_id": route_id}):
        platforms.append(record)

    return template("route", platforms = platforms, route_id = route_id)



if __name__ == "__main__":
    run(host="localhost", port=8080, reloader=True)
