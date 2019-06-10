# dexaggregatex

GraphQL API serving aggregated market data from decentralized exchanges.

## Example usage

1. Subscribe to an aggregated market model with all prices and volumes denominated in DAI (as specified by the rebaseAddress argument). 
```graphql
subscription daiRebasedIdexMarket {
  rebasedMarket (rebaseAddress: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359", exchanges: ["idex"]) {
    baseAddress,
    pairs {
      baseSymbol,
      baseAddress,
      quoteSymbol,
      quoteAddress,
      marketData {
        exchange,
        lastPrice,
        currentAsk,
        currentBid,
        baseVolume
      }
    }
  }
}
```

2. Subscribe to a raw aggregated market model with all prices and volumes denominated in the base token of the pair.
```graphql
subscription kyberMarket {
  market (exchanges: ["kyber"]) {
    baseSymbol,
    baseAddress,
    quoteSymbol,
    quoteAddress,
    marketData {
      exchange,
      lastPrice,
      currentAsk,
      currentBid,
      baseVolume
    }
  }
}
```

3. Subscribe to data about the last update to the market.
```graphql
subscription lastUpdate {
  lastUpdate {
    exchange
    timestamp
    utc_time
  }
}
```

4. Subscribe to a list of all exchanges currently included in the market.
```graphql
subscription exchanges {
  exchanges
}
```

All of these subscriptions are also available as simple GraphQL queries.






