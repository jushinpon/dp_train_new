import os
import matplotlib.pyplot as plt
import numpy as np
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

# Define output folder
output_folder = "../matplot4compress/postprocessed"

# Remove old folder and create a new one
if os.path.exists(output_folder):
    os.system(f"rm -rf {output_folder}")
os.makedirs(output_folder)

def plot_accuracy_density(dft, dlp, data_type, dataset, size=30, xlabel='DFT', ylabel='DLP'):
    """Plot DFT vs DLP scatter with regression and metrics."""
    # Map to full names for SCI paper formatting
    data_type_full = {"e": "Energy", "f": "Force", "v": "Virial"}[data_type]

    fig, ax = plt.subplots(figsize=(8, 8), dpi=300)

    # Determine min/max for axis limits
    min_val, max_val = min(np.min(dft), np.min(dlp)), max(np.max(dft), np.max(dlp)) * 1.1

    # Regression line
    x_vals = np.linspace(min_val, max_val, 100)
    slope, intercept = np.polyfit(dft, dlp, 1)
    dlp_fit = slope * x_vals + intercept

    # Scatter plot
    ax.scatter(dft, dlp, marker='.', s=size, alpha=0.5, edgecolors='black')

    # Plot regression line
    ax.plot(x_vals, dlp_fit, 'r-', linewidth=2, label=f'y = {slope:.2f}x + {intercept:.2f}')
    
    # One-to-one line
    ax.plot([min_val, max_val], [min_val, max_val], '--', color='black')

    # Labels and title
    ax.set_title(f"{data_type_full} ({dataset.capitalize()})", fontsize=16, fontweight='bold')
    ax.set_xlabel(xlabel, fontsize=14)
    ax.set_ylabel(ylabel, fontsize=14)

    # Set equal axis limits
    ax.set_xlim(min_val, max_val)
    ax.set_ylim(min_val, max_val)

    # Compute error metrics (scaled by 1000)
    rmse = np.sqrt(mean_squared_error(dft, dlp))
    mae = mean_absolute_error(dft, dlp)
    r2 = r2_score(dft, dlp)

    # Display metrics
    metrics_text = f"RMSE = {rmse:.3f}\nR² = {r2:.3f}\nMAE = {mae:.3f}"
    ax.text(0.05, 0.95, metrics_text, transform=ax.transAxes, fontsize=12,
            verticalalignment='top', bbox=dict(facecolor='white', alpha=0.8, edgecolor='black'))

    # Improve appearance
    ax.tick_params(axis="both", which="major", labelsize=12)
    ax.grid(True, linestyle="--", linewidth=0.5)
    ax.legend(fontsize=12)

    # Save figure
    fig.tight_layout()
    plt.savefig(f"{output_folder}/{dataset}_{data_type_full}.png")
    plt.close()

# Plot learning curve
data = np.genfromtxt("../dp_train/graph01/lcurve.out", names=True)
plt.figure(figsize=(8, 6), dpi=300)
for name in data.dtype.names[1:]:  # Skip 'step'
    plt.plot(data['step'], data[name], label=name, linewidth=1.5)
plt.legend(fontsize=12)
plt.xlabel('Steps', fontsize=14)
plt.ylabel('Loss', fontsize=14)
plt.title('Learning Curve', fontsize=16, fontweight='bold')
plt.grid(True, linestyle="--", linewidth=0.5)
plt.tight_layout()
plt.savefig(f"{output_folder}/learning_curve.png")
plt.close()

# Load and plot validation & training data
datasets = ['train', 'validation']
data_types = {'temp.e': 'e', 'temp.f': 'f', 'temp.v': 'v'}

for dataset in datasets:
    for short_name, full_name in data_types.items():
        file_path = f"../matplot_data4compress/{dataset}-{short_name}-graph01.out"
        if os.path.exists(file_path):
            data = np.loadtxt(file_path, comments='#')
            dft_values = data[:, :data.shape[1]//2].ravel()
            dlp_values = data[:, data.shape[1]//2:].ravel()
            plot_accuracy_density(dft_values, dlp_values, full_name, dataset)
