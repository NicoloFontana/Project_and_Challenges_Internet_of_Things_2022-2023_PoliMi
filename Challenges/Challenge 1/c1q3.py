from scapy.all import *
from scapy.contrib.mqtt import MQTT
from scapy.layers.inet import IP, TCP


print("How many different MQTT clients subscribe to the public broker mosquitto using single-level wildcards?")
print("How many of these clients WOULD receive a publish message issued to the topic 'hospital/room2/area0?'")

def use_single_lvl_wildcard(topic):
    topic = topic.decode('utf-8').split('/')
    for section in topic:
        if section == '+':
            return True
    return False


def exists_single_lvl_wildcard(topics):
    for topic in topics:
        if use_single_lvl_wildcard(topic.topic):
            return True
    return False


def exists_topic(pub, topics):
    pub = pub.split('/')
    for topic in topics:
        sub = topic.topic
        sub = sub.decode('utf-8').split('/')
        if (len(pub) > len(sub) and sub[-1] != '#') or (len(pub) < len(sub)):
            return False
        for i in range(len(pub)):
            if sub[i] == '#':
                return True
            if sub[i] != pub[i] and sub[i] != '+':
                return False
    return True


path = "challenge2023_1.pcapng"
cap = rdpcap(path)

mqtt_cap = []
for sub_request in cap:
    if MQTT in sub_request:
        mqtt_cap.append(sub_request)

# IP address found with Wireshark: dns.qry.name contains "mosquitto"
broker_addr = "91.121.93.94"  # IPv6 not used IP address: 2001:41d0:1:925e::1
resource = "hospital/room2/area0"

single_lvl_clients = []
hospital_clients = []
successful_sub_idx = []
for i in range(len(mqtt_cap)):
    sub_request = mqtt_cap[i]
    if sub_request[MQTT].type == 8 and sub_request[IP].dst == broker_addr:
        found_ack = False
        for j in range(i + 1, len(mqtt_cap)):
            if not found_ack:
                sub_ack = mqtt_cap[j]
                if sub_ack[MQTT].type == 9 and sub_ack[TCP].seq == sub_request[TCP].ack and sub_ack[MQTT].msgid == \
                        sub_request[MQTT].msgid:
                    successful_sub_idx.append(i)
                    found_ack = True
for i in successful_sub_idx:
    sub_request = mqtt_cap[i]
    sub_topics = sub_request[MQTT].topics
    sub_id = (sub_request[IP].src, sub_request.sport)
    if exists_single_lvl_wildcard(sub_topics):
        single_lvl_clients.append(sub_id)

general_successful_sub_idx = []
for i in range(len(mqtt_cap)):
    general_sub_request = mqtt_cap[i]
    if general_sub_request[MQTT].type == 8 and (
    general_sub_request[IP].src, general_sub_request.sport) in single_lvl_clients:
        found_ack = False
        for j in range(i + 1, len(mqtt_cap)):
            if not found_ack:
                general_sub_ack = mqtt_cap[j]
                if general_sub_ack[MQTT].type == 9 and general_sub_ack[TCP].seq == general_sub_request[TCP].ack and \
                        general_sub_ack[MQTT].msgid == general_sub_request[MQTT].msgid:
                    general_successful_sub_idx.append(i)
                    found_ack = True
for i in general_successful_sub_idx:
    general_sub_request = mqtt_cap[i]
    general_sub_topics = general_sub_request[MQTT].topics
    general_sub_id = (general_sub_request[IP].src, general_sub_request.sport)
    if exists_topic(resource, general_sub_topics):
        print("matching topics: ", general_sub_topics)
        hospital_clients.append(general_sub_id)

set_single_lvl_clients = set(single_lvl_clients)
single_lvl = len(set_single_lvl_clients)
set_hospital_clients = set(hospital_clients)
hospital = len(set_hospital_clients)
print(single_lvl, hospital)
