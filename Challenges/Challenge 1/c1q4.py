from scapy.all import *
from scapy.contrib.mqtt import MQTT
from scapy.layers.inet import IP, TCP


print("How many MQTT clients specify a last Will Message directed to a topic having as first level 'university'?")
print("How many of these Will Messages are sent from the broker to the subscribers?")

def check_first_lvl(tgt, topic, wildcards=False):
    topic = topic.decode('utf-8', errors="ignore").split('/')
    if topic[0] == tgt:
        return True
    elif wildcards and (topic[0] == '+' or topic[0] == '#'):
        return True
    return False


path = "challenge2023_1.pcapng"
cap = rdpcap(path)

mqtt_cap = []
for pkt in cap:
    if MQTT in pkt:
        mqtt_cap.append(pkt)

tgt_topic = "university"

last_will_clients = []
last_will_msgs = []
for pkt in mqtt_cap:
    if pkt[MQTT].type == 1 and pkt[MQTT].willflag == 1:
        if check_first_lvl(tgt_topic, pkt[MQTT].willtopic):
            last_will_clients.append((pkt[IP].src, pkt[TCP].sport))
            last_will_msgs.append(pkt[MQTT].willmsg)

last_will_sent = 0
for pkt in mqtt_cap:
    if pkt[MQTT].type == 3 and check_first_lvl(tgt_topic, pkt[MQTT].topic, wildcards=True) and pkt[
        MQTT].value in last_will_msgs:
        last_will_sent += 1

set_last_will_clients = set(last_will_clients)
last_will = len(set_last_will_clients)
print(last_will, last_will_sent)
