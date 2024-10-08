const int ledPin = LED_BUILTIN; // Use internal LED

void setup() {
  Serial.begin(9600); // Initialize serial communication with the BLE module

  pinMode(ledPin, OUTPUT); // Set internal LED as an output

  delay(5000);

  Serial.println("Bluetooth device active, waiting for commands...");
}

void loop() {
  if (Serial.available()) {
    char command = Serial.read();
    if (command == '1') {
      Serial.println("LED on");
      digitalWrite(ledPin, HIGH); // Turn on internal LED
    } else if (command == '0') {
      Serial.println("LED off");
      digitalWrite(ledPin, LOW); // Turn off internal LED
    }
  }
}
