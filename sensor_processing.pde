import processing.serial.*; // importa biblioteca para comunicação serial
import java.awt.event.KeyEvent; // biblioteca de importações para ler os dados da porta serial
import java.io.IOException;
import java.util.ArrayList; // Importa a classe ArrayList

Serial myPort;
// variáveis
String angle="";
String distance="";
String data="";
String noObject;
float pixsDistance; // Distância do objeto em pixels (convertida)
int iAngle, iDistance;
int index1=0;
int index2=0;

// Variáveis para suavizar a varredura
float currentAngle = 0; // Ângulo atual interpolado para suavidade

// Raio máximo do radar em pixels, consistente para varredura e detecção
final float RADAR_MAX_RADIUS = 630; 

// Classe para armazenar cada rastro de detecção de objeto
class DetectedTrace {
  float startX, startY; // Coordenadas de início da linha (posição do objeto)
  float endX, endY;     // Coordenadas de fim da linha (borda do radar)
  long detectionTime;   // Tempo em que o rastro foi criado (millis())
  int initialAlpha = 200; // Transparência inicial do rastro vermelho
  float fadeDuration = 2000; // Duração do rastro em milissegundos (2 segundos)

  DetectedTrace(float sX, float sY, float eX, float eY) {
    this.startX = sX;
    this.startY = sY;
    this.endX = eX;
    this.endY = eY;
    this.detectionTime = millis(); // Marca o tempo de detecção
  }

  // Desenha o rastro com transparência que diminui com o tempo
  void display() {
    long elapsedTime = millis() - detectionTime;
    
    // Calcula o alpha atual, diminuindo-o com o tempo
    float currentAlpha = map(elapsedTime, 0, fadeDuration, initialAlpha, 0);
    
    // Garante que o alpha não seja negativo
    if (currentAlpha < 0) currentAlpha = 0;

    stroke(255, 10, 10, currentAlpha); // Vermelho com transparência variável
    strokeWeight(6); // Espessura da linha do rastro
    line(startX, startY, endX, endY);
  }

  // Verifica se o rastro já desapareceu (alpha <= 0 ou tempo expirou)
  boolean isFaded() {
    return (millis() - detectionTime) > fadeDuration;
  }
}

// Lista para armazenar os rastros de detecção
ArrayList<DetectedTrace> detectedTraces = new ArrayList<DetectedTrace>();

void setup() {
  size (1366, 768); // **MUDE ISTO PARA SUA RESOLUÇÃO DE TELA**
  smooth();
  // myPort = new Serial(this,"COM4", 9600); // descomente esta linha ao usar um Arduino físico
  myPort = new Serial(this, Serial.list()[0], 9600); // Tenta detectar a primeira porta serial automaticamente
  myPort.bufferUntil('.');
  frameRate(60);
}

void draw() {
  // Simula desfoque de movimento e fade para criar um rastro sutil no fundo
  noStroke();
  fill(0, 0, 0, 8); // Fundo preto com leve transparência para o efeito de rastro
  rect(0, 0, width, height - height * 0.065); // Área do radar

  // Desenha a estrutura do radar (arcos e linhas guia)
  drawRadar();

  // Suaviza o movimento do ângulo para a varredura verde
  currentAngle = lerp(currentAngle, iAngle, 0.2);

  drawGreenSweep(); // Desenha a linha de varredura verde principal
  handleObjectDetection(); // Gerencia a adição de rastros vermelhos
  drawRedTraces(); // Desenha todos os rastros vermelhos persistentes
  drawTextAndMarkers(); // Desenha texto e marcadores de ângulo
}

void serialEvent (Serial myPort) {
  data = myPort.readStringUntil('.');
  data = data.substring(0,data.length()-1);
  
  index1 = data.indexOf(",");
  angle = data.substring(0, index1);
  distance = data.substring(index1+1, data.length());
  
  iAngle = int(angle);
  iDistance = int(distance);
}

