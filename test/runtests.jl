using ParticipationAnalytics
using Clustering
using SparseArrays
using Test
using TextAnalysis

@testset "slatetext" begin
    @test slatetext("{\"document\":{\"nodes\":[]}}") == ""

    str = """
        {
            \"document\": {
                \"nodes\": [{
                    \"kind\": \"text\",
                    \"leaves\": [{
                        \"text\": \"Julia\"
                    }]
                }, {
                    \"kind\": \"block\",
                    \"nodes\": [{
                        \"kind\": \"text\",
                        \"leaves\": [{
                            \"text\": \"is fun\"
                        }]
                    }]
                }]
            }
        }
    """
    @test slatetext(str) == "Julia is fun"
end

@testset "preprocessing" begin
    entity = StringDocument("1Julia.is,2fun")
    preprocess!(entity)
    @test text(entity) == "Julia is fun"

    entity = StringDocument("1Julia.is,2fun")
    crps = Corpus([entity])
    preprocess!(crps)
    @test text(crps[1]) == "Julia is fun"

    @test preprocess("1Julia.is,2fun") == "Julia is fun"
end

@testset "similarities" begin
    doc1 = StringDocument("a b")
    doc2 = StringDocument("b c")

    crps = Corpus([doc1, doc1])
    sims = similarities(crps)
    @test sims[1] ≈ sims[4] ≈ 1.0 && isnan(sims[2]) && isnan(sims[3])
    @test similarities(crps, false) ≈ [1.0 1.0; 1.0 1.0]

    crps = Corpus([doc1, doc2])
    @test similarities(crps) ≈ [1.0 0.0; 0.0 1.0]
    @test similarities(crps, false) ≈ [1.0 0.5; 0.5 1.0]
end

@testset "clustering" begin
    doc1 = StringDocument("a")
    doc2 = StringDocument("b")
    doc3 = StringDocument("c")
    crps = Corpus([doc1, doc2, doc3])

    c = clustering(crps, 2)
    @test typeof(c) <: ClusteringResult && nclusters(c) == 2

    c = clustering(crps, 2, false)
    @test typeof(c) <: ClusteringResult && nclusters(c) == 2
end

@testset "topicmodel" begin
    doc1 = StringDocument("a")
    doc2 = StringDocument("b")
    crps = Corpus([doc1, doc2])
    topicword, topicdoc = topicmodel(crps, 2, 100, 0.1, 0.1)
    @test typeof(topicword) == SparseMatrixCSC{Float64,Int64}
    @test typeof(topicdoc) == Array{Float64,2}
end

@testset "topkwords" begin
    doc1 = StringDocument("programming in julia")
    doc2 = StringDocument("python programming")
    doc3 = StringDocument("julia and ada")
    crps = Corpus([doc1, doc2, doc3])
    topicword, topicdoc = topicmodel(crps, 2, 100, 0.1, 0.1)
    words = topkwords(topicword, 1, crps, 2)
    @test typeof(words) == Array{Tuple{String,Float64},1}
    @test length(words) == 2
    @test words[1][2] >= words[2][2]
end