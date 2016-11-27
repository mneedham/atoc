// add time to rels
MATCH (r:Route {id: "G74062"})
MATCH (r)-[:HAS_STOP]->(stop:Stop)
WITH r, stop ORDER BY stop.routeId, stop.position
WITH r, stop.routeId AS routeId, COLLECT(stop) AS stops
UNWIND RANGE(0, SIZE(stops) - 2) AS idx
WITH r, stops[idx] AS from, stops[idx+1] AS to
MATCH (from)-[next:NEXT]->(to)
WITH from, next, to, coalesce(from.departureSecondsSinceStartOfDay, from.passedThroughSecondsSinceStartOfDay) AS fromTime, coalesce(to.arrivalSecondsSinceStartOfDay, to.passedThroughSecondsSinceStartOfDay) AS toTime
SET next.time =  toTime - fromTime

// working out the time between each stop
MATCH (r:Route {id: "G74062"})
MATCH (r)-[:HAS_STOP]->(stop:Stop)
WITH r, stop ORDER BY stop.routeId, stop.position
WITH r, stop.routeId AS routeId, COLLECT(stop) AS stops
UNWIND RANGE(0, SIZE(stops) - 2) AS idx
WITH r, stops[idx] AS from, stops[idx+1] AS to
MATCH (from)-[next:NEXT]->(to)
RETURN from, next, to, coalesce(from.departure, from.passedThrough), coalesce(to.arrival, to.passedThrough)
