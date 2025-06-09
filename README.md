# Fingerprint Identification System

## 📖 Project Description

An intelligent fingerprint identification system developed in MATLAB. The project utilizes neural networks to recognize fingerprints based on minutiae extraction and analysis.

## 🎯 Project Goals

- Build a fingerprint identification system using MATLAB
- Compare performance of different neural network architectures (Pattern Recognition Network and CNN))
- Use genetic algorithms to optimize network parameters
- Achieve recognition accuracy above 95%
- Measure and analyze execution times for various processing stages

## 🏗️ Project Structure

fingerprint-identification/
├── main.m # Main launcher script
├── src/ # Source code
│ ├── core/ # Core system functions
│ ├── image/ # Image processing and minutiae extraction
│ └── utils/ # Utility functions
├── data/ # Fingerprint database
└── output/ # Generated results and models

## 🚀 How to Run

1. Clone the repository
2. Open MATLAB
3. Navigate to the project directory
4. Run the `main.m` script

```matlab
% In MATLAB console
cd path/to/project
main
```

## 📊 Dataset

The project utilizes a database of 140 fingerprint images (5 fingers, 14 samples each for both PNG and TIFF formats), captured at 600 dpi resolution.

## 🧠 Implementation

The project implements two approaches for fingerprint recognition:

1. Pattern Recognition Network with hidden layers
2. Convolutional Neural Network (CNN)

In both cases, we use minutiae extraction as the primary feature extraction method.

## 📋 Requirements

- MATLAB R2021b or newer
- Image Processing Toolbox
- Deep Learning Toolbox
- Global Optimization Toolbox (for genetic algorithm)

## 🔍 Results

Detailed experiment results, including:

- Recognition accuracy for various network configurations
- Processing time comparison
- Charts and visualizations

will be provided after the completion of experiments.

## ✍️ Author

- PS
