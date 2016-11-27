CREATE CONSTRAINT ON (l:Location)
ASSERT l.code is unique;

CREATE INDEX ON :Location(name);

CREATE CONSTRAINT ON (s:Stop)
ASSERT s.id is unique;

RETURN "stops -> routes";
USING PERIODIC COMMIT 10000
load csv with headers from "file:///routes.csv" AS row
with row where row.routeId in ["G74062", "W72442"]
MERGE (stop:Stop {id: row.routeId + "_" + row.location})
ON CREATE SET stop.departure = row.departure,
              stop.arrival = row.arrival,
              stop.passedThrough = row.passedThrough,
              stop.position = toInteger(row.position),
              stop.routeId = row.routeId
MERGE (route:Route {id: row.routeId})
MERGE (route)-[:HAS_STOP]->(stop);

RETURN "stops -> locations";
USING PERIODIC COMMIT 10000
load csv with headers from "file:///routes.csv" AS row
with row where row.routeId in ["G74062", "W72442"]
MATCH (stop:Stop {id: row.routeId + "_" + row.location})
MERGE (location:Location {code: row.location})
MERGE (stop)-[:AT]->(location);

RETURN "set locations name";
load csv with headers from "file:///locations.csv" AS row
MATCH (l:Location {code: row.code})
SET l.name = row.description
FOREACH(ignoreMe IN CASE WHEN row.type = "station" THEN [1] ELSE [] END |
 SET l:Station);

RETURN "stops -> stops";
MATCH (stop:Stop)
WITH stop ORDER BY stop.routeId, stop.position
WITH stop.routeId AS routeId, COLLECT(stop) AS stops
UNWIND RANGE(0, SIZE(stops) - 2) AS idx
WITH stops[idx] AS from, stops[idx+1] AS to
MERGE (from)-[:NEXT]->(to);

RETURN "stops properties";
MATCH (stop:Stop)
UNWIND ["arrival", "departure", "passedThrough"] AS key
WITH stop,
     key,
     toInteger(substring(stop[key], 0, 2)) AS hours,
     toInteger(substring(stop[key], 2, 2)) AS minutes,
     CASE WHEN substring(stop[key], 4,1) = "H" THEN 30 ELSE 0 END As seconds
WITH stop, key, (hours * 60 * 60) + (minutes * 60) + seconds AS secondsSinceStartOfDay
WHERE NOT secondsSinceStartOfDay is NULL
WITH stop, key + "SecondsSinceStartOfDay" AS newKey, secondsSinceStartOfDay
CALL apoc.create.setProperty(stop, newKey, secondsSinceStartOfDay) YIELD node
RETURN COUNT(*);

RETURN "NEXT times";
MATCH (r:Route)
MATCH (r)-[:HAS_STOP]->(stop:Stop)
WITH r, stop ORDER BY stop.routeId, stop.position
WITH r, stop.routeId AS routeId, COLLECT(stop) AS stops
UNWIND RANGE(0, SIZE(stops) - 2) AS idx
WITH r, stops[idx] AS from, stops[idx+1] AS to
MATCH (from)-[next:NEXT]->(to)
WITH r, from, next, to, coalesce(from.departureSecondsSinceStartOfDay, from.passedThroughSecondsSinceStartOfDay) AS fromTime, coalesce(to.arrivalSecondsSinceStartOfDay, to.passedThroughSecondsSinceStartOfDay) AS toTime
SET next.time =  toTime - fromTime;

RETURN "WAIT times";
MATCH (location:Station)<-[:AT]-(stop)
WITH location, stop
ORDER BY location.name, stop.departureSecondsSinceStartOfDay
WITH location, COLLECT(stop) AS stops
UNWIND RANGE(0, SIZE(stops)-2) AS idx
WITH stops[idx] AS one, stops[idx+1] AS two
WITH one, two, two.departureSecondsSinceStartOfDay - one.departureSecondsSinceStartOfDay AS waitingTime
WHERE NOT waitingTime is NULL
MERGE (one)-[wait:WAIT]->(two)
ON CREATE SET wait.time = waitingTime;
