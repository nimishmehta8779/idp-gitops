"""
${{ values.serviceName }} - FastAPI Service
"""
import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(
    title="${{ values.serviceName }}",
    description="${{ values.description }}",
    version="0.1.0",
)

# Environment variables
LOG_LEVEL = os.getenv("LOG_LEVEL", "info")
SERVICE_NAME = os.getenv("SERVICE_NAME", "${{ values.serviceName }}")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return JSONResponse({"status": "healthy"})


@app.get("/ready")
async def readiness_check():
    """Readiness check endpoint"""
    return JSONResponse({"status": "ready"})


@app.get("/")
async def root():
    """Welcome endpoint"""
    return {
        "message": f"Welcome to {SERVICE_NAME}",
        "version": "0.1.0",
    }


@app.get("/api/info")
async def info():
    """Service information"""
    return {
        "name": SERVICE_NAME,
        "log_level": LOG_LEVEL,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8080)),
    )
