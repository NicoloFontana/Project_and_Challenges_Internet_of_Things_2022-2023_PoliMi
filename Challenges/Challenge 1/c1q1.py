from scapy.all import *
from scapy.contrib.coap import CoAP
from scapy.layers.inet import IP

print("How many CoAP GET requests are directed to non-existing resources in the local CoAP server?")
print("How many of these are of type Non-confirmable?")

path = "challenge2023_1.pcapng"
cap = rdpcap(path)

coap_cap = []
for pkt in cap:
    if CoAP in pkt:
        coap_cap.append(pkt)

not_found = 0
non_conf = 0
local_get = 0
for i in range(len(coap_cap)):
    get_request = coap_cap[i]
    if get_request[CoAP].code == 1 and get_request[IP].dst == "127.0.0.1":
        local_get += 1
        found_first = False
        for j in range(i + 1, len(coap_cap)):
            if not found_first:
                response = coap_cap[j]
                if (response[IP].src == get_request[IP].dst and response[IP].dst == get_request[IP].src and response[
                    CoAP].code == 132 and (response[CoAP].msg_id == get_request[CoAP].msg_id or (
                        response[CoAP].token == get_request[CoAP].token and len(response[CoAP].token) != 0))):
                    not_found += 1
                    if get_request[CoAP].type == 1:
                        non_conf += 1
                    found_first = True

print(not_found, non_conf)
