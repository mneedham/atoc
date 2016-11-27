import csv
from collections import defaultdict
from neo4j.v1 import GraphDatabase, basic_auth

class Trie:
    """
    Implement a trie with insert, search, and startsWith methods.
    """
    def __init__(self):
        self.root = defaultdict()

    # @param {string} word
    # @return {void}
    # Inserts a word into the trie.
    def insert(self, word):
        current = self.root
        for letter in word:
            current = current.setdefault(letter, {})
        current.setdefault("_end")

    # @param {string} word
    # @return {boolean}
    # Returns if the word is in the trie.
    def search(self, word):
        current = self.root
        for letter in word:
            if letter not in current:
                return False
            current = current[letter]
        if "_end" in current:
            return True
        return False

    # @param {string} prefix
    # @return {boolean}
    # Returns if there is any word in the trie
    # that starts with the given prefix.
    def startsWith(self, prefix):
        current = self.root
        for letter in prefix:
            if letter not in current:
                return False
            current = current[letter]

        return True

    def item(self, prefix):
        current = self.root
        for letter in prefix:
            if letter not in current:
                return False
            current = current[letter]

        return self.squash(current)

    def squash(self, x):
        for key in x:
            if key == "_end":
                return ""
            else:
                return key + self.squash(x[key])

stops = {}
trie = Trie()
with open("Stops.csv", "r") as stops_file:
    reader = csv.DictReader(stops_file)

    for row in reader:
        trie.insert(row["ATCOCode"][::-1])
        stops[row["ATCOCode"]] = {"lat": row["Latitude"], "lon": row["Longitude"]}

driver = GraphDatabase.driver("bolt://localhost", auth=basic_auth("neo4j", "neo"))
session = driver.session()

result = session.run("""MATCH (l:Location)
                        WHERE NOT EXISTS(l.lat)
                        RETURN l""")

lat_longs = []
for record in result:
    location = record["l"]
    if trie.startsWith(location["code"][::-1]):
        key = "{0}{1}".format(trie.item(location["code"][::-1])[::-1], location["code"])
        value = stops[key]

        lat_longs.append([location["code"], value["lat"], value["lon"]])

session.close()

with open("data/latLongs.csv", "w") as lat_lons_file, \
     open("data/locations.csv", "r") as locations_file:
    writer = csv.writer(lat_lons_file, delimiter=",")
    writer.writerow(["code", "lat", "lon"])

    for lat_long in lat_longs:
        writer.writerow(lat_long)

    reader = csv.reader(locations_file, delimiter=",")
    next(reader)

    for row in reader:
        if row[3]:
            writer.writerow([row[0], row[3], row[4]])
