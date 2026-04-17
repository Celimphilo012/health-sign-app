
import cv2
import os
from pathlib import Path

DATASET_PATH = Path('dataset/asl_alphabet_train/asl_alphabet_train')
PHOTOS_PER_GESTURE = 200
COUNTDOWN_SECONDS  = 3

GESTURES_TO_COLLECT = [
    {
        'folder':      'CHEST_PAIN',
        'name':        'Chest Pain',
        'instruction': 'Place your hand flat on your chest',
    },
    {
        'folder':      'HEADACHE',
        'name':        'Headache',
        'instruction': 'Touch your forehead with your fingers',
    },
    {
        'folder':      'NAUSEA',
        'name':        'Nausea',
        'instruction': 'Place hand on your stomach area',
    },
    {
        'folder':      'DIZZY',
        'name':        'Dizzy',
        'instruction': 'Point finger and make circular motion',
    },
    {
        'folder':      'BREATHLESS',
        'name':        'Difficulty Breathing',
        'instruction': 'Both hands on chest, fingers spread wide',
    },
    {
        'folder':      'CALL_NURSE',
        'name':        'Call Nurse',
        'instruction': 'Wave hand side to side above shoulder',
    },
    {
'folder':'HELLO',
'name':'Hello',
'instruction':'Wave hand infront of your face',
    },
    # ── NEW hospital gestures ─────────────────────────
    {
        'folder':      'HUNGRY',
        'name':        'I Am Hungry',
        'instruction': 'Rub your stomach in a circular motion',
    },
    {
        'folder':      'THIRSTY',
        'name':        'I Am Thirsty',
        'instruction': 'Point to your throat with one finger',
    },
    {
        'folder':      'HOT',
        'name':        'I Feel Hot',
        'instruction': 'Fan your face with your open hand',
    },
    {
        'folder':      'COLD',
        'name':        'I Feel Cold',
        'instruction': 'Wrap arms around yourself and shiver',
    },
    {
        'folder':      'TOILET',
        'name':        'I Need Toilet',
        'instruction': 'Cross your legs and point downward',
    },
    {
        'folder':      'MEDICINE',
        'name':        'I Need Medicine',
        'instruction': 'Tap your inner wrist like checking pulse',
    },
    {
        'folder':      'SLEEP',
        'name':        'I Want to Sleep',
        'instruction': 'Tilt your head and rest cheek on palm',
    },
    {
        'folder':      'MORE_PAIN',
        'name':        'Pain Getting Worse',
        'instruction': 'Point to painful area then make fist',
    },
    {
        'folder':      'LESS_PAIN',
        'name':        'Pain Getting Better',
        'instruction': 'Thumbs up then open palm slowly',
    },
    {
        'folder':      'CANT_BREATHE',
        'name':        'Cannot Breathe',
        'instruction': 'Both hands on throat, lean forward',
    },
    {
        'folder':      'VOMIT',
        'name':        'Going to Vomit',
        'instruction': 'Hand over mouth, lean forward slightly',
    },
    {
        'folder':      'FAMILY',
        'name':        'Call My Family',
        'instruction': 'Point to ring finger then mime phone call',
    },
    {
        'folder':      'THANK_YOU',
        'name':        'Thank You',
        'instruction': 'Flat hand from chin moving forward',
    },
    {
        'folder':      'CONFUSED',
        'name':        'I Am Confused',
        'instruction': 'Point to head and shake side to side',
    },
    {
        'folder':      'REPEAT',
        'name':        'Please Repeat',
        'instruction': 'Circle index finger in the air',
    },
    {
        'folder':      'UNDERSTAND',
        'name':        'I Understand',
        'instruction': 'Index finger pointing up then nod',
    },
    {
        'folder':      'DONT_UNDERSTAND',
        'name':        'I Do Not Understand',
        'instruction': 'Cross both index fingers in an X',
    },
    {
        'folder':      'LYING_DOWN',
        'name':        'I Want to Lie Down',
        'instruction': 'Flat palm facing down, move downward',
    },
    {
        'folder':      'SIT_UP',
        'name':        'Help Me Sit Up',
        'instruction': 'Flat palm facing up, move upward slowly',
    },
    {
        'folder':      'BLEEDING',
        'name':        'I Am Bleeding',
        'instruction': 'Point to wound area with two fingers',
    },
    {
        'folder':      'SWELLING',
        'name':        'I Have Swelling',
        'instruction': 'Cup both hands around affected area',
    },
    {
        'folder':      'ITCHING',
        'name':        'I Am Itching',
        'instruction': 'Scratch arm with opposite hand fingers',
    },
    {
        'folder':      'ALLERGIC',
        'name':        'Allergic Reaction',
        'instruction': 'Point to skin then wave hand away',
    },
]