void drawRadar() {
  pushMatrix();
  translate(width/2,height-height*0.074); // move as coordenadas iniciais para o novo local
  noFill();
  strokeWeight(2);
  stroke(98,245,31); // cor verde
  // desenha as linhas do arco
  arc(0,0,(width-width*0.0625),(width-width*0.0625),PI,TWO_PI); // Arco mais externo
  arc(0,0,(width-width*0.27),(width-width*0.27),PI,TWO_PI);
  arc(0,0,(width-width*0.479),(width-width*0.479),PI,TWO_PI);
  arc(0,0,(width-width*0.687),(width-width*0.687),PI,TWO_PI); // Arco mais interno
  
  // desenha as linhas angulares
  line(0,0,(-width/2)*cos(radians(0)),(-width/2)*sin(radians(0))); // 0 graus (horizontal)
  line(0,0,(-width/2)*cos(radians(30)),(-width/2)*sin(radians(30)));
  line(0,0,(-width/2)*cos(radians(60)),(-width/2)*sin(radians(60)));
  line(0,0,(-width/2)*cos(radians(90)),(-width/2)*sin(radians(90))); // 90 graus (vertical)
  line(0,0,(-width/2)*cos(radians(120)),(-width/2)*sin(radians(120)));
  line(0,0,(-width/2)*cos(radians(150)),(-width/2)*sin(radians(150)));
  line(0,0,(-width/2)*cos(radians(180)),(-width/2)*sin(radians(180))); // 180 graus (horizontal)
  popMatrix();
}

void drawGreenSweep() { // Função para a varredura verde principal
  pushMatrix();
  strokeWeight(9);
  stroke(30,250,60); // cor verde
  translate(width/2,height-height*0.074); // move as coordenadas iniciais para o novo local
  
  // Desenha a linha de varredura verde usando o ângulo suavizado
  line(0,0,RADAR_MAX_RADIUS * cos(radians(currentAngle)),-RADAR_MAX_RADIUS * sin(radians(currentAngle)));
  popMatrix();
}

void handleObjectDetection() { // Gerencia a lógica de detecção para adicionar rastros
  // Esta função não desenha, apenas adiciona novas detecções à lista
  pushMatrix();
  translate(width/2,height-height*0.074); // Centro do radar
  
  // Conversão de cm para pixels (40cm é o alcance máximo de detecção em seu contexto)
  final float PIXELS_PER_CM = RADAR_MAX_RADIUS / 40.0; 
  
  // Calcula a distância do objeto em pixels, limitada ao alcance do radar
  pixsDistance = min(iDistance * PIXELS_PER_CM, RADAR_MAX_RADIUS); 
  
  // Condição para registrar uma nova detecção de rastro
  // O rastro é adicionado se o objeto estiver dentro do alcance e
  // a linha de varredura verde estiver passando pelo ângulo do objeto.
  final float ANGLE_TOLERANCE = 3; // Janela de detecção em graus.
  
  if (iDistance > 0 && iDistance <= 40 && abs(currentAngle - iAngle) < ANGLE_TOLERANCE) { 
    // Calcula as coordenadas do ponto de início da linha (posição do objeto)
    float startX = pixsDistance * cos(radians(iAngle));
    float startY = -pixsDistance * sin(radians(iAngle));
    
    // Calcula as coordenadas do ponto de fim da linha (borda do radar)
    float endX = RADAR_MAX_RADIUS * cos(radians(iAngle));
    float endY = -RADAR_MAX_RADIUS * sin(radians(iAngle));
    
    // Adiciona um novo rastro à lista
    detectedTraces.add(new DetectedTrace(startX, startY, endX, endY));
  }
  popMatrix();
}

