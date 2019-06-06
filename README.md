# dexaggregatex

GraphQL API serving aggregated market data from decentralized exchanges.

## Example usage

1. Subscribe to an aggregated market model with all prices and volumes denominated in DAI (as specified by the rebaseAddress argument). 
```graphql
subscription rebasedMarket {
  updatedRebasedMarket (rebaseAddress: "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359") {
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

2. Get data about the last update to the market.

```graphql
query lastUpdate {
    lastUpdate {
        exchange
        timestamp
    }
}
```

3. Get a list of names of the exchanges currently included in the market model.

```graphql
query exchangeInMarket {
  exchanges
}
```