def collect_gesture(gesture_info, cap):
    folder = DATASET_PATH / gesture_info['folder']
    folder.mkdir(parents=True, exist_ok=True)

    existing   = list(folder.glob('*.jpg'))
    start_idx  = len(existing)

    print(f"\n{'='*50}")
    print(f"Gesture     : {gesture_info['name']}")
    print(f"Instruction : {gesture_info['instruction']}")
    print(f"Target      : {PHOTOS_PER_GESTURE} photos")
    print(f"Already have: {start_idx} photos")
    print(f"{'='*50}")
    print("Press SPACE to start  |  Q to skip")

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame = cv2.flip(frame, 1)
        h, w  = frame.shape[:2]

        cv2.rectangle(frame, (0, 0), (w, 110), (13, 17, 23), -1)
        cv2.putText(frame, gesture_info['name'],
                    (10, 35), cv2.FONT_HERSHEY_SIMPLEX,
                    1.0, (0, 191, 165), 2)
        cv2.putText(frame, gesture_info['instruction'],
                    (10, 68), cv2.FONT_HERSHEY_SIMPLEX,
                    0.6, (200, 200, 200), 1)
        cv2.putText(frame, "SPACE = Start   Q = Skip",
                    (10, 98), cv2.FONT_HERSHEY_SIMPLEX,
                    0.5, (139, 148, 158), 1)
        cv2.imshow('Gesture Collection — HealthSign', frame)

        key = cv2.waitKey(1) & 0xFF
        if key == ord(' '):
            break
        elif key == ord('q'):
            return start_idx

    for i in range(COUNTDOWN_SECONDS, 0, -1):
        for _ in range(10):
            ret, frame = cap.read()
            if not ret:
                break
            frame = cv2.flip(frame, 1)
            h, w  = frame.shape[:2]
            cv2.rectangle(frame, (0, 0), (w, 120), (13, 17, 23), -1)
            cv2.putText(frame, f"Get ready... {i}",
                        (w//2 - 150, 75),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        2.0, (0, 191, 165), 3)
            cv2.imshow('Gesture Collection — HealthSign', frame)
            cv2.waitKey(100)

    collected = start_idx
    target    = start_idx + PHOTOS_PER_GESTURE
    print(f"Collecting... hold the gesture steady!")

    while collected < target:
        ret, frame = cap.read()
        if not ret:
            break
        frame = cv2.flip(frame, 1)
        h, w  = frame.shape[:2]

        filename = folder / f'{gesture_info["folder"]}_{collected:04d}.jpg'
        cv2.imwrite(str(filename), frame)
        collected += 1

        done     = collected - start_idx
        progress = done / PHOTOS_PER_GESTURE
        bar_w    = int((w - 40) * progress)

        cv2.rectangle(frame, (0, 0), (w, 80), (13, 17, 23), -1)
        cv2.putText(frame,
                    f"Recording: {done}/{PHOTOS_PER_GESTURE}",
                    (10, 38),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 191, 165), 2)
        cv2.rectangle(frame, (20, 52), (w-20, 68), (50, 50, 50), -1)
        cv2.rectangle(frame, (20, 52), (20+bar_w, 68), (0, 191, 165), -1)
        cv2.imshow('Gesture Collection — HealthSign', frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    done = collected - start_idx
    print(f"+ Collected {done} photos for {gesture_info['name']}")
    return collected


def main():
    print("=" * 50)
    print("HealthSign — Custom Gesture Collection")
    print("=" * 50)
    print(f"Photos per gesture : {PHOTOS_PER_GESTURE}")
    print(f"Gestures to record : {len(GESTURES_TO_COLLECT)}")
    print(f"Save location      : {DATASET_PATH}")

    DATASET_PATH.mkdir(parents=True, exist_ok=True)

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("ERROR: Could not open webcam!")
        return

    total = 0
    for i, gesture in enumerate(GESTURES_TO_COLLECT):
        print(f"\n[{i+1}/{len(GESTURES_TO_COLLECT)}] {gesture['name']}")
        count  = collect_gesture(gesture, cap)
        total += count

    cap.release()
    cv2.destroyAllWindows()

    print("\n" + "=" * 50)
    print("COLLECTION COMPLETE")
    print("=" * 50)
    print(f"Total photos collected: {total}")
    print("\nNext steps:")
    print("  python extract_landmarks.py")
    print("  python train.py")


if __name__ == '__main__':
    main()