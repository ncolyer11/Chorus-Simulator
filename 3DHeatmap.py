import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

# Max runtime (chosen as ~95% of chorus are fully grown by then)
MAX_SIM_CYCLE_MINUTES = 30


names = ["Chorus Plant", "Chorus Flower"]
for name in names:
    max = 1
    # name = "Chorus Flower" # uncomment this to switch between plants and flowers
    if name == "Chorus Flower":
        max = 0.5

    excelFile = pd.ExcelFile(name + ' Heatmap.xlsx')

    data = excelFile.parse(MAX_SIM_CYCLE_MINUTES) # read from oldest sheet
    array_3d = data.values.reshape((11, 11, 22))
    excelFile.close()

    # Create a meshgrid for the x, y, and z coordinates
    x, y, z = np.meshgrid(range(11), range(22), range(11))
    x_flat = x.flatten()
    y_flat = y.flatten()
    z_flat = z.flatten()
    values = array_3d.flatten()

    # Set values to NaN so 0 cells aren't rendered
    values[values == 0] = np.nan

    # Initialise 3D scatter plot/heatmap
    fig = plt.figure(figsize=(20, 20))
    ax = fig.add_subplot(111, projection='3d')
    sc = ax.scatter(z_flat, x_flat, 22 - y_flat, c=values, cmap="CMRmap_r", s=100, norm=LogNorm())
    cbar = fig.colorbar(sc, shrink=0.5)
    ax.set_title('3D Heatmap')
    ax.set_xlabel('X-axis')
    ax.set_ylabel('Y-axis')
    ax.set_zlabel('Z-axis')

    # Open 3D interactive environment
    plt.show()
