from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import JSONResponse
import pandas as pd
import io
from hrv_analysis import analyze_hrv

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "HRV API is running"}

@app.post("/analyze")
async def analyze(file: UploadFile = File(...), start_index: int = Form(0)):
    try:
        contents = await file.read()
        df = pd.read_csv(io.StringIO(contents.decode("utf-8")), sep=";")
        hrv_metrics, rr_table = analyze_hrv(df, start_index)

        return {
            "hrvMetrics": hrv_metrics,
            "rrTable": rr_table
        }

    except Exception as e:
        return JSONResponse(status_code=500, content={"error": str(e)})
