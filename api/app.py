from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Dict, Any
import joblib
import json
import numpy as np
import os
from pathlib import Path
import asyncio
from concurrent.futures import ThreadPoolExecutor
from prometheus_fastapi_instrumentator import Instrumentator

# Initialize FastAPI app
app = FastAPI(
    title="Salesforce ML Test Prediction API",
    description="API with toy model for Salesforce ML Test",
    version="1.0.0"
)

# Global variables to store loaded model components
model = None
scaler = None
metadata = None

# Thread pool for CPU-intensive tasks
executor = ThreadPoolExecutor(max_workers=4)

# Initialize Prometheus metrics
instrumentator = Instrumentator()
instrumentator.instrument(app).expose(app)

# Pydantic model for input validation
class PredictionInput(BaseModel):
    """Input model for prediction endpoint"""
    feat1: float = Field(..., description="Feature 1 value")
    feat2: float = Field(..., description="Feature 2 value")
    feat3: float = Field(..., description="Feature 3 value")
    feat4: float = Field(..., description="Feature 4 value")
    feat5: float = Field(..., description="Feature 5 value")
    feat6: float = Field(..., description="Feature 6 value")
    feat7: float = Field(..., description="Feature 7 value")
    feat8: float = Field(..., description="Feature 8 value")
    feat9: float = Field(..., description="Feature 9 value")
    feat10: float = Field(..., description="Feature 10 value")
    feat11: float = Field(..., description="Feature 11 value")
    feat12: float = Field(..., description="Feature 12 value")
    feat13: float = Field(..., description="Feature 13 value")
    feat14: float = Field(..., description="Feature 14 value")
    feat15: float = Field(..., description="Feature 15 value")
    feat16: float = Field(..., description="Feature 16 value")
    feat17: float = Field(..., description="Feature 17 value")
    feat18: float = Field(..., description="Feature 18 value")
    feat19: float = Field(..., description="Feature 19 value")
    feat20: float = Field(..., description="Feature 20 value")
    feat21: float = Field(..., description="Feature 21 value")
    feat22: float = Field(..., description="Feature 22 value")
    feat23: float = Field(..., description="Feature 23 value")
    feat24: float = Field(..., description="Feature 24 value")
    feat25: float = Field(..., description="Feature 25 value")
    feat26: float = Field(..., description="Feature 26 value")
    feat27: float = Field(..., description="Feature 27 value")
    feat28: float = Field(..., description="Feature 28 value")
    feat29: float = Field(..., description="Feature 29 value")
    feat30: float = Field(..., description="Feature 30 value")
    feat31: float = Field(..., description="Feature 31 value")
    feat32: float = Field(..., description="Feature 32 value")
    feat33: float = Field(..., description="Feature 33 value")
    feat34: float = Field(..., description="Feature 34 value")
    feat35: float = Field(..., description="Feature 35 value")
    feat36: float = Field(..., description="Feature 36 value")

    class Config:
        json_schema_extra = {
            "example": {
                "feat1": 55.0,
                "feat2": 2.0,
                "feat3": 6750.0,
                "feat4": 33.0,
                "feat5": 32.0,
                "feat6": 22.0,
                "feat7": 2.0,
                "feat8": 0.0,
                "feat9": 14.0,
                "feat10": 66.0,
                "feat11": 0.0,
                "feat12": 0.0,
                "feat13": 0.0,
                "feat14": 0.0,
                "feat15": 0.0,
                "feat16": 0.0,
                "feat17": 0.0,
                "feat18": 0.0,
                "feat19": 0.0,
                "feat20": 0.0,
                "feat21": 0.0,
                "feat22": 0.0,
                "feat23": 0.0,
                "feat24": 0.0,
                "feat25": 0.0,
                "feat26": 0.0,
                "feat27": 0.0,
                "feat28": 1.0,
                "feat29": 0.0,
                "feat30": 0.0,
                "feat31": 1.0,
                "feat32": 0.0,
                "feat33": 0.0,
                "feat34": 1.0,
                "feat35": 0.0,
                "feat36": 0.0
            }
        }

