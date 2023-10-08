#ifndef IOT_CHALLENGE_3_RADIOROUTE_H
#define IOT_CHALLENGE_3_RADIOROUTE_H

typedef enum {
        DATA_MSG = 0,
        ROUTE_REQ = 1,
        ROUTE_REP = 2
        } message_type;

typedef struct radio_route_msg {
        message_type type;
        uint16_t sender;
        uint16_t destination;
        uint16_t value;
        uint16_t node_requested;
        uint16_t cost;

} radio_route_msg_t;

typedef struct routing_table_entry {
  uint16_t destination;
  uint16_t next_hop;
  uint16_t cost;

} routing_table_entry_t;

enum {
  AM_RADIO_COUNT_MSG = 10,
};

#endif