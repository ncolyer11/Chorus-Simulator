import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

# Cutting off 2 edges as they can only gen 1 flower really late
CHORUS_RADII = 4
CHORUS_WIDTH = 9
CHORUS_HEIGHT = 22


names = ["Chorus Flower", "Chorus Plant"]
for name in names:
    alphaVal = 0
    if name == "Chorus Flower":
        alphaVal = 1
    excelFile = pd.ExcelFile(name + ' Heatmap.xlsx')

    # Print blank for the first, empty, sheet
    i = 0
    for sheetName in excelFile.sheet_names:
        if i == 0:
            blankData = pd.DataFrame(0.0, index=range(CHORUS_HEIGHT), columns=range(CHORUS_WIDTH ** 2))
            centreCoord = (CHORUS_WIDTH ** 2 - 1) / 2
            blankData[centreCoord][CHORUS_HEIGHT - 1] = 1 # set initial chorus flower
                # Initialize the first heatmap with blank data
            plt.figure(figsize=(25, 12))
            xLabels = [str(x) for x in np.tile(np.arange(-CHORUS_RADII, CHORUS_RADII + 1), CHORUS_WIDTH)]
            sns.heatmap(
                blankData,
                cmap="rocket_r",
                annot=False,
                cbar=True,
                square=True,
                xticklabels=xLabels,
                yticklabels=range(CHORUS_HEIGHT, -1, -1),
                cbar_kws={'shrink': 0.6},
                norm=LogNorm(vmin=1e-4, vmax=1),
                alpha=alphaVal
            )
            # Add lines to separate slices and labels for z-slices
            for i in range(1, CHORUS_WIDTH):
                plt.axvline(i * CHORUS_WIDTH, color='black', linewidth=1)
                zLabel = f"z = {i - (CHORUS_WIDTH + 1)}"
                plt.text(i * CHORUS_WIDTH - (CHORUS_RADII + 0.5), 26, zLabel, ha='center')

            plt.xlabel('x offset (repeats for 11 z-slices)')
            plt.ylabel('y layer')
            plt.title(f'{name}s at minute: 0')
            plt.savefig(f'media\\MatPlotHeatmaps\\{name} Heatmap at Minute 0.png', format='png', bbox_inches='tight')
            plt.close()
            i = 1
            continue

        # Determine the number of slices in the z-axis (should always be 9)
        data = excelFile.parse(sheetName)
        num_slices = data.shape[1] // CHORUS_WIDTH
        zSlices = []
        for zSlice in range(num_slices):
            # Extract the data for the current z-slice
            zSliceData = data.iloc[:, zSlice * CHORUS_WIDTH:(zSlice + 1) * CHORUS_WIDTH]
            zSlices.append(zSliceData)

        # Concatenate the z-slice data horizontally
        concatenatedData = pd.concat(zSlices, axis=1)

        # Initialise heatmap
        plt.figure(figsize=(25, 12))
        xLabels = [str(x) for x in np.tile(np.arange(-CHORUS_RADII, CHORUS_RADII + 1), CHORUS_WIDTH)]
        sns.heatmap(
            concatenatedData,
            cmap="rocket_r",
            annot=False,
            cbar=True,
            square=True,
            xticklabels=xLabels,
            yticklabels=range(CHORUS_HEIGHT, -1, -1),
            cbar_kws={'shrink': 0.6},
            norm=LogNorm(vmin=1e-4, vmax=1)
        )
        # Add lines to separate slices and labels for z-slices
        for i in range(1, CHORUS_WIDTH):
            plt.axvline(i * CHORUS_WIDTH, color='black', linewidth=1)
            zLabel = f"z = {i - (CHORUS_WIDTH + 1)}"
            plt.text(i * CHORUS_WIDTH - (CHORUS_RADII + 0.5), 26, zLabel, ha='center')
            
        plt.xlabel('x offset (repeats for 9 z-slices)')
        plt.ylabel('y layer')
        plt.title(f'{name}s at minute: {sheetName}')
        plt.savefig(f'media\\MatPlotHeatmaps\\{name} Heatmap at Minute {sheetName}.png', format='png', bbox_inches='tight')
        plt.close()
    excelFile.close()
