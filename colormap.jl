import Bonito.TailwindDashboard as D
using WGLMakie, DataFrames, CSV, ColorSchemes, Images, FileIO, Makie

# India's geographic bounds
const INDIA_MIN_LON = 68.0
const INDIA_MAX_LON = 97.0
const INDIA_MIN_LAT = 8.0
const INDIA_MAX_LAT = 37.0

# Load and prepare city data
cities_locations = CSV.read("cities.csv", DataFrame) |>
    df -> select(df, [:city_names, :lat, :lng]) |>
    df -> rename(df, Dict(:city_names => :city_names, :lat => :y, :lng => :x))

# Convert coordinates to pixel space
cities_locations.x_px = 800 .* (cities_locations.x .- INDIA_MIN_LON) ./ (INDIA_MAX_LON - INDIA_MIN_LON)
cities_locations.y_px = 800 .* ((cities_locations.y .- INDIA_MIN_LAT) ./ (INDIA_MAX_LAT - INDIA_MIN_LAT))

# Load mask
mask_img = load("output.jpg")
mask = Float32.(Gray.(mask_img) .< 0.5)

grid_size = 800
x_grid = range(0, 800, length=grid_size)
y_grid = range(0, 800, length=grid_size)
temp_cmap = cgrad([:blue, :lightblue, :green, :yellow, :orange, :red], 
                 [0.0, 0.2, 0.4, 0.6, 0.8, 1.0])

function find_nearest_temp(x, y, points, temps)
    min_dist = Inf
    nearest_temp = missing
    for i in 1:size(points, 2)
        dist = sqrt((x - points[1,i])^2 + (y - points[2,i])^2)
        if dist < min_dist
            min_dist = dist
            nearest_temp = temps[i]
        end
    end
    return nearest_temp
end

function generate_colormapped_figure(day)
    try
        day_data = CSV.read("NewDataset/Day$day.csv", DataFrame)
        cities_data = innerjoin(day_data, cities_locations, on=:city_names)
        points = hcat(cities_data.x_px, cities_data.y_px)'
        temps = cities_data.temp
        grid_values = [find_nearest_temp(x, y, points, temps) for x in x_grid, y in y_grid]
        grid_values = Float32.(grid_values)
        masked_values = grid_values .* mask
        masked_values[masked_values .== 0] .= NaN 
        
        fig = Figure(size=(800, 800))
        ax = WGLMakie.Axis(fig[1, 1], title="Day $day Temperature (Nearest Neighbor)")
        heatmap!(ax, x_grid, y_grid, masked_values, colormap=temp_cmap, nan_color=:white)
        return fig
    catch e
        @warn "Error generating plot for day $day: $e"
        return nothing
    end
end

bapp = App() do session
    sl_day = D.Slider("Day", 1:730, value=1)
    img_display = map(generate_colormapped_figure, sl_day.value)
    return DOM.div(
        D.FlexCol(sl_day, img_display, 
            style="align-items: center; justify-content: center; padding: 20px; gap: 20px;")
    )
end