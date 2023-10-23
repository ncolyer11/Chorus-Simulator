import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm

# Max runtime (chosen as ~95% of chorus are fully grown by then)
MAX_SIM_CYCLE_MINUTES = 30
# Cutting off 2 edges as they can only gen 1 flower really late
CHORUS_WIDTH = 9
CHORUS_HEIGHT = 22

names = ["Chorus Plant", "Chorus Flower"]
for name in names:
    max = 1
    if name == "Chorus Flower":
        max = 0.5
    excelFile = pd.ExcelFile(name + ' Heatmap.xlsx')

    data = excelFile.parse(MAX_SIM_CYCLE_MINUTES) # read from oldest sheet
    array_3d = data.values.reshape((CHORUS_WIDTH, CHORUS_WIDTH, CHORUS_HEIGHT))
    excelFile.close()

    # Create a meshgrid for the x, y, and z coordinates
    x, y, z = np.meshgrid(range(CHORUS_WIDTH), range(CHORUS_HEIGHT), range(CHORUS_WIDTH))
    x_flat = x.flatten()
    y_flat = y.flatten()
    z_flat = z.flatten()
    values = array_3d.flatten()

    # Set values to NaN so 0 cells aren't rendered
    values[values == 0] = np.nan

    # Initialise 3D scatter plot/heatmap
    fig = plt.figure(figsize=(25, 25))
    ax = fig.add_subplot(111, projection='3d')
    sc = ax.scatter(z_flat, x_flat, CHORUS_HEIGHT - y_flat, c=values, cmap="CMRmap_r", s=100, norm=LogNorm())
    cbar = fig.colorbar(sc, shrink=0.5)
    ax.set_title('3D {name} Heatmap')
    ax.set_xlabel('X-axis')
    ax.set_ylabel('Y-axis')
    ax.set_zlabel('Z-axis')

    # Open 3D interactive environment
    plt.show()
