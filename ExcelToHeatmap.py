import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm


names = ["Chorus Plant", "Chorus Flower"]
for name in names:
    max = 1
    if name == "Chorus Flower":
        max = 0.45
    excel_file = pd.ExcelFile(name + ' Heatmap.xlsx')

    # Print blank for the first, empty, sheet
    i = 0
    for sheet_name in excel_file.sheet_names:
        if i == 0:
            blankData = pd.DataFrame(0.0, index=range(23), columns=range(121))
            blankData[60][21] = 1 # set initial chorus flower
            alphaVal = (-20 / 11) * (max - 1) # 1 if chorus flowers, 0 if chorus plant
                # Initialize the first heatmap with blank data
            plt.figure(figsize=(25, 7))
            sns.heatmap(
                blankData,
                cmap="rocket_r",
                annot=False,
                cbar=True,
                square=True,
                xticklabels=range(0, 121, 1),
                yticklabels=range(22, -1, -1),
                cbar_kws={'shrink': 0.6},
                norm=LogNorm(vmin=1e-4, vmax=max),
                alpha=alphaVal
            )
            plt.xlabel('z slices (11 x wide)')
            plt.ylabel('y layer')
            plt.title(f'{name}s at minute: 0')
            plt.savefig(f'media\\MatPlotHeatmaps\\heatmap_{name}0.png', format='png', bbox_inches='tight')
            plt.close()
            i = 1
            continue
        data = excel_file.parse(sheet_name)

        # Determine the number of slices in the z-axis (should always be 11)
        num_slices = data.shape[1] // 11

        z_slices = []
        for z_slice in range(num_slices):
            # Extract the data for the current z-slice
            z_slice_data = data.iloc[:, z_slice * 11:(z_slice + 1) * 11]
            z_slices.append(z_slice_data)

        # Concatenate the z-slice data horizontally
        concatenated_data = pd.concat(z_slices, axis=1)

        # Initialise heatmap
        plt.figure(figsize=(25, 7))
        sns.heatmap(
            concatenated_data,
            cmap="rocket_r",
            annot=False,
            cbar=True,
            square=True,
            xticklabels=range(0, 121, 1),
            yticklabels=range(22, -1, -1),
            cbar_kws={'shrink': 0.6},
            norm=LogNorm(vmin=1e-4, vmax=max)
        )
        plt.xlabel('z slices (11 x wide)')
        plt.ylabel('y layer')
        plt.title(f'{name}s at minute: {sheet_name}')
        plt.savefig(f'media\\MatPlotHeatmaps\\heatmap_{name + sheet_name}.png', format='png', bbox_inches='tight')
        plt.close()
    excel_file.close()
