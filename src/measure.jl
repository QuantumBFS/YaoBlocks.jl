export measure

abstract type AbstractMeasure <: AbstractBlock{UnkownSize, Any} end

MatrixTrait(::AbstractMeasure) = MatrixUnkown()

mutable struct Measure{K} <: AbstractMeasure
    locations::NTuple{K, Int}
    collapseto::Union{Int, Nothing}
    remove::Bool
    results::Vector{Int}
    Measure(locations::NTuple{K, Int}, collapseto, remove) where K =
        new{K}(locations, collapseto, remove)
end

function YaoBase.measure(locs::Int...; collapseto=nothing, remove=false)
    Measure(locs, collapseto, remove)
end

function apply!(r::AbstractRegister, m::Measure{0})
    if m.collapseto !== nothing
        m.results = measure_setto!(r; bit_config=r.collapseto)
    elseif m.remove
        m.results = measure_remove!(r)
    else
        m.results = measure!(r)
    end
    return m
end

function apply!(r::AbstractRegister, m::Measure)
    if m.collapseto !== nothing
        m.results = measure_setto!(r, m.locations; bit_config=r.collapseto)
    elseif m.remove
        m.results = measure_remove!(r, m.locations)
    else
        m.results = measure!(r, m.locations)
    end
    return m
end


# """
#     Measure <: AbstractMeasure
#     Measure() -> Measure
#
# Measure block, collapse a state and store measured value, e.g.
#
# # Examples
# ```julia-repl
# julia> m = Measure();
#
# julia> reg = product_state(4, 7)
# DefaultRegister{1, Complex{Float64}}
#     active qubits: 4/4
#
# julia> reg |> m
# DefaultRegister{1, Complex{Float64}}
#     active qubits: 4/4
#
# julia> m.result
# 1-element Array{Int64,1}:
#  7
# ```
#
# Note:
# `Measure` returns a vector here, the length corresponds to batch dimension of registers.
# """
# mutable struct Measure <: AbstractMeasure
#     results::Vector{Int}
#     Measure() = new()
# end
#
# """
#     MeasureAndRemove <: AbstractMeasure
#     MeasureAndRemove() -> MeasureAndRemove
#
# Measure and remove block, remove measured qubits and store measured value.
# """
# mutable struct MeasureAndRemove <: AbstractMeasure
#     result::Vector{Int}
#     MeasureAndRemove() = new()
# end
#
# """
#     MeasureAndCollapseTo <: AbstractMeasure
#     MeasureAndCollapseTo([val=0]) -> MeasureAndCollapseTo
#
# Measure and reset block, collapse measured qubits to `val` and store measured value.
# """
# mutable struct MeasureAndCollapseTo <: AbstractMeasure
#     bit_config::Int
#     result::Vector{Int}
#     MeasureAndCollapseTo(val::Int) = new(val)
# end
#
# MeasureAndCollapseTo() = MeasureAndCollapseTo(0)
#
# function apply!(r::AbstractRegister, m::Measure)
#     m.results = measure!(r)
#     return r
# end
#
# function apply!(r::AbstractRegister, m::MeasureAndRemove)
#     m.results = measure_remove!(r)
#     return r
# end
#
# function apply!(r::AbstractRegister, m::MeasureAndCollapseTo)
#     m.results = measure_setto!(r; bit_config=m.bit_config)
#     return r
# end
