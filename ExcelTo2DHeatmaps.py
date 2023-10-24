import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

# Cutting off 2 edges as they can only gen 1 flower really late
CHORUS_RADII = 4
CHORUS_WIDTH = 9
CHORUS_HEIGHT = 23


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
            blankData[centreCoord][CHORUS_HEIGHT - 2] = 1 # set initial chorus flower
                # Initialize the first heatmap with blank data
            plt.figure(figsize=(26, 12))
            xLabels = [str(x) for x in np.tile(np.arange(-CHORUS_RADII, CHORUS_RADII + 1), CHORUS_WIDTH)]
            yTickLabels = [str(y - 1) for y in range(CHORUS_HEIGHT, 0, -1)]
            heatmap = sns.heatmap(
                blankData,
                cmap="rocket_r",
                annot=False,
                cbar=True,
                square=True,
                xticklabels=xLabels,
                yticklabels=yTickLabels,
                cbar_kws={'shrink': 0.6},
                norm=LogNorm(vmin=1e-7, vmax=1),
            )
            heatmap.get_children()[0].set_alpha(alphaVal)
            # Add lines to separate slices and labels for z-slices
            for i in range(1, CHORUS_WIDTH + 1):
                if i != CHORUS_WIDTH:
                    plt.axvline(i * CHORUS_WIDTH, color='black', linewidth=1)
                zLabel = f"Z = {i - (CHORUS_RADII + 1)}"
                plt.text(i * CHORUS_WIDTH - (CHORUS_RADII + 0.5), 26, zLabel, ha='center')

            plt.xlabel(f'X Offset')
            plt.ylabel('Y layer')
            plt.title(f'{name}s @ Minute: 0')
            plt.savefig(f'media\\MatPlotHeatmaps\\{name} Heatmap at Minute 0.png', format='png', bbox_inches='tight')
            plt.close()
            i = 1
            continue

        # Determine the number of slices in the z-axis (should always be 9)
        data = excelFile.parse(sheetName)
        numSlices = data.shape[1] // CHORUS_WIDTH
        zSlices = []
        for zSlice in range(numSlices):
            # Extract the data for the current z-slice
            zSliceData = data.iloc[:, zSlice * CHORUS_WIDTH:(zSlice + 1) * CHORUS_WIDTH]
            zSlices.append(zSliceData)

        # Concatenate the z-slice data horizontally
        concatenatedData = pd.concat(zSlices, axis=1)
        # Add blank row to push heatmap data down (thanks Seaborn <3)
        zeros_row = pd.DataFrame(0, columns=concatenatedData.columns, index=[0])
        concatenatedData = pd.concat([zeros_row, concatenatedData], axis=0)

        # Initialise heatmap
        plt.figure(figsize=(26, 12))
        xLabels = [str(x) for x in np.tile(np.arange(-CHORUS_RADII, CHORUS_RADII + 1), CHORUS_WIDTH)]
        yTickLabels = [str(y - 1) for y in range(CHORUS_HEIGHT, 0, -1)]
        sns.heatmap(
            concatenatedData,
            cmap="rocket_r",
            annot=False,
            cbar=True,
            square=True,
            xticklabels=xLabels,
            yticklabels=yTickLabels,
            cbar_kws={'shrink': 0.6},
            norm=LogNorm(vmin=1e-7, vmax=1)
        )
        # Add lines to separate slices and labels for z-slices
        for i in range(1, CHORUS_WIDTH + 1):
            if i != CHORUS_WIDTH:
                plt.axvline(i * CHORUS_WIDTH, color='black', linewidth=1)
            zLabel = f"Z = {i - (CHORUS_RADII + 1)}"
            plt.text(i * CHORUS_WIDTH - (CHORUS_RADII + 0.5), 26, zLabel, ha='center')
        plt.xlabel(f'X Offset')
        plt.ylabel('Y layer')
        plt.title(f'{name}s @ Minute: {sheetName}')
        plt.savefig(f'media\\MatPlotHeatmaps\\{name} Heatmap at Minute {sheetName}.png', format='png', bbox_inches='tight')
        plt.close()
    excelFile.close()