void drawRedTraces() { // Desenha todos os rastros vermelhos persistentes
  pushMatrix();
  translate(width/2,height-height*0.074); // Centro do radar
  
  // Itera sobre a lista de rastros
  // Começamos do final para a frente para remover elementos enquanto iteramos com segurança
  for (int i = detectedTraces.size() - 1; i >= 0; i--) {
    DetectedTrace trace = detectedTraces.get(i);
    trace.display(); // Desenha o rastro com transparência
    
    // Remove o rastro se ele já desapareceu completamente
    if (trace.isFaded()) {
      detectedTraces.remove(i);
    }
  }
  popMatrix();
}

void drawTextAndMarkers() { // Combina as funções drawText e drawAngleMarker
  pushMatrix();
  
  fill(0,0,0); // Fundo preto para a área de texto
  noStroke();
  rect(0, height-height*0.0648, width, height); // Limpa a área de texto
  
  fill(98,245,31); // Cor verde para o texto
  
  // Texto de distâncias (10cm, 20cm, etc.)
  textSize(25);
  text("10cm",width-width*0.3854,height-height*0.0833);
  text("20cm",width-width*0.281,height-height*0.0833);
  text("30cm",width-width*0.177,height-height*0.0833);
  text("40cm",width-width*0.0729,height-height*0.0833);
  
  // Status do objeto, ângulo e distância
  textSize(40);
  if(iDistance > 40 || iDistance == 0) { // Adicionei iDistance == 0 para "Fora do Radar" para leituras ausentes
    noObject = "Fora do Radar";
  } else {
    noObject = "Objeto Detectado";
  }
  
  text("Objeto: " + noObject, width-width*0.875, height-height*0.0277);
  text("Ângulo: " + iAngle +" °", width-width*0.48, height-height*0.0277);
  text("Distância: ", width-width*0.26, height-height*0.0277);
  if(iDistance > 0 && iDistance <= 40) { // Exibe a distância apenas se estiver dentro do alcance válido
    text("         " + iDistance +" cm", width-width*0.225, height-height*0.0277);
  } else {
    text("         --- cm", width-width*0.225, height-height*0.0277); // Mostra "---" se fora do alcance
  }
  
  // Marcadores de ângulo
  textSize(25);
  fill(98,245,31); // Cor verde para os marcadores
  
  // Funções simplificadas para desenhar os marcadores de ângulo, similar ao seu código original.
  // Use pushMatrix/popMatrix para isolar as transformações de cada texto.
  
  // 30°
  pushMatrix();
  translate(width/2 + RADAR_MAX_RADIUS * cos(radians(30)), (height - height*0.074) - RADAR_MAX_RADIUS * sin(radians(30)));
  rotate(-radians(30)); // Rotação para alinhar o texto com o ângulo
  text("30°", 0, 0);
  popMatrix();
  
  // 60°
  pushMatrix();
  translate(width/2 + RADAR_MAX_RADIUS * cos(radians(60)), (height - height*0.074) - RADAR_MAX_RADIUS * sin(radians(60)));
  rotate(-radians(60));
  text("60°", 0, 0);
  popMatrix();
  
  // 90°
  pushMatrix();
  translate(width/2 + RADAR_MAX_RADIUS * cos(radians(90)), (height - height*0.074) - RADAR_MAX_RADIUS * sin(radians(90)));
  rotate(-radians(90));
  text("90°", 0, 0);
  popMatrix();
  
  // 120°
  pushMatrix();
  translate(width/2 + RADAR_MAX_RADIUS * cos(radians(120)), (height - height*0.074) - RADAR_MAX_RADIUS * sin(radians(120)));
  rotate(-radians(120));
  text("120°", 0, 0);
  popMatrix();
  
  // 150°
  pushMatrix();
  translate(width/2 + RADAR_MAX_RADIUS * cos(radians(150)), (height - height*0.074) - RADAR_MAX_RADIUS * sin(radians(150)));
  rotate(-radians(150));
  text("150°", 0, 0);
  popMatrix();
  
  popMatrix(); // Fecha o pushMatrix inicial de drawTextAndMarkers
}
