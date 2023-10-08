#include <PubSubClient.h>
#include <WiFi.h>
#include "DHTesp.h"
#include <ArduinoJson.h>


#define LED_PIN 12
#define MQTT_SERVER "broker.hivemq.com"
#define MQTT_PORT 1883
#define MQTT_TOPIC "/10581197_10583298"
#define MQTT_ID_LENGTH 10
#define PANC_ID "PANC"
#define LED 1
#define PWM_FREQ 5000
#define PWM_RES 3


unsigned long previousMillis = 0;
unsigned long interval = 30000;

time_t currentTimestamp;
time_t joinTimestamp;
time_t waitingTime = 20;

time_t receptionTime;

volatile int pwm_value = 0;

StaticJsonDocument<1000> doc_in;
StaticJsonDocument<200> doc_out;
bool joined = 0;
bool joining = 0;
char client_id[8];

DHTesp dht;
WiFiClient espClient;
PubSubClient mqtt_client(espClient);
char mqtt_id[MQTT_ID_LENGTH];

void callback(char* topic, byte* payload, unsigned int length) {

  // Try JSON parsing
  DeserializationError de_error = deserializeJson(doc_in, payload);
  // Test if parsing succeeds
  if (de_error) {
    Serial.print(F("deserializeJson() failed: "));
    Serial.println(de_error.f_str());
    return;
  }

  // Fetch values
  int type = doc_in["type"];
  const char* dst = doc_in["dst"];
  // Distinguish messages
  if(type==-1){ //something went wrong
    const char* comm_error = doc_in["error"];
    Serial.print("Communication error: ");
    Serial.println(comm_error);
    mqtt_client.disconnect();
    WiFi.disconnect();
  }
  if(type==0 && !joined && !joining){ //received beacon and not registred to net yet
    Serial.println("Received first beacon");
    int interval = doc_in["frame"];
    //create association message
    doc_out["type"] = 1;
    doc_out["src"] = mqtt_id;
    doc_out["dst"] = PANC_ID;
    doc_out["client_type"] = 1;
    char payload_out[64];
    serializeJson(doc_out, payload_out);
    //wait for CAP to start
    Serial.print("Wait for millisec ");
    Serial.println(interval);
    delay(interval);
    Serial.println("Sending association message");
    //send association msg to join net
    bool pub = mqtt_client.publish(MQTT_TOPIC, payload_out);
    delay(1000);
    if(pub){ //publish successful
      time(&joinTimestamp);
      joining = 1;
    }
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
  if(type==2 && joining && !strcmp(dst,mqtt_id)){ //received ACK of net registration
    joined = 1;
    joining = 0;
    strcpy(client_id, doc_in["id"]);
    Serial.print("Joined as ");
    Serial.println(client_id);
  }
  if(type==3 && !strcmp(dst,client_id)){ //received data to update led
    float data = doc_in["data"];
    time(&receptionTime);
    int max_pwm_value = pow(2, PWM_RES);
    pwm_value = (data*max_pwm_value);
    Serial.print("Received data ");
    Serial.print(data);
    Serial.print(" at second ");
    Serial.print(receptionTime);
    Serial.print(" => LED brightness ");
    Serial.println(pwm_value);
    analogWrite(LED_PIN, pwm_value);
  }
}

void setup() {
  Serial.begin(9600);
  // Start WiFi connection
  WiFi.mode(WIFI_STA);
  WiFi.begin("Wokwi-GUEST", "");
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
  }
  Serial.print("Connected to the WiFi network with IP address: ");
  Serial.println(WiFi.localIP());
  
  // Start MQTT connection
  int index = 0;
  while(index<MQTT_ID_LENGTH) {
    int asciiPos = random(48,122);
    if((asciiPos > 57 && asciiPos < 65) || (asciiPos > 90 && asciiPos < 97))
      continue;
    mqtt_id[index] = (char) asciiPos;
    index++;
  }
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

  // Setup LED
  ledcAttachPin(LED_PIN, LED);
  ledcSetup(LED, PWM_FREQ, PWM_RES);
  ledcWrite(LED, pwm_value);
  Serial.println("LED set");
}

void loop() {
  unsigned long currentMillis = millis();
  // if WiFi is down, try reconnecting every CHECK_WIFI_TIME seconds
  if ((WiFi.status() != WL_CONNECTED) && (currentMillis - previousMillis >=interval)) {
    Serial.print(millis());
    Serial.println("Reconnecting to WiFi...");
    WiFi.disconnect();
    WiFi.reconnect();
    previousMillis = currentMillis;
  }
  mqtt_client.loop();
}