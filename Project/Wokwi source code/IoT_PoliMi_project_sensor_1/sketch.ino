// Importing all the needed libraries
#include <PubSubClient.h>
#include <WiFi.h>
#include "DHTesp.h"
#include <string>
#include <ArduinoJson.h>
#include <random>
#include <chrono>


#define DHT_PIN 15
#define MQTT_SERVER "broker.hivemq.com"
#define MQTT_PORT 1883
#define MQTT_TOPIC "/10581197_10583298"
#define MQTT_ID_LENGTH 10
#define PANC_id "PANC"

char mqtt_id[MQTT_ID_LENGTH];

char client_id[8];

StaticJsonDocument<1000> doc_in;
StaticJsonDocument<200> doc_out;
bool joined = 0;
bool joining = 0;

int my_slot;

float noisedHumidityValue;

DHTesp dht; // For the DHT sensor
WiFiClient espClient; // wifi client
PubSubClient mqtt_client(espClient); // mqtt client

StaticJsonDocument<200> doc;

unsigned long previousMillis = 0;
unsigned long interval = 30000;

time_t currentTimestamp;
time_t joinTimestamp;
time_t waitingTime = 20;

time_t samplingTime;

void setup() {

  Serial.begin(9600);

  //pin initialization
  dht.setup(DHT_PIN, DHTesp::DHT22);


  //WiFi setup
  WiFi.mode(WIFI_STA); // wifi mode as station
  WiFi.begin("Wokwi-GUEST", ""); // Specifying the SSID and password

  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
  }
  Serial.println();
  Serial.print("Connected to the WiFi network with IP address: ");
  Serial.println(WiFi.localIP());

  //Time for connection
  delay(2000);

  // Start MQTT connection
  int index = 0;
  // Generate a random string for the initial ID
  while(index < MQTT_ID_LENGTH){
    int asciiPos = random(48 , 122);
    if((asciiPos > 57 && asciiPos < 65) || (asciiPos > 90 && asciiPos < 97))
      continue;
    mqtt_id[index] = (char) asciiPos;
    index++;
  }

  //MQTT setup
  mqtt_client.setServer(MQTT_SERVER, MQTT_PORT);
  mqtt_client.setCallback(callback);
  mqtt_client.connect(mqtt_id);
  Serial.print("Connected to ");
  Serial.print(MQTT_SERVER);
  Serial.print(" with ID ");
  Serial.println(mqtt_id);
  mqtt_client.subscribe(MQTT_TOPIC);
  Serial.print("Subscribed to ");
  Serial.println(MQTT_TOPIC);

}



void callback(char* topic, byte* payload, unsigned int length) {

  // Try JSON parsing
  DeserializationError error = deserializeJson(doc_in, payload);
  
  // Test if parsing succeeds.
  if (error) {
    Serial.print(F("deserializeJson() failed: "));
    Serial.println(error.f_str());
    Serial.println();
    return;
  }

  // Fetch values
  int type = doc_in["type"];
  const char* dst = doc_in["dst"];


  if(type==-1){
    const char* conn_error = doc_in["error"];
    Serial.println(conn_error);
    mqtt_client.disconnect();
    WiFi.disconnect();
  }
  if(type == 0 && !joined && !joining){ //send association msg to join net
    Serial.println("Received first beacon");

    int interval = doc_in["frame"];

    doc_out["type"] = 1;
    doc_out["src"] = mqtt_id;
    doc_out["dst"] = PANC_id;
    doc_out["client_type"] = 0;
    char payload_out[64];
    serializeJson(doc_out, payload_out);
    Serial.print("Wait for millisec ");
    Serial.println(interval);
    delay(interval);
    Serial.println("Sending association message");
    Serial.println();
    bool pub = mqtt_client.publish(MQTT_TOPIC, payload_out);
    delay(1000);
    if(pub){
      time(&joinTimestamp);
      joining = 1;

    }
  }
  if(type == 0 && joined) {

    StaticJsonDocument<200> assignments;

    int frame = doc_in["frame"];
    int cap = doc_in["cap"];

    for(int i=0;i<sizeof(assignments);i++){
      if(!strcmp((const char*) assignments[i], client_id)){
        my_slot = i;
        break;
      }
    }

    int interval = frame + cap + my_slot*frame;

    doc_out["type"] = 3;
    doc_out["src"] = client_id;
    doc_out["dst"] = PANC_id;
    doc_out["data"] = noisedHumidityValue;
    doc_out["forwarded"] = 0;
    char payload_out[96];
    serializeJson(doc_out, payload_out);
    delay(interval);
    Serial.print("Sending data message with data ");
    Serial.print(noisedHumidityValue);
    Serial.print(" at second ");
    Serial.println(samplingTime);
    Serial.println();
    bool pub = mqtt_client.publish(MQTT_TOPIC, payload_out);
    delay(1000);

  }
  if(type == 0 && !joined && joining) { // To avoid getting stuck forever, waiting for an ACK
    time(&currentTimestamp);
    if(currentTimestamp - joinTimestamp > waitingTime) {
      Serial.println("Hurry up!");
      Serial.print("Threshold was ");
      Serial.print(waitingTime);
      Serial.print(" seconds and you are ");
      Serial.print(currentTimestamp - joinTimestamp);
      Serial.print(" seconds late!");
      joining = 0;
    }
  } 
  if(type==2 && joining && !strcmp(dst, mqtt_id)){ //get ACK

    // Copy client_id assigned by PANC
    strcpy(client_id, doc_in["id"]);

    joined = 1;
    joining = 0;
    Serial.print("Joined as ");
    Serial.println(client_id);
    Serial.println();
  }

}


void loop() {

  unsigned long currentMillis = millis();
  // if WiFi is down, try reconnecting every CHECK_WIFI_TIME seconds
  if ((WiFi.status() != WL_CONNECTED) && (currentMillis - previousMillis >=interval)) {
    Serial.print(millis());
    Serial.println("Reconnecting to WiFi...");
    Serial.println();
    WiFi.disconnect();
    WiFi.reconnect();
    previousMillis = currentMillis;
  }

  // Read the DHT value
  TempAndHumidity data = dht.getTempAndHumidity();
  time(&samplingTime);
  // Add noise
  noisedHumidityValue = gaussianNoiseGenerator(data.humidity);

  mqtt_client.loop();
}

// To add noise to humidity and/or temperature values
float gaussianNoiseGenerator(float initialValue) {

  float noisedValue;

  unsigned seed = std::chrono::system_clock::now().time_since_epoch().count();

  // Define random generator with Gaussian distribution
  const float mean = 0.0;
  const float stddev = 15;
  std::default_random_engine generator (seed);
  std::normal_distribution<float> dist(mean, stddev);

  // Add gaussian noise
  noisedValue = initialValue + dist(generator);

  if(noisedValue < 0) {
    noisedValue = 0;
  }
  if(noisedValue > 100) {
    noisedValue = 100;
  }

  return noisedValue;

}
