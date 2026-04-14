import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime

os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import tensorflow as tf
from tensorflow import keras
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix

timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

print("=" * 50)
print("HealthSign — Gesture Classifier Training")
print("=" * 50)
print(f"TensorFlow : {tf.__version__}")
print(f"Run ID     : {timestamp}")

if not os.path.exists('landmarks.csv'):
    print("\nERROR: landmarks.csv not found!")
    print("Run extract_landmarks.py first.")
    exit(1)

print("\nLoading landmarks.csv...")
df = pd.read_csv('landmarks.csv')
print(f"Total samples : {len(df)}")
print(f"\nClass distribution:")
print(df['label'].value_counts().to_string())

X = df.drop('label', axis=1).values.astype(np.float32)
y = df['label'].values

encoder = LabelEncoder()
y_encoded = encoder.fit_transform(y)
class_names = list(encoder.classes_)
num_classes = len(class_names)

print(f"\nClasses ({num_classes} total):")
for i, name in enumerate(class_names):
    print(f"  {i}: {name}")

X_train, X_temp, y_train, y_temp = train_test_split(
    X, y_encoded, test_size=0.3, random_state=42, stratify=y_encoded)
X_val, X_test, y_val, y_test = train_test_split(
    X_temp, y_temp, test_size=0.5, random_state=42, stratify=y_temp)

print(f"\nDataset split:")
print(f"  Train : {len(X_train)}")
print(f"  Val   : {len(X_val)}")
print(f"  Test  : {len(X_test)}")

print("\nBuilding model...")
model = keras.Sequential([
    keras.layers.Input(shape=(63,)),
    keras.layers.Dense(256, activation='relu'),
    keras.layers.BatchNormalization(),
    keras.layers.Dropout(0.3),
    keras.layers.Dense(128, activation='relu'),
    keras.layers.BatchNormalization(),
    keras.layers.Dropout(0.3),
    keras.layers.Dense(64, activation='relu'),
    keras.layers.BatchNormalization(),
    keras.layers.Dropout(0.2),
    keras.layers.Dense(32, activation='relu'),
    keras.layers.Dropout(0.1),
    keras.layers.Dense(num_classes, activation='softmax'),
], name='HealthSign_GestureClassifier')

model.summary()

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=0.001),
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy'],
)

os.makedirs('model', exist_ok=True)
os.makedirs('plots', exist_ok=True)

callbacks = [
    keras.callbacks.EarlyStopping(
        monitor='val_accuracy',
        patience=15,
        restore_best_weights=True,
        verbose=1,
    ),
    keras.callbacks.ModelCheckpoint(
        'model/best_model.keras',
        monitor='val_accuracy',
        save_best_only=True,
        verbose=0,
    ),
    keras.callbacks.ReduceLROnPlateau(
        monitor='val_loss',
        factor=0.5,
        patience=5,
        min_lr=0.000001,
        verbose=1,
    ),
]

print("\nTraining started...")
history = model.fit(
    X_train, y_train,
    epochs=100,
    batch_size=32,
    validation_data=(X_val, y_val),
    callbacks=callbacks,
    verbose=1,
)

print("\nEvaluating...")
test_loss, test_acc = model.evaluate(X_test, y_test, verbose=0)
print(f"\nTest Accuracy : {test_acc*100:.2f}%")
print(f"Test Loss     : {test_loss:.4f}")

y_pred = np.argmax(model.predict(X_test, verbose=0), axis=1)
print("\nClassification Report:")
print(classification_report(y_test, y_pred, target_names=class_names))

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
fig.suptitle(
    f'HealthSign Gesture Classifier — Run {timestamp}',
    fontsize=13)

ax1.plot(history.history['accuracy'],
         label='Train', color='#00BFA5', linewidth=2)
ax1.plot(history.history['val_accuracy'],
         label='Validation', color='#58A6FF',
         linewidth=2, linestyle='--')
