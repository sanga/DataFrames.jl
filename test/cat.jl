module TestCat
    using Base.Test, DataFrames

    #
    # hcat
    #

    nvint = [1, 2, null, 4]
    nvstr = ["one", "two", null, "four"]

    df2 = DataFrame(Any[nvint, nvstr])
    df3 = DataFrame(Any[nvint])
    df4 = convert(DataFrame, [1:4 1:4])
    df5 = DataFrame(Any[Union{Int, Null}[1,2,3,4], nvstr])

    dfh = hcat(df3, df4)
    @test size(dfh, 2) == 3
    @test names(dfh) == [:x1, :x1_1, :x2]
    @test dfh[:x1] == df3[:x1]
    @test dfh == [df3 df4]
    @test dfh == DataFrames.hcat!(DataFrame(), df3, df4)

    dfh3 = hcat(df3, df4, df5)
    @test names(dfh3) == [:x1, :x1_1, :x2, :x1_2, :x2_1]
    @test dfh3 == hcat(dfh, df5)
    @test dfh3 == DataFrames.hcat!(DataFrame(), df3, df4, df5)

    @test df2 == DataFrames.hcat!(df2)

    @testset "hcat ::AbstractDataFrame" begin
        df = DataFrame(A = repeat('A':'C', inner=4), B = 1:12)
        gd = groupby(df, :A)
        answer = DataFrame(A = fill('A', 4), B = 1:4, A_1 = 'B', B_1 = 5:8, A_2 = 'C', B_2 = 9:12)
        @test hcat(gd...) == answer
        answer = answer[1:4]
        @test hcat(gd[1], gd[2]) == answer
    end

    @testset "hcat ::Vectors" begin
        df = DataFrame()
        DataFrames.hcat!(df, CategoricalVector{Union{Int, Null}}(1:10))
        @test df[1] == collect(1:10)
        DataFrames.hcat!(df, 1:10)
        @test df[2] == collect(1:10)
    end

    @testset "hcat ::AbstractDataFrame" begin
        df = DataFrame(A = repeat('A':'C', inner=4), B = 1:12)
        gd = groupby(df, :A)
        answer = DataFrame(A = fill('A', 4), B = 1:4, A_1 = 'B', B_1 = 5:8, A_2 = 'C', B_2 = 9:12)
        @test hcat(gd...) == answer
        answer = answer[1:4]
        @test hcat(gd[1], gd[2]) == answer
    end

    @testset "hcat ::Vectors" begin
        df = DataFrame()
        DataFrames.hcat!(df, CategoricalVector{Union{Int, Null}}(1:10))
        @test df[1] == CategoricalVector(1:10)
        DataFrames.hcat!(df, collect(1:10))
        @test df[2] == collect(1:10)
    end

    #
    # vcat
    #

    null_df = DataFrame(Int, 0, 0)
    df = DataFrame(Int, 4, 3)

    # Assignment of rows
    df[1, :] = df[1, :]
    df[1:2, :] = df[1:2, :]
    df[[true,false,false,true], :] = df[2:3, :]

    # Scalar broadcasting assignment of rows
    df[1, :] = 1
    df[1:2, :] = 1
    df[[true,false,false,true], :] = 3

    # Vector broadcasting assignment of rows
    df[1:2, :] = [2,3]
    df[[true,false,false,true], :] = [2,3]

    # Assignment of columns
    df[1] = zeros(4)
    df[:, 2] = ones(4)

    # Broadcasting assignment of columns
    df[:, 1] = 1
    df[1] = 3
    df[:x3] = 2

    # assignment of subtables
    df[1, 1:2] = df[2, 2:3]
    df[1:2, 1:2] = df[2:3, 2:3]
    df[[true,false,false,true], 2:3] = df[1:2,1:2]

    # scalar broadcasting assignment of subtables
    df[1, 1:2] = 3
    df[1:2, 1:2] = 3
    df[[true,false,false,true], 2:3] = 3

    # vector broadcasting assignment of subtables
    df[1:2, 1:2] = [3,2]
    df[[true,false,false,true], 2:3] = [2,3]

    @test vcat(null_df) == DataFrame()
    @test vcat(null_df, null_df) == DataFrame()
    @test_throws ArgumentError vcat(null_df, df)
    @test_throws ArgumentError vcat(df, null_df)
    @test eltypes(vcat(df, df)) == Type[Float64, Float64, Int]
    @test size(vcat(df, df)) == (size(df, 1) * 2, size(df, 2))
    @test eltypes(vcat(df, df, df)) == Type[Float64, Float64, Int]
    @test size(vcat(df, df, df)) == (size(df, 1) * 3, size(df, 2))

    alt_df = deepcopy(df)
    vcat(df, alt_df)

    # Don't fail on non-matching types
    df[1] = zeros(Int, nrow(df))
    vcat(df, alt_df)

    dfr = vcat(df4, df4)
    @test size(dfr, 1) == 8
    @test names(df4) == names(dfr)
    @test dfr == [df4; df4]

    @test eltypes(vcat(DataFrame(a = [1]), DataFrame(a = [2.1]))) == Type[Float64]
    @test eltypes(vcat(DataFrame(a = nulls(Int, 1)), DataFrame(a = Union{Float64, Null}[2.1]))) == Type[Union{Float64, Null}]

    # Minimal container type promotion
    dfa = DataFrame(a = CategoricalArray{Union{Int, Null}}([1, 2, 2]))
    dfb = DataFrame(a = CategoricalArray{Union{Int, Null}}([2, 3, 4]))
    dfc = DataFrame(a = Union{Int, Null}[2, 3, 4])
    dfd = DataFrame(Any[2:4], [:a])
    dfab = vcat(dfa, dfb)
    dfac = vcat(dfa, dfc)
    @test dfab[:a] == [1, 2, 2, 2, 3, 4]
    @test dfac[:a] == [1, 2, 2, 2, 3, 4]
    @test isa(dfab[:a], CategoricalVector{Union{Int, Null}})
    @test isa(dfac[:a], CategoricalVector{Union{Int, Null}})
    # ^^ container may flip if container promotion happens in Base/DataArrays
    dc = vcat(dfd, dfc)
    @test vcat(dfc, dfd) == dc

    # Zero-row DataFrames
    dfc0 = similar(dfc, 0)
    @test vcat(dfd, dfc0, dfc) == dc
    @test eltypes(vcat(dfd, dfc0)) == eltypes(dc)

    # vcat should be able to concatenate different implementations of AbstractDataFrame (PR #944)
    @test vcat(view(DataFrame(A=1:3),2),DataFrame(A=4:5)) == DataFrame(A=[2,4,5])

    @testset "vcat >2 args" begin
        @test vcat(DataFrame(), DataFrame(), DataFrame()) == DataFrame()
        df = DataFrame(x = trues(1), y = falses(1))
        @test vcat(df, df, df) == DataFrame(x = trues(3), y = falses(3))
    end

    @testset "vcat mixed coltypes" begin
        df = vcat(DataFrame([[1]], [:x]), DataFrame([[1.0]], [:x]))
        @test df == DataFrame([[1.0, 1.0]], [:x])
        @test typeof.(df.columns) == [Vector{Float64}]
        df = vcat(DataFrame([[1]], [:x]), DataFrame([["1"]], [:x]))
        @test df == DataFrame([[1, "1"]], [:x])
        @test typeof.(df.columns) == [Vector{Any}]
        df = vcat(DataFrame([Union{Null, Int}[1]], [:x]), DataFrame([[1]], [:x]))
        @test df == DataFrame([[1, 1]], [:x])
        @test typeof.(df.columns) == [Vector{Union{Null, Int}}]
        df = vcat(DataFrame([CategoricalArray([1])], [:x]), DataFrame([[1]], [:x]))
        @test df == DataFrame([[1, 1]], [:x])
        @test typeof(df[:x]) <: CategoricalVector{Int}
        df = vcat(DataFrame([CategoricalArray([1])], [:x]),
                  DataFrame([Union{Null, Int}[1]], [:x]))
        @test df == DataFrame([[1, 1]], [:x])
        @test typeof(df[:x]) <: CategoricalVector{Union{Int, Null}}
        df = vcat(DataFrame([CategoricalArray([1])], [:x]),
                  DataFrame([CategoricalArray{Union{Int, Null}}([1])], [:x]))
        @test df == DataFrame([[1, 1]], [:x])
        @test typeof(df[:x]) <: CategoricalVector{Union{Int, Null}}
        df = vcat(DataFrame([Union{Int, Null}[1]], [:x]),
                  DataFrame([["1"]], [:x]))
        @test df == DataFrame([[1, "1"]], [:x])
        @test typeof.(df.columns) == [Vector{Any}]
        df = vcat(DataFrame([CategoricalArray([1])], [:x]),
                  DataFrame([CategoricalArray(["1"])], [:x]))
        @test df == DataFrame([[1, "1"]], [:x])
        @test typeof(df[:x]) <: CategoricalVector{Any}
        df = vcat(DataFrame([trues(1)], [:x]), DataFrame([[false]], [:x]))
        @test df == DataFrame([[true, false]], [:x])
        @test typeof.(df.columns) == [Vector{Bool}]
    end

    @testset "vcat errors" begin
        err = @test_throws ArgumentError vcat(DataFrame(), DataFrame(), DataFrame(x=[]))
        @test err.value.msg == "column(s) x are missing from argument(s) 1 and 2"
        err = @test_throws ArgumentError vcat(DataFrame(), DataFrame(), DataFrame(x=[1]))
        @test err.value.msg == "column(s) x are missing from argument(s) 1 and 2"
        df1 = DataFrame(A = 1:3, B = 1:3)
        df2 = DataFrame(A = 1:3)
        # right missing 1 column
        err = @test_throws ArgumentError vcat(df1, df2)
        @test err.value.msg == "column(s) B are missing from argument(s) 2"
        # left missing 1 column
        err = @test_throws ArgumentError vcat(df2, df1)
        @test err.value.msg == "column(s) B are missing from argument(s) 1"
        # multiple missing 1 column
        err = @test_throws ArgumentError vcat(df1, df2, df2, df2, df2, df2)
        @test err.value.msg == "column(s) B are missing from argument(s) 2, 3, 4, 5 and 6"
        # argument missing >1 columns
        df1 = DataFrame(A = 1:3, B = 1:3, C = 1:3, D = 1:3, E = 1:3)
        err = @test_throws ArgumentError vcat(df1, df2)
        @test err.value.msg == "column(s) B, C, D and E are missing from argument(s) 2"
        # >1 arguments missing >1 columns
        err = @test_throws ArgumentError vcat(df1, df2, df2, df2, df2)
        @test err.value.msg == "column(s) B, C, D and E are missing from argument(s) 2, 3, 4 and 5"
        # out of order
        df2 = df1[reverse(names(df1))]
        err = @test_throws ArgumentError vcat(df1, df2)
        @test err.value.msg == "column order of argument(s) 1 != column order of argument(s) 2"
        # first group >1 arguments
        err = @test_throws ArgumentError vcat(df1, df1, df2)
        @test err.value.msg == "column order of argument(s) 1 and 2 != column order of argument(s) 3"
        # second group >1 arguments
        err = @test_throws ArgumentError vcat(df1, df2, df2)
        @test err.value.msg == "column order of argument(s) 1 != column order of argument(s) 2 and 3"
        # first and second groups >1 argument
        err = @test_throws ArgumentError vcat(df1, df1, df1, df2, df2, df2)
        @test err.value.msg == "column order of argument(s) 1, 2 and 3 != column order of argument(s) 4, 5 and 6"
        # >2 groups out of order
        srand(1)
        df3 = df1[shuffle(names(df1))]
        err = @test_throws ArgumentError vcat(df1, df1, df1, df2, df2, df2, df3, df3, df3, df3)
        @test err.value.msg == "column order of argument(s) 1, 2 and 3 != column order of argument(s) 4, 5 and 6 != column order of argument(s) 7, 8, 9 and 10"
        # missing columns throws error before out of order columns
        df1 = DataFrame(A = 1, B = 1)
        df2 = DataFrame(A = 1)
        df3 = DataFrame(B = 1, A = 1)
        err = @test_throws ArgumentError vcat(df1, df2, df3)
        @test err.value.msg == "column(s) B are missing from argument(s) 2"
        # unique columns for both sides
        df1 = DataFrame(A = 1, B = 1, C = 1, D = 1)
        df2 = DataFrame(A = 1, C = 1, D = 1, E = 1, F = 1)
        err = @test_throws ArgumentError vcat(df1, df2)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1, and column(s) B are missing from argument(s) 2"
        err = @test_throws ArgumentError vcat(df1, df1, df2, df2)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1 and 2, and column(s) B are missing from argument(s) 3 and 4"
        df3 = DataFrame(A = 1, B = 1, C = 1, D = 1, E = 1)
        err = @test_throws ArgumentError vcat(df1, df2, df3)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1, column(s) B are missing from argument(s) 2, and column(s) F are missing from argument(s) 3"
        err = @test_throws ArgumentError vcat(df1, df1, df2, df2, df3, df3)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1 and 2, column(s) B are missing from argument(s) 3 and 4, and column(s) F are missing from argument(s) 5 and 6"
        err = @test_throws ArgumentError vcat(df1, df1, df1, df2, df2, df2, df3, df3, df3)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1, 2 and 3, column(s) B are missing from argument(s) 4, 5 and 6, and column(s) F are missing from argument(s) 7, 8 and 9"
        # df4 is a superset of names found in all other DataFrames and won't be shown in error
        df4 = DataFrame(A = 1, B = 1, C = 1, D = 1, E = 1, F = 1)
        err = @test_throws ArgumentError vcat(df1, df2, df3, df4)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1, column(s) B are missing from argument(s) 2, and column(s) F are missing from argument(s) 3"
        err = @test_throws ArgumentError vcat(df1, df1, df2, df2, df3, df3, df4, df4)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1 and 2, column(s) B are missing from argument(s) 3 and 4, and column(s) F are missing from argument(s) 5 and 6"
        err = @test_throws ArgumentError vcat(df1, df1, df1, df2, df2, df2, df3, df3, df3, df4, df4, df4)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1, 2 and 3, column(s) B are missing from argument(s) 4, 5 and 6, and column(s) F are missing from argument(s) 7, 8 and 9"
        err = @test_throws ArgumentError vcat(df1, df2, df3, df4, df1, df2, df3, df4, df1, df2, df3, df4)
        @test err.value.msg == "column(s) E and F are missing from argument(s) 1, 5 and 9, column(s) B are missing from argument(s) 2, 6 and 10, and column(s) F are missing from argument(s) 3, 7 and 11"
    end
    x = view(DataFrame(A = Vector{Union{Null, Int}}(1:3)), 2)
    y = DataFrame(A = 4:5)
    @test vcat(x, y) == DataFrame(A = [2, 4, 5])
end
