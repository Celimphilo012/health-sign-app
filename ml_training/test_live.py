import os
import sys
import numpy as np

os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

if not os.path.exists('model/gesture_model.tflite'):
    print("ERROR: model/gesture_model.tflite not found!")
    print("Run these first:")
    print("  1. python extract_landmarks.py")
    print("  2. python train.py")
    sys.exit(1)

import cv2
import tensorflow as tf
import mediapipe as mp

print("Loading model...")
interpreter = tf.lite.Interpreter(
    model_path='model/gesture_model.tflite')
interpreter.allocate_tensors()
input_details  = interpreter.get_input_details()
output_details = interpreter.get_output_details()

with open('model/gesture_labels.txt') as f:
    labels = f.read().strip().split('\n')

print(f"Classes: {labels}")

mp_hands   = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5,
)

gesture_desc = {
    'Closed_Fist':        'I am in pain',
    'Open_Palm':          'Stop / Wait',
    'I_Feel_Cold':        'I feel cold / shivering',
    'Pointing_Up':        'I need attention',
    'I_Need_Water':       'I need water',
    'Thumb_Up':           'Yes / I agree',
    'No_Disagree':        'No / I disagree',
    'Need_Medicine':      'I need medicine',
    'Need_Restroom':      'I need the restroom',
    'Severe_Pain':        'I am in severe pain',
    'Victory':            'I am okay',
    'Need_Water':         'I need water urgently',
    'ILoveYou':           'Thank you',
    'Chest_Pain':         'I have chest pain',
    'Headache':           'I have a headache',
    'Nausea':             'I feel nauseous',
    'Dizzy':              'I feel dizzy',
    'Difficulty_Breathing': 'Difficulty breathing',
    'Call_Nurse':         'Please call a nurse',
}


def normalize_landmarks(landmarks):
    wrist_x, wrist_y, wrist_z = landmarks[0], landmarks[1], landmarks[2]
    normalized = []
    for i in range(0, len(landmarks), 3):
        normalized.extend([
            landmarks[i]   - wrist_x,
            landmarks[i+1] - wrist_y,
            landmarks[i+2] - wrist_z,
        ])
    max_val = max(abs(v) for v in normalized) or 1.0
    return [v / max_val for v in normalized]


def predict_gesture(landmarks):
    normalized  = normalize_landmarks(landmarks)
    input_data  = np.array([normalized], dtype=np.float32)
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    output      = interpreter.get_tensor(output_details[0]['index'])[0]
    idx         = int(np.argmax(output))
    confidence  = float(output[idx])
    return labels[idx], confidence


print("\nOpening webcam... Press Q to quit")
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("ERROR: Could not open webcam!")
    sys.exit(1)

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    frame = cv2.flip(frame, 1)
    rgb   = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = hands.process(rgb)

    gesture_text = "No hand detected"
    description  = ""
    confidence   = 0.0
    color        = (128, 128, 128)

    if results.multi_hand_landmarks:
        for hand_landmarks in results.multi_hand_landmarks:
            mp_drawing.draw_landmarks(
                frame, hand_landmarks, mp_hands.HAND_CONNECTIONS,
                mp_drawing.DrawingSpec(color=(0, 191, 165), thickness=2),
                mp_drawing.DrawingSpec(color=(88, 166, 255), thickness=2),
            )
            coords = []
            for lm in hand_landmarks.landmark:
                coords.extend([lm.x, lm.y, lm.z])

            gesture, conf = predict_gesture(coords)
            confidence = conf

            if conf >= 0.85:
                gesture_text = gesture
                description  = gesture_desc.get(gesture, '')
                color        = (0, 220, 0)
            elif conf >= 0.65:
                gesture_text = f"{gesture}?"
                description  = "Hold steady..."
                color        = (0, 165, 255)
            else:
                gesture_text = "Uncertain"
                description  = "Show gesture clearly"
                color        = (80, 80, 200)

    h, w = frame.shape[:2]
    cv2.rectangle(frame, (0, 0), (w, 85), (13, 17, 23), -1)
    cv2.putText(frame, gesture_text, (15, 40),
                cv2.FONT_HERSHEY_SIMPLEX, 1.1, color, 2)
    cv2.putText(frame, description, (15, 68),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200, 200, 200), 1)

    if confidence > 0:
        bar_w = int((w - 30) * confidence)
        cv2.rectangle(frame, (15, 75), (w - 15, 82), (50, 50, 50), -1)
        cv2.rectangle(frame, (15, 75), (15 + bar_w, 82), color, -1)

    cv2.rectangle(frame, (0, h - 30), (w, h), (13, 17, 23), -1)
    cv2.putText(
        frame,
        f"HealthSign Custom Model | Conf: {confidence*100:.0f}% | Q=Quit",
        (10, h - 8),
        cv2.FONT_HERSHEY_SIMPLEX, 0.5, (139, 148, 158), 1,
    )

    cv2.imshow('HealthSign — Custom Gesture Model', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
hands.close()
print("Done!")