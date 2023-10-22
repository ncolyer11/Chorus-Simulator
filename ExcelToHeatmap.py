import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

name = "Chorus Plant"
max = 1
# name = "Chorus Flower"
if name == "Chorus Flower":
    max = 0.5
excel_file = pd.ExcelFile(name + ' Heatmap.xlsx')

# Skip first, empty, sheet
i = 0
for sheet_name in excel_file.sheet_names:
    if i == 0:
        i += 1
        continue
    data = excel_file.parse(sheet_name)
    for row

    # Determine the number of slices in the Z-axis
    num_slices = data.shape[1] // 11

    z_slices = []
    for z_slice in range(num_slices):
        # Extract the data for the current Z-slice
        z_slice_data = data.iloc[:, z_slice * 11:(z_slice + 1) * 11]
        z_slices.append(z_slice_data)

    # Concatenate the Z-slice data horizontally
    concatenated_data = pd.concat(z_slices, axis=1)

    plt.figure(figsize=(25, 7))  # Adjust the figure size as needed

    # Customize axis labels
    sns.heatmap(concatenated_data, cmap="rocket_r", annot=False, cbar=True, vmin=0, vmax=max, square=True, xticklabels=range(0, 121, 11), yticklabels=range(0, 22, 1), cbar_kws={'shrink': 0.6}, norm=LogNorm())

    # Add labels and title if necessary
    plt.xlabel('z slices (11 x wide)')
    plt.ylabel('ylabel = "y layer"')
    plt.title(f'{name}s at minute: {sheet_name}')

    # Save the heatmap as a .png image
    plt.savefig(f'MatPlotHeatmaps\\heatmap_{name + sheet_name}.png', format='png', bbox_inches='tight')
    plt.close()

# Close the Excel file
excel_file.close()
