
#define MAX_RT_ENTRIES 10 //max number of entries in the routing table
#define MAX_INT 65535 //highest value of uint16_t

// Support variables
uint16_t i;
bool found;

void print_msg_type(uint16_t node, uint16_t sending_msg_type, bool is_sent){  
    /*
    *   Debug function to print the type of message sent or received
    */
    if (is_sent){   
        switch(sending_msg_type){
            case 0:
                dbg("radio_send", "%s sent\n", "DATA_MSG");
                break;
            case 1:
                dbg("radio_send", "%s sent\n", "ROUTE_REQ");
                break;
            case 2:
                dbg("radio_send", "%s sent\n", "ROUTE_REP");
                break;
        }
    } else {   
        switch(sending_msg_type){
            case 0:
                dbg("radio_rec", "%s received\n", "DATA_MSG");
                break;
            case 1:
                dbg("radio_rec", "%s received\n", "ROUTE_REQ");
                break;
            case 2:
                dbg("radio_rec", "%s received\n", "ROUTE_REP");
                break;
        }
    }
}


  /****** FUNCTIONS TO HANDLE ROUTING TABLE *****/

void print_rt(routing_table_entry_t rt[]){
    /*
    *   Debug function to print the routing table
    *   @Input:
    *       rt: routing table
    */
    for (i = 0; i < MAX_RT_ENTRIES; i++){
            dbg("dbg","RT[%d] = nxt %d dst %d cost %d\n", i, rt[i].next_hop, rt[i].destination, rt[i].cost);
    }
}

void init_rt(routing_table_entry_t rt[]){
    /* 
    * Initialize routing table to destination and next hop 0 and cost MAX_INT
    * @Input:
    *     rt: routing table
    */
    for (i=0; i<MAX_RT_ENTRIES; i++){
      rt[i].destination = 0;
      rt[i].next_hop = 0;
      rt[i].cost = MAX_INT;
    }
  }
  
  bool is_dst_in_rt(routing_table_entry_t rt[], uint16_t dst){
    /*
    * Check if a destination is in the routing table
    * @Input:
    *     rt: routing table
    *     dst: destination to be checked
    * @Output:
    *     TRUE if destination is in the routing table
    */
    for(i=0; i<MAX_RT_ENTRIES; i++){
      if(rt[i].destination == dst){
        return TRUE;
      }
    }
    return FALSE;
  }

  void update_rt(routing_table_entry_t rt[], uint16_t dst, uint16_t next_hop, uint16_t cost){
    /* 
    * Update routing table with new cost or new entry
    * @Input:
    *     rt: routing table
    *     dst: destination with new route
    *     next_hop: next hop to reach dst
    *     cost: cost to reach dst
    */
    found = is_dst_in_rt(rt, dst);
    if (found){ // Entry already exists => just update
      for (i=0; i<MAX_RT_ENTRIES; i++){
        if (rt[i].destination == dst){
          rt[i].next_hop = next_hop;
          rt[i].cost = cost;
        }
      }
    } else { // Entry does not exist => create new entry
      for (i=0; i<MAX_RT_ENTRIES; i++){
        if (rt[i].destination == 0 && rt[i].next_hop == 0 && rt[i].cost == MAX_INT){
          rt[i].destination = dst;
          rt[i].next_hop = next_hop;
          rt[i].cost = cost;
        }
      }
    }
  }

  uint16_t get_next_hop(routing_table_entry_t rt[], uint16_t dst){
    /*
    * Get the next hop to reach a destination
    * @Input:
    *     rt: routing table
    *     dst: destination to be reached
    * @Output:
    *     next_hop: next hop to reach dst
    */
    for(i=0; i<MAX_RT_ENTRIES; i++){
      if(rt[i].destination == dst){
        return rt[i].next_hop;
      }
    }
    return 0; // if not found
  }

  uint16_t get_cost(routing_table_entry_t rt[], uint16_t dst){
    /*
    * Get the cost to reach a destination
    * @Input:
    *     rt: routing table
    *     dst: destination to be reached
    * @Output:
    *     cost: cost to reach dst
    */
    for(i=0; i<MAX_RT_ENTRIES; i++){
      if(rt[i].destination == dst){
        return rt[i].cost;
      }
    }
    return MAX_INT; // if not found
  }


  
  /****** FUNCTIONS TO CREATE MESSAGES *****/

  radio_route_msg_t* create_data_msg(radio_route_msg_t* msg, uint16_t sender, uint16_t dst, uint16_t val){
    /*
    * Create a data message
    * @Input:
    *     msg: empty message to be modified
    *     sender: sender of the message
    *     dst: destination of the message
    *     val: value to be sent
    * @Output:
    *     msg: message to be sent
    */
    msg->type = DATA_MSG;
    msg->sender = sender;
    msg->destination = dst;
    msg->value = val;

    return msg;
  }

  radio_route_msg_t* create_route_req_msg(radio_route_msg_t* msg, uint16_t node_requested){
    /*
    * Create a route request message
    * @Input:
    *     msg: empty message to be modified
    *     node_requested: node of which the route is requested
    * @Output:
    *     msg: message to be sent
    */
    msg->type = ROUTE_REQ;
    msg->node_requested = node_requested;

    return msg;
  }

  radio_route_msg_t* create_route_rep_msg(radio_route_msg_t* msg, uint16_t sender, uint16_t node_requested, uint16_t cost){
    /*
    * Create a route reply message
    * @Input:
    *     msg: empty message to be modified
    *     sender: sender of the message
    *     node_requested: node of which the route was requested
    *     cost: cost to reach node_requested
    * @Output:
    *     msg: message to be sent
    */
    msg->type = ROUTE_REP;
    msg->sender = sender;
    msg->node_requested = node_requested;
    msg->cost = cost;

    return msg;
  }