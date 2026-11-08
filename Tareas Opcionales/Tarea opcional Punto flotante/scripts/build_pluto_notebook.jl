using JSON
using UUIDs

const ROOT = normpath(joinpath(@__DIR__, ".."))
const INPUT = joinpath(ROOT, "PuntoFlotante_Julia_final.ipynb")
const OUTPUT = joinpath(ROOT, "PuntoFlotante_Julia_final.jl")

nb = JSON.parsefile(INPUT)

function markdown_expression(source::AbstractString)
    occursin("\"\"\"", source) && error("Una celda Markdown contiene comillas triples")
    # El literal raw conserva los signos $ y las barras de LaTeX. Así,
    # Markdown.parse los clasifica como fórmulas en lugar de texto común.
    "Markdown.parse(raw\"\"\"\n$(source)\n\"\"\")"
end

cell_blocks = String[]
cell_order = String[]

function add_cell!(source::AbstractString; markdown::Bool=false, id=string(uuid4()))
    expression = markdown ? markdown_expression(source) : String(source)
    push!(cell_blocks, "# ╔═╡ $(id)\n$(expression)\n")
    push!(cell_order, (markdown ? "# ╟─" : "# ╠═") * id)
end

for (index, cell) in enumerate(nb["cells"])
    raw_source = cell["source"]
    source = raw_source isa AbstractVector ? join(string.(raw_source)) : String(raw_source)
    if cell["cell_type"] == "markdown"
        add_cell!(source; markdown=true)
    else
        if index == 3
            # Pluto utilizará el entorno embebido; no se debe activar otro proyecto desde una celda.
            source = replace(source, "Pkg.activate(pwd())\n" => "")
            source = replace(source, "using Plots\n" => "using Plots\nusing PlutoUI\n")
        end
        add_cell!("begin\n$(source)\nend")
        if index == 3
            add_cell!("TableOfContents(title=\"Contenido\", indent=true, depth=3, aside=true)")
        end
    end
end

project = read(joinpath(ROOT, "Project.toml"), String)
manifest = read(joinpath(ROOT, "Manifest.toml"), String)

project_id = "00000000-0000-0000-0000-000000000001"
manifest_id = "00000000-0000-0000-0000-000000000002"
push!(cell_blocks, "# ╔═╡ $(project_id)\nPLUTO_PROJECT_TOML_CONTENTS = \"\"\"\n$(project)\n\"\"\"\n")
push!(cell_blocks, "# ╔═╡ $(manifest_id)\nPLUTO_MANIFEST_TOML_CONTENTS = \"\"\"\n$(manifest)\n\"\"\"\n")
push!(cell_order, "# ╟─" * project_id)
push!(cell_order, "# ╟─" * manifest_id)

frontmatter = """### A Pluto.jl notebook ###
# v1.1.0

#> [frontmatter]
#> title = "Tarea opcional: punto flotante"
#> description = "Soluciones, experimentos, gráficas y benchmarks ejecutados en Julia."
#> date = "2026-11-08"
#> tags = ["analisis-numerico", "punto-flotante", "julia"]
#>
#>     [[frontmatter.author]]
#>     name = "Mateo Gabriel González Lara"

using Markdown
using InteractiveUtils

"""

open(OUTPUT, "w") do io
    print(io, frontmatter)
    for block in cell_blocks
        println(io, block)
    end
    println(io, "# ╔═╡ Cell order:")
    println(io, join(cell_order, '\n'))
end
println("Notebook Pluto generado en: ", OUTPUT)
