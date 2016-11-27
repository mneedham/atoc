import csv
import pprint
from datetime import datetime

pp = pprint.PrettyPrinter(indent=4)

journeys = {}

with open("ttf331/ttisf331.mca", "r") as file:
    for line in file.readlines()[1:]:
        if line[:2] == "BS":
            train_uid = line[3:9].strip()
            date_runs_from = line[9:15].strip()
            date_runs_to = line[15:21].strip()
            days_run = line[21:28].strip()
            train_status = line[29:30].strip()
            train_identity = line[32:36].strip()
            current_journey = {}
            current_journey["stops"] = []
            current_journey["train_uid"] = train_uid
            current_journey["from"] = date_runs_from
            current_journey["to"] = date_runs_to

            # only saturday routes
            if line[21:22] == "1":
                current_journey["include"] = True
            else:
                current_journey["include"] = False
        elif line[:2] == "LO":
            location = line[2:10].strip()
            scheduled_departure = line[10:15].strip()
            public_departure = line[15:19].strip()
            platform = line[19:21].strip()
            train_line = line[21:23].strip()
            current_journey["stops"].append({"location": location, "departure": scheduled_departure})
        elif line[:2] == "LI":
            location = line[2:10].strip()
            scheduled_arrival = line[10:15].strip()
            scheduled_departure = line[15:20].strip()
            scheduled_pass = line[20:25].strip()
            current_journey["stops"].append({"location": location, "arrival": scheduled_arrival, "departure": scheduled_departure, "passed_through": scheduled_pass})
        elif line[:2] == "CR":
            location = line[2:10].strip()
            train_category = line[10:12].strip()
            train_identity = line[12:16].strip()
        elif line[:2] == "LT":
            location = line[2:10].strip()
            scheduled_arrival = line[10:15].strip()
            public_arrival = line[15:19].strip()
            current_journey["stops"].append({"location": location, "arrival": scheduled_arrival})
            journeys["{0}_{1}_{2}".format(current_journey["train_uid"], current_journey["from"], current_journey["to"])] = current_journey
        else:
            continue

# with open("data/routes.csv", "w") as routes_file:
#     writer = csv.writer(routes_file, delimiter = ",")
#     writer.writerow(["routeId", "location", "arrival", "departure", "passedThrough", "position"])
#     for journey in journeys:
#         for position, stop in enumerate(journeys[journey]["stops"]):
#             writer.writerow([journey, stop["location"], stop.get("arrival", ""), stop.get("departure", ""), stop.get("passed_through", ""), position])

# with open("data/suttonRoutes.csv", "w") as routes_file:
#     writer = csv.writer(routes_file, delimiter = ",")
#     writer.writerow(["routeId", "location", "arrival", "departure", "passedThrough", "position"])
#     for journey in journeys:
#         for position, stop in enumerate(journeys[journey]["stops"]):
#             if journey in ["G74062", "W72442", "G74065", "G73438", "W74971", "W75646", "L97622", "L97832", "W75646", "W75012", "W75403", "W75645", "W70009", "W96409"]:
#                 writer.writerow([journey, stop["location"], stop.get("arrival", ""), stop.get("departure", ""), stop.get("passed_through", ""), position])

with open("data/mondayRoutes.csv", "w") as routes_file:
    writer = csv.writer(routes_file, delimiter = ",")
    writer.writerow(["routeId", "location", "arrival", "departure", "passedThrough", "position", "dateFrom", "dateTo"])
    for journey_id in journeys:
        journey = journeys[journey_id]
        if journey["include"]:
            if datetime.strptime(journey["from"], "%y%m%d") <= datetime.now() <= datetime.strptime(journey["to"], "%y%m%d"):
                for position, stop in enumerate(journey["stops"]):
                    writer.writerow([journey["train_uid"], stop["location"], stop.get("arrival", ""), stop.get("departure", ""), \
                    stop.get("passed_through", ""), position, journey["from"], journey["to"]])


# for journey_id in journeys:
#     journey = journeys[journey_id]
#     if journey["train_uid"] == "W72898":
#         print journey
#         # if journey["include"]:
#         #     if datetime.strptime(journey["from"], "%y%m%d") <= datetime.now() <= datetime.strptime(journey["to"], "%y%m%d"):
#         #         for position, stop in enumerate(journey["stops"]):
#         #             # writer.writerow([journey_id, stop["location"], stop.get("arrival", ""), stop.get("departure", ""), \
#         #             stop.get("passed_through", ""), position, journey["from"], journey["to"]])
