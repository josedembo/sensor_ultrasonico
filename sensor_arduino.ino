#include <Servo.h>               // Controle do servo motor
#include <Wire.h>                // Comunicação I2C
#include <LiquidCrystal_I2C.h>   // Biblioteca para LCD I2C

// LCD I2C no endereço padrão 0x27, com 16 colunas e 2 linhas
LiquidCrystal_I2C lcd(0x27, 16, 2);

// Pinos do sensor ultrassônico
const int trigPin = 10;
const int echoPin = 11;

// Pinos dos LEDs e buzzer
const int redLedPin = 3;
const int yellowLedPin = 5;
const int greenLedPin = 7;
const int buzzerPin = 6;

// Servo motor
Servo myServo;

// Variáveis de medição
long duration;
int distance;
int angle;  // Variável para armazenar o ângulo

// Limites de alerta
const int warningDistance = 50; // < 50cm → perigo
const int safeDistance = 100;   // >= 100cm → seguro

void setup() {
  // Inicia LCD
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("  Sistema Iniciado");

  // Define pinos do sensor ultrassônico
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);

  // Define pinos dos LEDs e buzzer
  pinMode(redLedPin, OUTPUT);
  pinMode(yellowLedPin, OUTPUT);
  pinMode(greenLedPin, OUTPUT);
  pinMode(buzzerPin, OUTPUT);

  Serial.begin(9600); // Comunicação serial
  myServo.attach(12); // Servo no pino 12

  delay(2000);
  lcd.clear();
}

void loop() {
  // Varre de 15° a 165°
  for (int i = 15; i <= 165; i++) {
    angle = i;
    myServo.write(angle);
    delay(30);
    distance = calculateDistance();

    updateIndicators(distance);
    updateLCD(angle, distance);

    Serial.print(angle);
    Serial.print(",");
    Serial.print(distance);
    Serial.print(".");
  }

  // Retorna de 165° a 15°
  for (int i = 165; i >= 15; i--) {
    angle = i;
    myServo.write(angle);
    delay(30);
    distance = calculateDistance();

    updateIndicators(distance);
    updateLCD(angle, distance);

    Serial.print(angle);
    Serial.print(",");
    Serial.print(distance);
    Serial.print(".");
  }
}

// Calcula distância com sensor ultrassônico
int calculateDistance() {
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  duration = pulseIn(echoPin, HIGH);
  distance = duration * 0.034 / 2;

  return distance;
}

// Atualiza LEDs e buzzer
void updateIndicators(int distance) {
  digitalWrite(redLedPin, LOW);
  digitalWrite(yellowLedPin, LOW);
  digitalWrite(greenLedPin, LOW);
  noTone(buzzerPin);

  if (distance == 0 || distance > 250) return;

  if (distance < warningDistance) {
    digitalWrite(redLedPin, HIGH);
    tone(buzzerPin, 5000);
  } else if (distance < safeDistance) {
    digitalWrite(yellowLedPin, HIGH);
    tone(buzzerPin, 1000, 200);
  } else {
    digitalWrite(greenLedPin, HIGH);
  }
}

// Atualiza o LCD com os dados
void updateLCD(int angle, int distance) {
  lcd.clear();

  if (distance < 30 && distance > 0) {
    lcd.setCursor(0, 0);
    lcd.print("Objeto detectado!");
    lcd.setCursor(0, 1);
    lcd.print("Dist: ");
    lcd.print(distance);
    lcd.print(" cm   ");
  } else {
    lcd.setCursor(0, 0);
    lcd.print("Ang: ");
    lcd.print(angle);
    lcd.print(" deg   ");
    
    lcd.setCursor(0, 1);
    lcd.print("Dist: ");
    lcd.print(distance);
    lcd.print(" cm   ");
  }
}