ax1.set_title('Accuracy over epochs')
ax1.set_xlabel('Epoch')
ax1.set_ylabel('Accuracy')
ax1.legend()
ax1.grid(True, alpha=0.3)

ax2.plot(history.history['loss'],
         label='Train', color='#00BFA5', linewidth=2)
ax2.plot(history.history['val_loss'],
         label='Validation', color='#58A6FF',
         linewidth=2, linestyle='--')
ax2.set_title('Loss over epochs')
ax2.set_xlabel('Epoch')
ax2.set_ylabel('Loss')
ax2.legend()
ax2.grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig(f'plots/training_curves_{timestamp}.png',
            dpi=150, bbox_inches='tight')
plt.savefig('plots/training_curves_latest.png',
            dpi=150, bbox_inches='tight')
print(f"Saved: plots/training_curves_{timestamp}.png")

cm = confusion_matrix(y_test, y_pred)
plt.figure(figsize=(max(8, num_classes), max(6, num_classes - 1)))
sns.heatmap(
    cm, annot=True, fmt='d', cmap='Blues',
    xticklabels=class_names,
    yticklabels=class_names,
)
plt.title(f'Confusion Matrix — Run {timestamp}')
plt.ylabel('True Label')
plt.xlabel('Predicted Label')
plt.xticks(rotation=45, ha='right')
plt.yticks(rotation=0)
plt.tight_layout()
plt.savefig(f'plots/confusion_matrix_{timestamp}.png',
            dpi=150, bbox_inches='tight')
plt.savefig('plots/confusion_matrix_latest.png',
            dpi=150, bbox_inches='tight')
print(f"Saved: plots/confusion_matrix_{timestamp}.png")

print("\nConverting to TFLite...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

tflite_path = 'model/gesture_model.tflite'
with open(tflite_path, 'wb') as f:
    f.write(tflite_model)
size_kb = os.path.getsize(tflite_path) / 1024
print(f"Saved: {tflite_path} ({size_kb:.1f} KB)")

with open('model/gesture_labels.txt', 'w') as f:
    f.write('\n'.join(class_names))
print("Saved: model/gesture_labels.txt")

epochs_run = len(history.history['accuracy'])
best_val = max(history.history['val_accuracy'])

summary = f"""HealthSign Gesture Classifier — Training Summary
{"=" * 50}
Run ID        : {timestamp}

Dataset
-------
Total samples : {len(df)}
Train         : {len(X_train)}
Validation    : {len(X_val)}
Test          : {len(X_test)}
Classes       : {class_names}

Training
--------
Epochs run    : {epochs_run}
Best val acc  : {best_val*100:.2f}%
Test accuracy : {test_acc*100:.2f}%
Test loss     : {test_loss:.4f}

Model
-----
Input shape   : (63,) — 21 landmarks x (x, y, z)
Output shape  : ({num_classes},) softmax
TFLite size   : {size_kb:.1f} KB
Architecture  : Dense 256->128->64->32->{num_classes}

Class Mapping
-------------
"""
for i, name in enumerate(class_names):
    summary += f"  {i}: {name}\n"

with open('model/training_summary.txt', 'w') as f:
    f.write(summary)
print("Saved: model/training_summary.txt")

print("\n" + "=" * 50)
print("TRAINING COMPLETE")
print("=" * 50)
print(f"Test Accuracy : {test_acc*100:.2f}%")
print(f"Epochs run    : {epochs_run}")
print(f"Best val acc  : {best_val*100:.2f}%")
print(f"Model size    : {size_kb:.1f} KB")
print(f"\nFiles saved:")
print(f"  model/gesture_model.tflite")
print(f"  model/gesture_labels.txt")
print(f"  model/training_summary.txt")
print(f"  model/best_model.keras")
print(f"  plots/training_curves_{timestamp}.png")
print(f"  plots/training_curves_latest.png")
print(f"  plots/confusion_matrix_{timestamp}.png")
print(f"  plots/confusion_matrix_latest.png")