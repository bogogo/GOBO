// Gobo button remote: an ESP32 with momentary buttons that controls WLED lights over Wi-Fi.
// Wire each button between its GPIO pin and GND (internal pull-ups are used, no resistors needed).
// Board: "ESP32 Dev Module" in Arduino IDE (esp32 core 3.x).

#include <WiFi.h>
#include <HTTPClient.h>

const char *WIFI_SSID = "your-wifi";
const char *WIFI_PASS = "your-password";

// Lights this remote controls (IP or mDNS name). Every button press goes to all of them.
const char *LIGHTS[] = {"192.168.1.50"};

struct Button {
  uint8_t pin;
  const char *json;  // WLED JSON API state patch
  bool last;
  uint32_t changedAt;
};

// "t" toggles, "~25" steps brightness, "1~4~" cycles presets 1-4.
Button buttons[] = {
  {13, "{\"on\":\"t\"}"},
  {12, "{\"on\":true,\"bri\":\"~25\"}"},
  {14, "{\"bri\":\"~-25\"}"},
  {27, "{\"on\":true,\"ps\":\"1~4~\"}"},
};

void sendAll(const char *json) {
  for (const char *host : LIGHTS) {
    HTTPClient http;
    http.begin(String("http://") + host + "/json/state");
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(800);
    int code = http.POST(json);
    Serial.printf("%s -> %d\n", host, code);
    http.end();
  }
}

void setup() {
  Serial.begin(115200);
  for (auto &b : buttons) {
    pinMode(b.pin, INPUT_PULLUP);
    b.last = HIGH;
  }
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);  // faster response to presses
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) delay(200);
  Serial.printf("Connected: %s\n", WiFi.localIP().toString().c_str());
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) WiFi.reconnect();
  uint32_t now = millis();
  for (auto &b : buttons) {
    bool level = digitalRead(b.pin);
    if (level != b.last && now - b.changedAt > 30) {  // 30 ms debounce
      b.changedAt = now;
      b.last = level;
      if (level == LOW) sendAll(b.json);
    }
  }
  delay(5);
}
