import requests
from neo4j.v1 import GraphDatabase, basic_auth

driver = GraphDatabase.driver("bolt://localhost", auth=basic_auth("neo4j", "neo"))
session = driver.session()

uri = "http://nominatim.openstreetmap.org/search.php?q={0}&polygon=1&viewbox=&format=json&addressdetails=1"

query = """MATCH (location:Location)
           WHERE NOT EXISTS(location.lat) AND EXISTS(location.name)
           RETURN location
           """

result = session.run(query)
for row in result:
    location = row["location"]
    place = location["name"].replace("(BUS VIA PBO)", "").replace("(BY BUS)", "").replace("(BUS)","").replace("BUS", "")
    r = requests.get(uri.format(place))
    response = r.json()

    if len(response) > 0:
        response = response[0]

        if response["address"]["country"] in ["UK", "Isle of Man"]:
            print("{0},{1},{2}".format(location["code"], float(response["lat"]), float(response["lon"])))

session.close()
