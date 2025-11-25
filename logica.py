from ultralytics import YOLO
import cv2
import requests
import json
import time

# --- CONFIGURACIÓN DE AWS ---
# ¡IMPORTANTE! Reemplaza esta URL con el valor de 'InsertApiUrl'
# que obtuviste en la salida (Outputs) de tu despliegue de CloudFormation.
AWS_INSERT_API_URL = "https://TU_API_GATEWAY_ID.execute-api.REGION.amazonaws.com/dev/classify" 

# --- CONFIGURACIÓN YOLO ---
# Carga el modelo entrenado
model = YOLO("best.pt") 

# Intenta abrir la cámara
# Si sigue saliendo 'index out of range', prueba con 1, 2, etc.
cap = cv2.VideoCapture(0) 

# Función para enviar datos a AWS
def send_to_aws(classification_label, confidence):
    """
    Construye el payload y realiza una petición POST a AWS API Gateway.
    """
    # 1. Preparar el payload JSON
    data = {
        # Ejemplo: "Mal Estado" o "Buen Estado" (debe coincidir con la lógica del modelo)
        "classification": classification_label, 
        "confidence": confidence,
        # ID para rastrear desde qué dispositivo viene el dato
        "device_id": "Laptop_Faja_Principal" 
    }
    
    try:
        # 2. Enviar la petición POST
        response = requests.post(AWS_INSERT_API_URL, json=data, timeout=5)
        
        # 3. Verificar la respuesta
        if response.status_code == 200:
            print(f"✅ Éxito al enviar a AWS: {classification_label}")
        else:
            print(f"❌ Error al enviar a AWS. Código: {response.status_code}. Respuesta: {response.text}")

    except requests.exceptions.RequestException as e:
        print(f"❌ Error de conexión con AWS API: {e}")


if not cap.isOpened():
    print("Error: No se pudo abrir la cámara. Verifica el índice (0, 1, 2) y los permisos.")
else:
    print("Iniciando detección en tiempo real. Presiona ESC para salir...")
    
    while cap.isOpened():
        ret, frame = cap.read()
        
        if not ret:
            print("Error: El stream de la cámara terminó.")
            break 

        # 1. Realizar la inferencia con YOLO
        results = model(frame, verbose=False) 
        
        # 2. Analizar el resultado de la inferencia
        if results and len(results[0].boxes) > 0:
            
            # Solo analizamos la primera detección para la faja (fruta que está lista para clasificar)
            box = results[0].boxes[0]
            
            # Obtener el ID de la clase detectada (ej. 0 para Mal Estado, 1 para Buen Estado)
            class_id = int(box.cls[0].item()) 
            
            # Obtener el nombre de la clase
            # Asumiendo que tu modelo tiene names = {0: 'Mal Estado', 1: 'Buen Estado'}
            classification_label = model.names[class_id]
            
            # Obtener la confianza (0.0 a 1.0)
            confidence = float(box.conf[0].item())
            
            # 3. Mostrar la clasificación y enviar a AWS
            print(f"Clasificado: {classification_label} (Confianza: {confidence:.2f})")
            
            # 4. Enviar los datos al backend de AWS
            # Idealmente, solo enviarías a AWS si hay una nueva fruta o un cambio de estado.
            send_to_aws(classification_label, confidence)
            
            # Aquí iría el código para enviar la señal al Arduino (Serial.write)
            # send_to_arduino(classification_label) 

        # 5. Visualización (Interfaz de OpenCV)
        annotated_frame = results[0].plot()
        cv2.imshow("YOLO Inference", annotated_frame)
        
        # Espera un poco para no saturar la CPU con inferencias y llamadas a la API
        time.sleep(0.5) 
        
        # Presionar ESC (código 27) para salir
        if cv2.waitKey(1) & 0xFF == 27:
            break


cap.release()
cv2.destroyAllWindows()