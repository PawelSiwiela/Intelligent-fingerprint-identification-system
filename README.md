# Inteligent Fingerprint Identification System

Advanced biometric identification system utilizing state-of-the-art image processing and machine learning techniques for fingerprint classification.

## 🎯 Project Overview

Comprehensive biometric system implementing complete fingerprint identification pipeline:

- **Preprocessing** - Advanced image processing with Gabor filtering
- **Feature Extraction** - Minutiae detection and numerical feature vector generation
- **Machine Learning** - PatternNet and CNN model training with hyperparameter optimization
- **Visualizations** - Detailed result analysis and process visualization

## 🚀 Key Features

### Core Functionality

- ✅ **6-stage preprocessing pipeline** (orientation → frequency → Gabor → segmentation → binarization → skeletonization)
- ✅ **Minutiae detection and filtering** (endpoints, bifurcations) with quality analysis
- ✅ **40+ numerical feature extraction** (geometric, topological, statistical)
- ✅ **Automated machine learning** (PatternNet + CNN) with cross-validation
- ✅ **Hyperparameter optimization** with Random Search and early stopping
- ✅ **Professional visualizations** (confusion matrices, learning curves, feature analysis)

### Data Security

- 🔒 **Data anonymization** - export only skeletons and numerical features
- 🔒 **No original fingerprint storage** - only processed data
- 🔒 **Secure sharing** - complete .mat datasets without biometric data

### Interface & Usability

- 🖥️ **Interactive CLI** with intelligent data source selection
- 📊 **Comprehensive visualizations** of pipeline and ML results
- 📝 **Detailed logging** with timestamps and severity levels
- ⚡ **Fast paths** - direct loading of preprocessed data

## 📁 Project Structure

```
Intelligent-fingerprint-identification-system/
├── main.m                      # Entry point - run this file
├── src/                        # Source code
│   ├── App.m                   # Main application with CLI interface
│   ├── loadConfig.m            # Global system configuration
│   ├── core/                   # Main processing pipelines
│   │   ├── PreprocessingPipeline.m    # Image preprocessing pipeline
│   │   ├── MLPipeline.m               # Machine learning pipeline
│   │   ├── data/                      # Data loading and validation
│   │   ├── dimensionality/            # Dimensionality reduction (PCA, MDA)
│   │   └── network/                   # ML models and evaluation
│   ├── image/                  # Image processing
│   │   ├── preprocessing/             # Preprocessing (Gabor, binarization)
│   │   ├── minutiae/                  # Minutiae detection and filtering
│   │   └── visualizations/            # Process and feature visualizations
│   └── utils/                  # Utility tools
│       ├── measureIdentificationSpeed.m # Benchmarking model performance
│       ├── normalizeFeatures.m          # ML feature normalization
│       ├── data/                        # Data handling utilities
│       │   ├── saveProcessedData.m      # Anonymous data export
│       │   └── loadProcessedData.m      # Preprocessed data import
│       └── logging/                     # Logging system
├── data/                       # Input data directory (ignored)
│   ├── thumb/                  # Thumb images
│   ├── index/                  # Index finger images
│   ├── middle/                 # Middle finger images
│   ├── ring/                   # Ring finger images
│   └── little/                 # Little finger images
└── output/                     # Results directory (ignored)
    ├── logs/                   # Log files with timestamps
    ├── figures/                # Visualizations and plots
    ├── models/                 # Saved ML models
    └── anonymized_data/        # Secure data for sharing
```

## 🛠️ Installation and Setup

### Requirements

- MATLAB R2018b or newer
- Toolboxes: Image Processing, Deep Learning (optional), Statistics and Machine Learning

### Quick Start

1. **Clone repository:**

```bash
git clone <https://github.com/PawelSiwiela/Intelligent-fingerprint-identification-system>
cd Intelligent-fingerprint-identification-system
```

2. **Run in MATLAB:**

```matlab
main.m  % Launches main application
```

3. **Choose data source:**
   - **Option A** (recommended): Use preprocessed .mat files (fast)
   - **Option B**: Process original PNG/TIFF images (full pipeline)

### Data Preparation

**Directory structure for original images:**

```
data/
├── thumb/
│   ├── PNG/              # or TIFF/
│   │   ├── Sample 1.png
│   │   └── Sample 2.png
├── index/
│   └── PNG/
└── ...
```

**Supported formats:**

- PNG (recommended for quality)
- TIFF (for high-resolution data)

## 🧠 Processing Pipeline

### 1. Preprocessing (6 stages)

```
Image → Orientation → Frequency → Gabor → Segmentation → Binarization → Skeleton
```

### 2. Feature Extraction (40+ features)

- **Minutiae features**: count, types (endpoints/bifurcations), quality
- **Geometric features**: centroids, spatial spread
- **Topological features**: density, orientations, local correlations
- **Statistical features**: moments, distributions, asymmetries

### 3. Machine Learning

