import pandas as pd
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import numpy as np
from matplotlib.colors import LogNorm

name = "Chorus Plant"
max = 1
# name = "Chorus Flower"
if name == "Chorus Flower":
    max = 0.5

excelFile = pd.ExcelFile(name + ' Heatmap.xlsx')

# Read data from the current sheet
data = excelFile.parse(30)  # Assuming it's the first (and only) sheet
array_3d = data.values.reshape((11, 11, 22))
excelFile.close()

# Create a meshgrid for the x, y, and z coordinates
x, y, z = np.meshgrid(range(11), range(22), range(11))

# Flatten the coordinates and the values
x_flat = x.flatten()
y_flat = y.flatten()
z_flat = z.flatten()
values = array_3d.flatten()

# Set values to NaN where they are 0
values[values == 0] = np.nan

# Create a 3D scatter plot
fig = plt.figure(figsize=(10, 10))
ax = fig.add_subplot(111, projection='3d')

# Use Matplotlib's scatter function to plot the data
sc = ax.scatter(z_flat, x_flat, 22 - y_flat, c=values, cmap="nipy_spectral", s=100, norm=LogNorm())

# Create a colorbar to show the values
cbar = fig.colorbar(sc)

# Customize the plot as needed (title, labels, etc.)
ax.set_title('3D Heatmap')
ax.set_xlabel('X-axis')
ax.set_ylabel('Y-axis')
ax.set_zlabel('Z-axis')

# Show the plot
plt.show()
