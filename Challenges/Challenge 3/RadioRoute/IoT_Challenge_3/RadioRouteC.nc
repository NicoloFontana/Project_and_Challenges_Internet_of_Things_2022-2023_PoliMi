
/*
*	IMPORTANT:
*	The code will be avaluated based on:
*		Code design  
*
*/
 
 
#include "Timer.h"
#include "RadioRoute.h"
#include "Utils.h"

#define DEFAULT_SENDER 1 // Sender used for the challenge
#define DEFAULT_DST 7 // Destination used for the challenge
#define DEFAULT_VAL 5 // Value used for the challenge
#define DEFAULT_LED_NODE 6 // Node used to control the leds for the challenge
#define PC_LEN 8 // Length of the person code
#define N_LED 3


module RadioRouteC @safe() {
  uses {

    /****** INTERFACES *****/
    interface Boot;
    interface SplitControl as AMControl;
    interface AMSend;
    interface Receive;
    interface Packet;

    interface Timer<TMilli> as Timer0;
    interface Timer<TMilli> as Timer1;
    interface Leds;
  }
}
implementation {
  routing_table_entry_t rt[MAX_RT_ENTRIES];
  char PERSON_CODE[9] = {'1','0','5','8','1','1','9','7','\0'};

  message_t packet;
  bool locked;

  // Variables to store the message to send
  message_t queued_packet;
  uint16_t queue_addr;
  uint16_t time_delays[7]={61,173,267,371,479,583,689}; //Time delay in milli seconds
  
  // Variables to avoid multiple transmissions
  bool route_req_sent=FALSE;
  bool route_rep_sent=FALSE;

  uint16_t round = 0; // Round counter for update the leds

  // Variables for prettier debug
  bool dbg_route_req_sent=FALSE;
  bool dbg_route_rep_sent=FALSE;
  bool dbg_route_req_received=FALSE;
  bool dbg_route_rep_received=FALSE;
  bool dbg_node_found = FALSE;

  /******** VARIOUS VARS *****/
  bool in_RT;
  uint16_t curr_cost;
  uint16_t new_cost;
  uint16_t led_idx;
  uint16_t next_hop;
  int i;

  message_type sending_msg_type; // Type of the message to send
  radio_route_msg_t* msg;
  radio_route_msg_t* msg_received;


  /****** HELPER FUNCTIONS *****/
  
  bool actual_send (uint16_t address, message_t* packet);
  bool generate_send (uint16_t address, message_t* packet, uint8_t type);
  


  void update_led(uint16_t val) {
    /*
    * Update the leds based on the value received, the actual round and the person code
    * @Input:
    *		val: value to be used to update the leds
    */
    led_idx = (PERSON_CODE[round]-'0') % N_LED;
    if (TOS_NODE_ID == DEFAULT_LED_NODE){ // Print on debug channel only if node 6
      // dbg("dbg", "Round %d: check %d vs %d\n", round, PERSON_CODE[round], (PERSON_CODE[round]-'0'));
      dbg("led", "Updating led %d at round %d\n", led_idx, round);
    }
    switch(led_idx){
      case 0:
        call Leds.led0Toggle();
        break;
      case 1:
        call Leds.led1Toggle();
        break;
      case 2:
        call Leds.led2Toggle();
        break;
    }
    dbg("led", "New leds status: led0: %d led1: %d led2: %d\n",  call Leds.get()&1, (call Leds.get()&2)/2, (call Leds.get()&4)/4);
    if (TOS_NODE_ID == DEFAULT_LED_NODE){ // Print on debug channel only if node 6
      dbg("led6", "Round %d, digit %d:\n\t\t led0: %d led1: %d led2: %d\n\n", round, PERSON_CODE[round]-'0', call Leds.get()&1, (call Leds.get()&2)/2, (call Leds.get()&4)/4);
    }
    round++;
    round = round % PC_LEN;
  }

  event void Boot.booted() {
    /*
    * Boot the node
    */
    dbg("boot", "Booting\n");
    dbg("boot","Application booted.\n");
    init_rt(rt);
    dbg("led", "Initial leds status: led0: %d led1: %d led2: %d\n",  call Leds.get()&1, (call Leds.get()&2)/2, (call Leds.get()&4)/4);
    if(TOS_NODE_ID == DEFAULT_LED_NODE){ // Print on debug channel only if node 6
      dbg("led6", "Person code: %s\n\n", &PERSON_CODE);
      dbg("led6", "Initial leds status:\n\t\t led0: %d led1: %d led2: %d\n\n", call Leds.get()&1, (call Leds.get()&2)/2, (call Leds.get()&4)/4);
    }
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    /*
    * Start the radio
    */
    dbg("radio", "Starting\n");
    if (err == SUCCESS) {
      dbg("radio","Radio on on node %d!\n", TOS_NODE_ID);
      if (TOS_NODE_ID == DEFAULT_SENDER){ // Node 1 waits 5s before trying to send 5 to node 7
        call Timer1.startOneShot(5000);
        dbg("timer", "Starting Timer1\n");
        dbg_route_req_received = TRUE;
      }
    }
    else {
      dbgerror("radio", "Radio failed to start, retrying...\n");
      call AMControl.start();
    }
  }
  
  event void AMControl.stopDone(error_t err) {
    dbg("radio","Radio off\n");
  }
  
  event void Timer1.fired() {
    /*
    * Timer1 fired, node 1 tries to send 5 to node 7
    */
    dbg("timer", "Fired Timer1\n");
    dbg("dbg", "Node %d tries to send %d to node %d\n", DEFAULT_SENDER, DEFAULT_VAL, DEFAULT_DST);
    in_RT = is_dst_in_rt(rt, DEFAULT_DST);
    if (in_RT){ // Node 7 is in the routing table of node 1 (NB: impossible at init because the routing table is empty)
      dbg("dbg", "Found node %d in rt\n", DEFAULT_DST);
      sending_msg_type = DATA_MSG;
      next_hop = get_next_hop(rt, DEFAULT_DST);
      msg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      msg = create_data_msg(msg, TOS_NODE_ID, DEFAULT_DST, DEFAULT_VAL);
      generate_send(next_hop, &packet, sending_msg_type);
  } else { // Node 7 is not in the routing table of node 1 => node 1 must send a route request
      dbg("dbg", "Node %d not found in rt\n", DEFAULT_DST);
      sending_msg_type = ROUTE_REQ;
      msg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
      msg = create_route_req_msg(msg, DEFAULT_DST);
      generate_send(AM_BROADCAST_ADDR, &packet, sending_msg_type);
    }
    
  }



  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
	/*
	* Parse the received packet.
	* Implement all the functionalities
	* Perform the packet send using the generate_send function if needed
	* Implement the LED logic and print LED status on Debug
	*/
  msg_received = (radio_route_msg_t*) payload;
	switch(msg_received->type){
    case DATA_MSG: // Received a data message
      print_msg_type(TOS_NODE_ID, msg_received->type, FALSE);
      if (msg_received->destination == TOS_NODE_ID){ // Destination is me
        dbg("dbg", "DATA ARRIVED AT DESTINATION!\n");
        dbg("data", "Received data message from %d with value %d\n", msg_received->sender, msg_received->value);
      } else { // Destination is not me => I need to forward the message
        in_RT = is_dst_in_rt(rt, msg_received->destination);
        if (in_RT){ // Destination is in the routing table (i.e. I know how to reach it)
          sending_msg_type = DATA_MSG;
          next_hop = get_next_hop(rt, msg_received->destination);
          msg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
          msg = create_data_msg(msg, msg_received->sender, msg_received->destination, msg_received->value);
          generate_send(next_hop, &packet, sending_msg_type);
        } else { // Destination is not in the routing table => I should not be the next hop of the sender
          dbgerror("radio_rec","ERROR!! Routed as next hop for %d without knowing destination\n", msg_received->destination);
          print_rt(rt);
        }
      }
      break;
    case ROUTE_REQ: // Received a route request
      if (!dbg_route_req_received){
        print_msg_type(TOS_NODE_ID, msg_received->type, FALSE);
      }
      if (msg_received->node_requested == TOS_NODE_ID){ // Node requested is me => I need to send a ROUTE_REP
        if(!dbg_node_found){
          dbg("dbg", "NODE REQUESTED FOUND!\n");
          dbg_node_found = TRUE;
          dbg_route_rep_received = TRUE;
        }
        sending_msg_type = ROUTE_REP;
        msg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
        msg = create_route_rep_msg(msg, TOS_NODE_ID, msg_received->node_requested, 1);
        generate_send(AM_BROADCAST_ADDR, &packet, sending_msg_type);
      } else { // Node requested is not me => I need to check if I have it in my routing table
        in_RT = is_dst_in_rt(rt, msg_received->node_requested);
        if (in_RT){ // Node requested is in the routing table (i.e. I know how to reach it) => I can send a route reply
          if(!dbg_route_req_received){
            dbg("dbg", "Found node %d in rt\n", msg_received->node_requested);
          }
          sending_msg_type = ROUTE_REP;
          new_cost = get_cost(rt, msg_received->node_requested)+1;
          msg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
          msg = create_route_rep_msg(msg, TOS_NODE_ID, msg_received->node_requested, new_cost);
          generate_send(AM_BROADCAST_ADDR, &packet, sending_msg_type);
        } else { // Node requested is not in the routing table => I need to ask how to reach it
          if(!dbg_route_req_received){
            dbg("dbg", "Node %d not found in rt\n", msg_received->node_requested);
          }
          sending_msg_type = ROUTE_REQ;
          msg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
          msg = create_route_req_msg(msg, msg_received->node_requested);
          generate_send(AM_BROADCAST_ADDR, &packet, sending_msg_type);
        }
      }
      if (TOS_NODE_ID != DEFAULT_LED_NODE){ // To continue to let node 6 print when a message is received
        dbg_route_req_received = TRUE;
      }
      break;
    case ROUTE_REP: // Received a route reply
      if (!dbg_route_rep_received){
        print_msg_type(TOS_NODE_ID, msg_received->type, FALSE);
      }
      in_RT = is_dst_in_rt(rt, msg_received->node_requested);
      curr_cost = get_cost(rt, msg_received->node_requested);
      if (!in_RT || msg_received->cost<curr_cost) { // I need to update my routing table (unkown route or higher cost saved)
          update_rt(rt, msg_received->node_requested, msg_received->sender, msg_received->cost);
          if (!dbg_route_rep_received){
            dbg("dbg", "UPDATE RT: Next hop for node %d is %d with cost %d\n", msg_received->node_requested, msg_received->sender, msg_received->cost);
          }
          if(TOS_NODE_ID == DEFAULT_SENDER && msg_received->node_requested == DEFAULT_DST){ // I am node 1 and I received a route reply for node 7 => I can send the data
            dbg("dbg", "Node %d re-tries to send %d to node %d\n", DEFAULT_SENDER, DEFAULT_VAL, DEFAULT_DST);
            sending_msg_type = DATA_MSG;
            next_hop = get_next_hop(rt, DEFAULT_DST);
            msg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
            msg = create_data_msg(msg, TOS_NODE_ID, DEFAULT_DST, DEFAULT_VAL);
            generate_send(next_hop, &packet, sending_msg_type);
          } else { // I am not node 1 OR I received a route reply for a node different from node 7 => I need to forward the route reply
            sending_msg_type = ROUTE_REP;
            new_cost = get_cost(rt, msg_received->node_requested)+1;
            msg = (radio_route_msg_t*)call Packet.getPayload(&packet, sizeof(radio_route_msg_t));
            msg = create_route_rep_msg(msg, TOS_NODE_ID, msg_received->node_requested, new_cost);
            generate_send(AM_BROADCAST_ADDR, &packet, sending_msg_type);
          }
        }
        if (TOS_NODE_ID != DEFAULT_LED_NODE){ // To continue to let node 6 print when a message is received
          dbg_route_rep_received = TRUE;
        }
    }
    update_led(msg_received->value); // Update the led with the value received
  return bufPtr;
  }
  


  bool generate_send (uint16_t address, message_t* packet, uint8_t type){
  /*
  * 
  * Function to be used when performing the send after the receive message event.
  * It store the packet and address into a global variable and start the timer execution to schedule the send.
  * It allow the sending of only one message for each REQ and REP type
  * @Input:
  *		address: packet destination address
  *		packet: full packet to be sent (Not only Payload)
  *		type: payload message type
  *
  * MANDATORY: DO NOT MODIFY THIS FUNCTION
  */
  	if (call Timer0.isRunning()){
  		return FALSE;
  	}else{
  	if (type == 1 && !route_req_sent ){
  		route_req_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 2 && !route_rep_sent){
  	  route_rep_sent = TRUE;
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;
  	}else if (type == 0){
  		call Timer0.startOneShot( time_delays[TOS_NODE_ID-1] );
  		queued_packet = *packet;
  		queue_addr = address;	
  	}
  	}
  	return TRUE;
  }

  event void Timer0.fired() {
  	/*
  	* Timer triggered to perform the send.
  	* MANDATORY: DO NOT MODIFY THIS FUNCTION
  	*/
  	actual_send (queue_addr, &queued_packet);
  }
  
  bool actual_send (uint16_t address, message_t* packet){
	/*
	* Check if the radio is locked and if not send the packet.
	*/
  if (locked) { // Radio is already transmitting something
      return FALSE;
    }
    else {
      msg = (radio_route_msg_t*)call Packet.getPayload(packet, sizeof(radio_route_msg_t));
      if (msg == NULL) {
		    return FALSE;
      }
      if (call AMSend.send(address, packet, sizeof(radio_route_msg_t)) == SUCCESS) { // Successful send

        // Debug prints
        if(sending_msg_type == DATA_MSG){
          print_msg_type(TOS_NODE_ID, sending_msg_type, TRUE);
        }
        if(sending_msg_type == ROUTE_REQ && !dbg_route_req_sent){
          print_msg_type(TOS_NODE_ID, sending_msg_type, TRUE);
          dbg_route_req_sent = TRUE;
        }
        if(sending_msg_type == ROUTE_REP && !dbg_route_rep_sent){
          print_msg_type(TOS_NODE_ID, sending_msg_type, TRUE);
          dbg_route_rep_sent = TRUE;
        }

        locked = TRUE;
        return TRUE;
      }
    }
    return FALSE;
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
	/*
  * This event is triggered when a message is sent 
	*  Check if the packet is sent 
	*/ 
  if (&packet == bufPtr && error == SUCCESS) {
      dbg("radio_send", "Packet sent...\n");
      dbg_clear("radio_send", " at time %s \n", sim_time_string());
    }
    else{
      // dbgerror("radio_send", "Send done error!\n");
    }
    locked = FALSE;
  }
}




