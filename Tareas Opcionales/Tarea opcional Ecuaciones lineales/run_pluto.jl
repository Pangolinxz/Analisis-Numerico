import Pluto

notebook = joinpath(@__DIR__, "shamanskii_ecuacion_no_lineal.jl")
Pluto.run(
    notebook=notebook,
    host="127.0.0.1",
    launch_browser=true,
    require_secret_for_access=false,
    require_secret_for_open_links=false,
)
