import numpy as np
import pandas as pd

def detect_peaks(voltage_data):
    # Simple peak detection: Replace with your algorithm later
    return [i for i in range(1, len(voltage_data) - 1) if voltage_data[i - 1] < voltage_data[i] > voltage_data[i + 1]]

def analyze_hrv(df: pd.DataFrame, start_index: int = 0):
    times = df["Time (s)"].values[start_index:]
    voltages = df["Voltage (mV)"].values[start_index:]

    peak_indices = detect_peaks(voltages)
    r_peaks_time = [times[i] for i in peak_indices]

    if len(r_peaks_time) < 2:
        raise ValueError("Not enough R-peaks to compute HRV.")

    rr_intervals = np.diff(r_peaks_time)
    rr_table = [
        {"timestamp": float(r_peaks_time[i]), "rr": float(rr_intervals[i])}
        for i in range(len(rr_intervals))
    ]

    hrv_metrics = {
        "MeanRR": float(np.mean(rr_intervals)),
        "SDNN": float(np.std(rr_intervals, ddof=1)),
        "RMSSD": float(np.sqrt(np.mean(np.square(np.diff(rr_intervals)))))
    }

    return hrv_metrics, rr_table