- **Models**: PatternNet (MLP) + CNN
- **Optimization**: Random Search hyperparameters (20-50 trials)
- **Validation**: Stratified k-fold cross-validation
- **Data split**: Train(60%) / Validation(20%) / Test(20%)

### 4. Evaluation and Visualization

- Confusion matrices with true finger names
- Learning curves (accuracy/loss vs epoch)
- Feature analysis (correlations, PCA, MDA)
- F1-score per class and macro metrics

## 📊 Results and Visualizations

System automatically generates:

### Preprocessing Analysis

- `preprocessing_pipeline.png` - 6-stage pipeline visualization
- `preprocessing_pipeline_sample_XXX.png` - Detailed per-image steps

### Minutiae Feature Analysis

- `minutiae_advanced_analysis.png` - Endpoints/bifurcations statistics
- `minutiae_finger_profiles.png` - Finger profiles (radar charts)
- `minutiae_distribution_analysis.png` - Feature distributions and correlations

### Machine Learning Results

- `model_comparison_TIMESTAMP.png` - All models comparison
- `model_visualization_MODELTYPE_TIMESTAMP.png` - Detailed model analysis
- `dimensionality_reduction_analysis.png` - PCA/MDA analysis

### Models and Data

- `output/models/` - Saved .mat models with hyperparameters
- `output/anonymized_data/` - Secure data for sharing

## 🔒 Security and Anonymization

### Anonymous Data

System automatically creates secure data versions:

- **Binary skeletons** instead of original fingerprints
- **Numerical feature vectors** without reconstruction possibility
- **Minutiae points** as mathematical coordinates
- **README with security documentation**

### Exported Files

```
output/anonymized_data/
├── complete_anonymized_dataset_TIMESTAMP.mat    # Complete dataset
├── preprocessed_images_TIMESTAMP.mat           # Skeletons only
├── features_data_TIMESTAMP.mat                 # Features only
├── minutiae_data_TIMESTAMP.mat                 # Minutiae only
└── README_ANONYMIZED_DATA.txt                  # Documentation
```

## ⚙️ Configuration

File [`src/loadConfig.m`](src/loadConfig.m) contains all parameters:

### Preprocessing

```matlab
config.preprocessing.gaborSigma = 3;           % Gabor filter
config.preprocessing.orientationBlockSize = 16; % Orientation analysis
config.preprocessing.frequencyBlockSize = 32;   % Frequency analysis
```

### Machine Learning

```matlab
config.ml.trainRatio = 0.6;     % 60% training data
config.ml.valRatio = 0.2;       % 20% validation
config.ml.testRatio = 0.2;      % 20% testing
config.ml.optimizeHyperparams = true;  # Hyperparameter optimization
```

### Visualizations

```matlab
config.visualization.enabled = true;
config.visualization.saveFormat = 'png';
config.visualization.outputDir = 'output/figures';
```

## 📈 Example Results

### Model Performance

- **PatternNet**: 85-95% accuracy (typically ~90%)
- **CNN**: 90-98% accuracy (typically ~94%)
- **Training time**: 30-180 seconds per model
- **Optimization**: Early stopping at 90%+ accuracy

### Feature Statistics

- **Dimensionality**: 40+ features per sample
- **Normalization**: Min-Max [0,1] for ML stability
- **Dimensionality reduction**: PCA preserves 95%+ variance

## 🐛 Debugging

### Common Issues

**No data found:**

```
❌ Error: No data found
✅ Solution: Check data/ directory structure
```

**Preprocessing errors:**

```
⚠️  Warning: Low success rate
✅ Solution: Check image quality, reduce resolution
```

**Memory issues:**

```
❌ Error: Out of memory
✅ Solution: Reduce CNN batch size in configuration
```

### Logging System

All operations logged to:

```
output/logs/fingerprint_processing_YYYY-MM-DD_HH-MM-SS.log
```

Log levels:

- `[INFO]` - General information
- `[WARNING]` - Warnings (don't stop process)
- `[ERROR]` - Critical errors
- `[SUCCESS]` - Successful operation confirmations

## 🤝 Contributing

### Adding New Features

1. **New features**: Add to [`extractMinutiaeFeatures.m`](src/image/minutiae/extractMinutiaeFeatures.m)
2. **New models**: Extend [`MLPipeline.m`](src/core/MLPipeline.m)
3. **New visualizations**: Add to [`src/image/visualizations/`](src/image/visualizations/)

### Testing

```matlab
% Run with test data
App();  % Choose option 1 (preprocessed data)
```

## 📄 License

Educational project - Intelligent Systems, Master's Studies  
[University Name] - Semester I

## 📞 Contact

In case of issues:

1. Check [Debugging](#-debugging) section
2. Analyze log files in `output/logs/`
3. Ensure all toolboxes are installed

---

**🔥 Quick Start**: Run `main.m` → Choose data source → System automatically executes complete ML pipeline! 🚀
