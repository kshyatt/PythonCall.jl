size_to_fstrides(elsz::Integer, sz::Integer...) =
    isempty(sz) ? () : (elsz, size_to_fstrides(elsz * sz[1], sz[2:end]...)...)

size_to_cstrides(elsz::Integer, sz::Integer...) =
    isempty(sz) ? () : (size_to_cstrides(elsz * sz[end], sz[1:end-1]...)..., elsz)

isfcontiguous(o::AbstractArray) = strides(o) == size_to_fstrides(1, size(o)...)
isccontiguous(o::AbstractArray) = strides(o) == size_to_cstrides(1, size(o)...)

function ismutablearray(x::AbstractArray)
    try
        i = firstindex(x)
        y = x[i]
        x[i] = y
        true
    catch
        false
    end
end

pybufferformat(::Type{T}) where {T} =
    T == Int8 ? "=b" :
    T == UInt8 ? "=B" :
    T == Int16 ? "=h" :
    T == UInt16 ? "=H" :
    T == Int32 ? "=i" :
    T == UInt32 ? "=I" :
    T == Int64 ? "=q" :
    T == UInt64 ? "=Q" :
    T == Float16 ? "=e" :
    T == Float32 ? "=f" :
    T == Float64 ? "=d" :
    T == Complex{Float16} ? "=Ze" :
    T == Complex{Float32} ? "=Zf" :
    T == Complex{Float64} ? "=Zd" :
    T == Bool ? "?" :
    T == Ptr{Cvoid} ? "P" :
    if isstructtype(T) && isconcretetype(T) && Base.allocatedinline(T)
        n = fieldcount(T)
        flds = []
        for i in 1:n
            nm = fieldname(T, i)
            tp = fieldtype(T, i)
            push!(flds, string(pybufferformat(tp), nm isa Symbol ? ":$nm:" : ""))
            d = (i==n ? sizeof(T) : fieldoffset(T, i+1)) - (fieldoffset(T, i) + sizeof(tp))
            @assert d≥0
            d>0 && push!(flds, "$(d)x")
        end
        string("T{", join(flds, " "), "}")
    else
        "$(Base.aligned_sizeof(T))x"
    end

pybufferformat_to_type(fmt::AbstractString) =
    fmt == "b" ? Cchar :
    fmt == "B" ? Cuchar :
    fmt == "h" ? Cshort :
    fmt == "H" ? Cushort :
    fmt == "i" ? Cint :
    fmt == "I" ? Cuint :
    fmt == "l" ? Clong :
    fmt == "L" ? Culong :
    fmt == "q" ? Clonglong :
    fmt == "Q" ? Culonglong :
    fmt == "e" ? Float16 :
    fmt == "f" ? Cfloat :
    fmt == "d" ? Cdouble :
    fmt == "?" ? Bool :
    fmt == "P" ? Ptr{Cvoid} :
    fmt == "O" ? CPyObjRef :
    error("not implemented: $(repr(fmt))")