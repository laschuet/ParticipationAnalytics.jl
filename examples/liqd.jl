using VisualParticipationAnalytics
using Clustering
using Distances
using NearestNeighbors
using PGFPlotsX
using Random
using SQLite
using Statistics
using Tables

Random.seed!(1)

empty!(PGFPlotsX.CUSTOM_PREAMBLE)
push!(PGFPlotsX.CUSTOM_PREAMBLE, raw"""
\usepgfplotslibrary{colorbrewer}
%\usepgfplotslibrary{colormap}
\usepackage{libertine}
\usepackage{unicode-math}
\setmathfont[Scale=MatchUppercase]{libertinusmath-regular.otf}
\pgfplotsset{
    colormap/Paired-12,
    cycle list/Paired-12,
    cycle multiindex* list={
        mark list*\nextlist
        Paired-12\nextlist
    }
}
""")

function main(dbpath, tablename)
    MEAN_EARTH_RADIUS = 6371
    earth_haversine = Haversine(MEAN_EARTH_RADIUS)

    # Load data
    db = SQLite.DB(dbpath)
    table = DBInterface.execute(db, """
        SELECT * FROM $tablename;
    """) |> Tables.columntable

    # Pre-process data
    # Text column title
    # Text column content

    # Cluster data
    longitude = table[Symbol("long")]
    latitude = table[Symbol("lat")]
    data = [longitude latitude]
    #display(data)

    # k-means
    k_range = 2:2
    distances = pairwise(earth_haversine, data')
    clusterings = []
    js = []
    silhouette_coefficients = []
    for k in k_range
        clustering = kmeans(data', k, distance=earth_haversine)
        push!(clusterings, clustering)

        push!(js, clustering.totalcost)

        mean_silhouette = mean(silhouettes(clustering, distances))
        push!(silhouette_coefficients, mean_silhouette)
    end

    # Evaluate k-means
    ## Assignment plots
    for k in k_range
        plt = @pgf Axis({
            xlabel = "longitude",
            ylabel = "latitude",
        }, PlotInc({
            scatter,
            "only marks",
            scatter_src = "explicit",
            mark_size = "1pt"
        }, Table({
            meta = "cluster"
        }, x = longitude, y = latitude, cluster = assignments(clusterings[k - 1]))))
        pgfsave("kmeans_assignments_k_" * (k < 10 ? "0$k" : "$k") * ".pdf", plt)
    end
    ## Elbow method
    plt = @pgf Axis({
        xlabel = raw"\(k\)",
        ylabel = raw"\(J\)",
    }, Plot({
        color = "blue",
        mark = "x",
    }, Coordinates(zip(k_range, js))))
    pgfsave("kmeans_elbow.pdf", plt)
    ## Silhouette coefficient
    plt = @pgf Axis({
        xlabel = raw"\(k\)",
        ylabel = "silhouette coefficient",
    }, Plot({
        color = "red",
        mark = "x",
    }, Coordinates(zip(k_range, silhouette_coefficients))))
    pgfsave("out/kmeans_silhouette.pdf", plt)

    # DBSCAN
    distances = pairwise(earth_haversine, data')
    display(distances)

    tree = BallTree(data', earth_haversine)
    k = 5
    _, knn_distances = knn(tree, data', k + 1, true)
    avg_knn_distances = mean.(knn_distances)
    sort!(avg_knn_distances)
    plt = @pgf Axis({
        xlabel = "instance",
        ylabel = "$k-nn distance",
    }, Plot({
        color = "green"
    }, Coordinates(zip(1:length(avg_knn_distances), avg_knn_distances))))
    pgfsave("dbscan_eps.pdf", plt)

    clusterings = []
    clustering = dbscan(distances, 0.7, k)
    push!(clusterings, clustering)

    # Evaluate DBSCAN
    ## Assignment plots
    plt = @pgf Axis({
        xlabel = "longitude",
        ylabel = "latitude",
    }, Plot({
        scatter,
        "only marks",
        scatter_src = "explicit",
        mark_size = "1pt"
    }, Table({
        meta = "cluster"
    }, x = longitude, y = latitude, cluster = assignments(clusterings[1]))))
    pgfsave("dbscan_assignments_min_eps_0.1_min_pts_3.pdf", plt)
    display(assignments(clusterings[1]))
end

main("~/datasets/participation/liqd_laermorte_melden.sqlite", "contribution")