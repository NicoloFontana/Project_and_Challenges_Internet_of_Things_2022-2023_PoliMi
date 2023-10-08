
 
#include "RadioRoute.h"


configuration RadioRouteAppC {}
implementation {
/****** COMPONENTS *****/
  components MainC, RadioRouteC as App;
  //add the other components here
  components LedsC;
  components new TimerMilliC() as timer0;
  components new TimerMilliC() as timer1;
  components ActiveMessageC;
  components new AMSenderC(AM_RADIO_COUNT_MSG);
  components new AMReceiverC(AM_RADIO_COUNT_MSG);

  
  
  /****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;  
  /****** Wire the other interfaces down here *****/
  App.AMControl -> ActiveMessageC;
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  App.Packet -> AMSenderC;

  App.Timer0 -> timer0;
  App.Timer1 -> timer1;
  App.Leds -> LedsC;
}