# Pydantic model for output response
class PredictionOutput(BaseModel):
    """Output model for prediction endpoint"""
    predicted_class: int = Field(..., description="Predicted performance class (1-5)")
    prediction_probabilities: Dict[str, float] = Field(..., description="Probability for each class")
    confidence: float = Field(..., description="Confidence score (highest probability)")
    
    class Config:
        json_schema_extra = {
            "example": {
                "predicted_class": 3,
                "prediction_probabilities": {
                    "1": 0.1,
                    "2": 0.2,
                    "3": 0.5,
                    "4": 0.15,
                    "5": 0.05
                },
                "confidence": 0.5
            }
        }

def load_model_components():
    """Load the trained model, scaler, and metadata"""
    global model, scaler, metadata
    
    try:
        # Get the directory where this script is located
        current_dir = Path(__file__).parent
        model_dir = current_dir / "model"
        
        model_path = model_dir / "xgboost_model.pkl"
        scaler_path = model_dir / "scaler.pkl"
        metadata_path = model_dir / "model_metadata.json"
        
        # Load model components
        model = joblib.load(model_path)
        scaler = joblib.load(scaler_path)
        
        with open(metadata_path, 'r') as f:
            metadata = json.load(f)
            
        print("Model components loaded successfully!")
        return True
        
    except Exception as e:
        print(f"Error loading model components: {str(e)}")
        return False

def evaluate_model(input_data: PredictionInput) -> Dict[str, Any]:
    """
    Evaluate model on input data
    
    Args:
        input_data: Pydantic model with feature values
    
    Returns:
        Dictionary with prediction results
    """
    try:
        # Convert input to dictionary
        data = input_data.dict()
        
        # Extract features in the correct order
        feature_names = metadata['feature_names']
        X_sample = np.array([data[feat] for feat in feature_names]).reshape(1, -1)
        
        # Scale the features
        X_sample_scaled = scaler.transform(X_sample)
        
        # Make prediction
        prediction = model.predict(X_sample_scaled)[0]
        prediction_proba = model.predict_proba(X_sample_scaled)[0]
        
        # Convert prediction back to original class labels
        class_mapping = json.loads(metadata['class_mapping'])
        reverse_mapping = {v: k for k, v in class_mapping.items()}
        original_prediction = reverse_mapping[prediction]
        
        # Get class probabilities for original classes
        class_labels = sorted(class_mapping.keys())
        proba_dict = {str(class_labels[i]): float(prediction_proba[i]) for i in range(len(class_labels))}
        
        return {
            'predicted_class': int(original_prediction),
            'prediction_probabilities': proba_dict,
            'confidence': float(max(prediction_proba))
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error during prediction: {str(e)}")

@app.on_event("startup")
async def startup_event():
    """Load model components on startup"""
    print("Starting up XGBoost Prediction API...")
    success = load_model_components()
    if not success:
        print("Failed to load model components. API may not work correctly.")
    else:
        print("API ready for predictions!")

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "XGBoost Prediction API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "predict": "/predict",
            "health": "/health",
            "docs": "/docs"
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    if model is None or scaler is None or metadata is None:
        return {
            "status": "unhealthy",
            "message": "Model components not loaded"
        }
    return {
        "status": "healthy",
        "message": "All components loaded successfully"
    }

@app.post("/predict", response_model=PredictionOutput)
async def predict(input_data: PredictionInput):
    """
    Predict using xgboost toy model
    
    Args:
        input_data: Input features for prediction
        
    Returns:
        Prediction results with class and probabilities
    """
    if model is None or scaler is None or metadata is None:
        raise HTTPException(
            status_code=503, 
            detail="Model components not loaded. Please check server logs."
        )
    
    try:
        # Run CPU-intensive operations in thread pool
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(executor, evaluate_model, input_data)
        return PredictionOutput(**result)
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
