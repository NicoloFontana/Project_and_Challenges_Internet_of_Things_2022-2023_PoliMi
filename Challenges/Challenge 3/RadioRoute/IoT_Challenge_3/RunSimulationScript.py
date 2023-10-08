print("********************************************")
print("*                                          *")
print("*             TOSSIM Script                *")
print("*                                          *")
print("********************************************")

import sys;
import time;

from TOSSIM import *;

t = Tossim([]);


topofile="topology.txt";
modelfile="meyer-heavy.txt";


print("Initializing mac....")
mac = t.mac();
print("Initializing radio channels....")
radio=t.radio();
print("    using topology file:",topofile)
print("    using noise file:",modelfile)
print("Initializing simulator....")
t.init();


simulation_outfile = "TOSSIM_log.txt";
print("Saving sensors simulation output to:", simulation_outfile);
out = open(simulation_outfile, "w");

led_outfile = "Node6_leds_log.txt";
print("Saving sensors simulation output to:", led_outfile);
led_out = open(led_outfile, "w");
# out = sys.stdout;

#Add debug channel
# print("Activate debug message on channel init")
# t.addChannel("init",out);
print("Activate debug message on channel boot")
t.addChannel("boot",out);
print("Activate debug message on channel timer")
t.addChannel("timer",out);
print("Activate debug message on channel led")
t.addChannel("led",out);
print("Activate debug message on channel led6")
t.addChannel("led6",led_out);
# print("Activate debug message on channel led_0")
# t.addChannel("led_0",out);
# print("Activate debug message on channel led_1")
# t.addChannel("led_1",out);
# print("Activate debug message on channel led_2")
# t.addChannel("led_2",out);
print("Activate debug message on channel radio")
t.addChannel("radio",out);
print("Activate debug message on channel radio_send")
t.addChannel("radio_send",out);
print("Activate debug message on channel radio_rec")
t.addChannel("radio_rec",out);
# print("Activate debug message on channel radio_pack")
# t.addChannel("radio_pack",out);
print("Activate debug message on channel dbg")
t.addChannel("dbg",out);
print("Activate debug message on channel data")
t.addChannel("data",out);

for i in range (1, 8): # Boot all nodes
    print("Creating node", i, "...")
    node = t.getNode(i);
    time = 0*t.ticksPerSecond();
    node.bootAtTime(time);
    print(">>>Will boot node", i, "at time",  time/t.ticksPerSecond(), "[sec]")

print("Creating radio channels...")
f = open(topofile, "r");
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print(">>>Setting radio channel from node ", s[0], " to node ", s[1], " with gain ", s[2], " dBm")
    radio.add(int(s[0]), int(s[1]), float(s[2]))


#creation of channel model
print("Initializing Closest Pattern Matching (CPM)...")
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0;
mid_compl = 0;

print("Reading noise model data file:", modelfile)
print("Loading:")
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1;
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl;
            mid_compl = 0;
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(1, 8):
            t.getNode(i).addNoiseTraceReading(val)
print("Done!")

for i in range(1, 8):
    print(">>>Creating noise model for node:",i)
    t.getNode(i).createNoiseModel()

print("Start simulation with TOSSIM! \n\n\n")

for i in range(0,12000):
	t.runNextEvent()
	
print("\n\n\nSimulation finished!")

