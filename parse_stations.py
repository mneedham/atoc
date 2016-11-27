import csv
from bng_to_latlon import OSGB36toWGS84

locations = {}

location_mappings = {}
with open("TIPLOC_Eastings_and_Northings.csv", "r") as location_mappings_file:
    reader = csv.DictReader(location_mappings_file)
    for row in reader:
        lat, lon = OSGB36toWGS84(int(float(row["EASTING"])), int(float(row["NORTHING"])))
        location_mappings[row["TIPLOC"]] = {'lat': lat, "lon": lon}

with open("ttf331/ttisf331.msn", "r") as file:
    for line in file.readlines()[1:]:
        if line[:1] == "A":
            station_name = line[5:35].strip()
            tiploc_code = line[36:43].strip()

            if tiploc_code in location_mappings:
                location = location_mappings[tiploc_code]
                locations[tiploc_code] = {'description': station_name, 'type': "station", 'lat': location["lat"], 'lon': location["lon"]}
            else:
                locations[tiploc_code] = {'description': station_name, 'type': "station"}
        else:
            continue

with open("ttf331/ttisf331.mca", "r") as file:
    for line in file.readlines()[1:]:
        if line[:2] == "TI":
            tiploc_code = line[2:9].strip()
            description = line[18:44].strip()
            if not tiploc_code in locations:
                if tiploc_code in location_mappings:
                    location = location_mappings[tiploc_code]
                    locations[tiploc_code] = {'description': description, 'type': "junction", 'lat': location["lat"], 'lon': location["lon"]}
                else:
                    locations[tiploc_code] = {'description': description, 'type': "junction"}

with open("data/locations.csv", "w") as locations_file:
    writer = csv.writer(locations_file, delimiter = ",")
    writer.writerow(["code", "description", "type", "lat", "lon"])

    for code in locations:
        print "{0} -> {1}".format(code, locations[code])
        location = locations[code]
        if "lat" in location:
            writer.writerow([code, location["description"], location["type"], location["lat"], location["lon"]])
        else:
            writer.writerow([code, location["description"], location["type"], "", ""])
