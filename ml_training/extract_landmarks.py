import os
import csv
import cv2
import numpy as np
from pathlib import Path

os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import mediapipe as mp

mp_hands = mp.solutions.hands

hands = mp_hands.Hands(
    static_image_mode=True,
    max_num_hands=1,
    min_detection_confidence=0.5,
)

GESTURE_CLASSES = {
    'A': 'Closed_Fist',
    'B': 'Open_Palm',
    'C': 'I_Feel_Cold',
    'D': 'Pointing_Up',
    'I': 'I_Need_Water',
    'L': 'Thumb_Up',
    'N': 'No_Disagree',
    'O': 'Need_Medicine',
    'R': 'Need_Restroom',
    'S': 'Severe_Pain',
    'V': 'Victory',
    'W': 'Need_Water',
    'Y': 'ILoveYou',
    'CHEST_PAIN':  'Chest_Pain',
    'HEADACHE':    'Headache',
    'NAUSEA':      'Nausea',
    'DIZZY':       'Dizzy',
    'BREATHLESS':  'Difficulty_Breathing',
    'CALL_NURSE':  'Call_Nurse',
    'HELLO':'hello',
    # ── Custom — NEW ──────────────────────────────────
    'HUNGRY':         'I_Am_Hungry',
    'THIRSTY':        'I_Am_Thirsty',
    'HOT':            'I_Feel_Hot',
    'COLD':           'I_Feel_Cold_Custom',
    'TOILET':         'I_Need_Toilet',
    'MEDICINE':       'I_Need_Medicine',
    'SLEEP':          'I_Want_Sleep',
    'MORE_PAIN':      'Pain_Getting_Worse',
    'LESS_PAIN':      'Pain_Getting_Better',
    'CANT_BREATHE':   'Cannot_Breathe',
    'VOMIT':          'Going_To_Vomit',
    'FAMILY':         'Call_My_Family',
    'THANK_YOU':      'Thank_You',
    'CONFUSED':       'I_Am_Confused',
    'REPEAT':         'Please_Repeat',
    'UNDERSTAND':     'I_Understand',
    'DONT_UNDERSTAND':'I_Dont_Understand',
    'LYING_DOWN':     'I_Want_To_Lie_Down',
    'SIT_UP':         'Help_Me_Sit_Up',
    'BLEEDING':       'I_Am_Bleeding',
    'SWELLING':       'I_Have_Swelling',
    'ITCHING':        'I_Am_Itching',
    'ALLERGIC':       'Allergic_Reaction',

}

DATASET_PATH = Path('dataset/asl_alphabet_train/asl_alphabet_train')
OUTPUT_CSV = 'landmarks.csv'
MAX_PER_CLASS = 500


def extract_landmarks(image_path):
    image = cv2.imread(str(image_path))
    if image is None:
        return None
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = hands.process(image_rgb)
    if not results.multi_hand_landmarks:
        return None
    landmarks = results.multi_hand_landmarks[0]
    coords = []
    for lm in landmarks.landmark:
        coords.extend([lm.x, lm.y, lm.z])
    return coords


def normalize_landmarks(landmarks):
    wrist_x = landmarks[0]
    wrist_y = landmarks[1]
    wrist_z = landmarks[2]
    normalized = []
    for i in range(0, len(landmarks), 3):
        normalized.extend([
            landmarks[i]   - wrist_x,
            landmarks[i+1] - wrist_y,
            landmarks[i+2] - wrist_z,
        ])
    max_val = max(abs(v) for v in normalized) or 1.0
    normalized = [v / max_val for v in normalized]
    return normalized


def main():
    print("=" * 50)
    print("HealthSign — Landmark Extraction")
    print("=" * 50)

    if not DATASET_PATH.exists():
        print(f"\nERROR: Dataset not found at: {DATASET_PATH}")
        print("Expected structure:")
        print("  dataset/asl_alphabet_train/asl_alphabet_train/A/")
        print("  dataset/asl_alphabet_train/asl_alphabet_train/B/")
        print("\nSearching for dataset folders...")
        for p in Path('dataset').rglob('*'):
            if p.is_dir():
                print(f"  Found: {p}")
        return

    rows = []
    headers = ['label'] + [f'lm_{i}' for i in range(63)]
    total_processed = 0
    total_skipped = 0

    for folder_name, gesture_name in GESTURE_CLASSES.items():
        folder = DATASET_PATH / folder_name
        if not folder.exists():
            print(f"WARNING: Folder not found: {folder}")
            continue

        images = (list(folder.glob('*.jpg')) +
                  list(folder.glob('*.png')) +
                  list(folder.glob('*.jpeg')))
        images = images[:MAX_PER_CLASS]
        class_count = 0

        print(f"\nProcessing [{folder_name}] -> {gesture_name} "
              f"({len(images)} images)")

        for idx, img_path in enumerate(images):
            if idx % 100 == 0:
                print(f"  {idx}/{len(images)}...", end='\r')

            landmarks = extract_landmarks(img_path)
            if landmarks is None:
                total_skipped += 1
                continue

            normalized = normalize_landmarks(landmarks)
            rows.append([gesture_name] + normalized)
            total_processed += 1
            class_count += 1

        print(f"  + {gesture_name}: {class_count} samples")

    if not rows:
        print("\nERROR: No landmarks extracted!")
        return

    print(f"\nSaving to {OUTPUT_CSV}...")
    with open(OUTPUT_CSV, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    print("\n" + "=" * 50)
    print("EXTRACTION COMPLETE")
    print("=" * 50)
    print(f"Total extracted : {total_processed}")
    print(f"Total skipped   : {total_skipped}")
    print(f"Output file     : {OUTPUT_CSV}")
    print(f"File size       : {os.path.getsize(OUTPUT_CSV)/1024:.1f} KB")

    from collections import Counter
    dist = Counter(r[0] for r in rows)
    print("\nClass distribution:")
    for label, count in sorted(dist.items()):
        bar = '#' * (count // 10)
        print(f"  {label:<25} {count:>4}  {bar}")


if __name__ == '__main__':
    main()
    hands.close()