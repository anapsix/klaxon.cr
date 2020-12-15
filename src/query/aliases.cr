class Klaxon
  class Query
    module Aliases

      alias PercentAnyAtor = NamedTuple(query_string: NamedTuple(analyze_wildcard: Bool, query: String | Nil))
      alias QueryAggregations = Hash(String | Symbol, NamedTuple(avg: NamedTuple(field: String | Nil)) | NamedTuple(filters: NamedTuple(filters: NamedTuple(denominator: PercentAnyAtor, numerator: PercentAnyAtor))))

      alias QueryMatchers = Array(Hash(String, String))
      alias QueryRange = NamedTuple(gte: String, lte: String)

      alias QueryFilter = NamedTuple(query_string: NamedTuple(analyze_wildcard: Bool, query: String)) | NamedTuple(range: NamedTuple("@timestamp": NamedTuple(gte: String, lte: String)))
      alias QueryString = String

      alias QueryBuilder = NamedTuple(
        aggs: QueryAggregations,
        query: NamedTuple(
          bool: NamedTuple(
            filter: Array(QueryFilter)
          )
        ),
        size: Int32
      )
    end
  end
end
