CREATE CONSTRAINT ON (l:Location)
ASSERT l.code is unique;

CREATE INDEX ON :Location(name);

CREATE CONSTRAINT ON (p:Point)
ASSERT p.id is unique;

CREATE CONSTRAINT ON (i:InPlatform)
ASSERT i.id is unique;

CREATE CONSTRAINT ON (o:OutPlatform)
ASSERT o.id is unique;

CREATE INDEX ON :Station(name);

CREATE CONSTRAINT ON (r:Route)
ASSERT r.id is unique;

CREATE INDEX ON :Stop(id);

RETURN "points -> routes";
USING PERIODIC COMMIT 10000
load csv with headers from "file:///saturdayRoutes.csv" AS row
with row WHERE EXISTS(row.passedThrough)
MERGE (point:Point {id: row.routeId + "_" + row.dateFrom + "_" + row.dateTo + "_" + row.location + "_point"})
SET point.time = row.passedThrough, point.position = toInteger(row.position), point.routeId = row.routeId, point:Stop
MERGE (route:Route {id: row.routeId + "_" + row.dateFrom + "_" + row.dateTo})
MERGE (route)-[:PASSED_THROUGH]->(point);

RETURN "in platforms -> routes";
USING PERIODIC COMMIT 10000
load csv with headers from "file:///saturdayRoutes.csv" AS row
with row where EXISTS(row.arrival)
MERGE (in:InPlatform {id: row.routeId + "_" + row.dateFrom + "_" + row.dateTo + "_" + row.location + "_in"})
SET in.time = row.arrival, in.position = toInteger(row.position), in.routeId = row.routeId, in:Stop
MERGE (route:Route {id: row.routeId + "_" + row.dateFrom + "_" + row.dateTo})
MERGE (route)-[:HAS_STOP]->(in);

RETURN "out platforms -> routes";
USING PERIODIC COMMIT 10000
load csv with headers from "file:///saturdayRoutes.csv" AS row
with row where EXISTS(row.departure)
MERGE (out:OutPlatform {id: row.routeId + "_" + row.dateFrom + "_" + row.dateTo + "_" + row.location + "_out"})
SET out.time = row.departure, out.position = toInteger(row.position), out.routeId = row.routeId, out:Stop
MERGE (route:Route {id: row.routeId + "_" + row.dateFrom + "_" + row.dateTo})
MERGE (route)-[:HAS_STOP]->(out);

RETURN "stops -> locations";
USING PERIODIC COMMIT 10000
load csv with headers from "file:///saturdayRoutes.csv" AS row
MATCH (stop:Stop) WHERE stop.id STARTS WITH (row.routeId + "_" + row.dateFrom + "_" + row.dateTo + "_" + row.location + "_")
WITH stop, row
MERGE (location:Location {code: row.location})
MERGE (stop)-[:AT]->(location);

RETURN "set locations name";
load csv with headers from "file:///locations.csv" AS row
MATCH (l:Location {code: row.code})
SET l.name = row.description
FOREACH(ignoreMe IN CASE WHEN row.type = "station" THEN [1] ELSE [] END |
 SET l:Station);

RETURN "stops properties";
CALL apoc.periodic.iterate(
  'MATCH (stop:Stop) RETURN stop',
  'WITH {stop} AS stop, "time" AS key
   WITH stop,
        key,
        toInteger(substring(stop[key], 0, 2)) AS hours,
        toInteger(substring(stop[key], 2, 2)) AS minutes,
        CASE WHEN substring(stop[key], 4,1) = "H" THEN 30 ELSE 0 END As seconds
   WITH stop, key, (hours * 60 * 60) + (minutes * 60) + seconds AS secondsSinceStartOfDay
   WHERE NOT secondsSinceStartOfDay is NULL
   WITH stop, key + "SecondsSinceStartOfDay" AS newKey, secondsSinceStartOfDay
   CALL apoc.create.setProperty(stop, newKey, secondsSinceStartOfDay) YIELD node
   RETURN COUNT(*)',
  {batchSize:1000,parallel:true})
YIELD batches, total;

RETURN "in -> out wait time";
CALL apoc.periodic.iterate(
  'MATCH (route:Route) RETURN route',
  'WITH {route} AS route
   MATCH (route)-[:HAS_STOP]->(platform:Stop)-[:AT]->(s)
   WITH s, route, platform
   ORDER BY s.name, route.id, platform.timeSecondsSinceStartOfDay
   WITH s, route.id AS routeId, COLLECT(platform) AS platforms
   WHERE SIZE(platforms) = 2
   WITH s, routeId, platforms, platforms[0] AS in, platforms[1] AS out
   WITH s, routeId, in, out, out.timeSecondsSinceStartOfDay - in.timeSecondsSinceStartOfDay AS waitingTime
   MERGE (in)-[wait:WAIT]->(out)
   SET wait.time = waitingTime',
  {batchSize:1000,parallel:false})
YIELD batches, total;

RETURN "stops -> stops";
CALL apoc.periodic.iterate(
  'MATCH (route:Route) RETURN route',
  'WITH {route} AS route
   MATCH (route)-[:HAS_STOP|:PASSED_THROUGH]->(stop:Stop)
   WITH route, stop ORDER BY route.id, stop.position, stop.timeSecondsSinceStartOfDay
   WITH route, COLLECT(stop) AS stops
   UNWIND RANGE(0, SIZE(stops) - 2) AS idx
   WITH stops[idx] AS from, stops[idx+1] AS to
   WHERE NOT from:InPlatform AND NOT to:OutPlatform
   WITH from, to, to.timeSecondsSinceStartOfDay - from.timeSecondsSinceStartOfDay AS timeInSeconds
   MERGE (from)-[next:NEXT]->(to)
   SET next.time = timeInSeconds',
  {batchSize:1000,parallel:false})
YIELD batches, total;

RETURN "WAIT times";
CALL apoc.periodic.iterate(
  'MATCH (location:Station) RETURN location',
  'WITH {location} AS location
   MATCH (location)<-[:AT]-(stop:OutPlatform)
   WITH location, stop
   ORDER BY location.name, stop.timeSecondsSinceStartOfDay
   WITH location, COLLECT(stop) AS stops
   UNWIND RANGE(0, SIZE(stops)-2) AS idx
   WITH stops[idx] AS one, stops[idx+1] AS two
   WITH one, two, two.timeSecondsSinceStartOfDay - one.timeSecondsSinceStartOfDay AS waitingTime
   MERGE (one)-[wait:WAIT]->(two)
   SET wait.time = waitingTime',
  {batchSize:1,parallel:false})
YIELD batches, total;

RETURN "AT rels";
CALL apoc.periodic.iterate(
  'MATCH (stop:Stop) RETURN stop',
  'WITH {stop} AS stop
   MATCH (stop)-[at:AT]->()
   SET at.time = 0',
  {batchSize:100,parallel:false})
YIELD batches, total;
