# Dexaggregatex

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

Example response:

```json5
{
  "data": {
    "rebasedMarket": {
      "baseAddress": "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
      "pairs": [
        {
          "baseAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "baseSymbol": "ETH",
          "marketData": [
            {
              "baseVolume": 287695.7818312325,
              "currentAsk": 0.01105725149559744,
              "currentBid": 0.010817169674888352,
              "exchange": "idex",
              "lastPrice": 0.01105994904415046
            }
          ],
          "quoteAddress": "0x1b80eeeadcc590f305945bcc258cfa770bbe1890",
          "quoteSymbol": "BQQQ"
        },
        {
          "baseAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "baseSymbol": "ETH",
          "marketData": [
            {
              "baseVolume": 283869.7495462329,
              "currentAsk": 0.13264790472392743,
              "currentBid": 0.1246618110188598,
              "exchange": "idex",
              "lastPrice": 0.1246618110188598
            }
          ],
          "quoteAddress": "0x763fa6806e1acf68130d2d0f0df754c93cc546b2",
          "quoteSymbol": "LIT"
        },
        ...
      ]
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
    utcTime
    pair {
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

Example response:

```json5
{
  "data": {
    "lastUpdate": {
      "pair": {
        "baseAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
        "baseSymbol": "ETH",
        "marketData": [
          {
            "baseVolume": 14184.500348420259,
            "currentAsk": 0.003696198287649789,
            "currentBid": 0.003696198287649789,
            "exchange": "uniswap",
            "lastPrice": 0.003696396887266987
          },
          {
            "baseVolume": 9188.77990512,
            "currentAsk": 0.0036900369003690036,
            "currentBid": 0.0037317920733527027,
            "exchange": "oasis",
            "lastPrice": 0.0036870997671707368
          }
        ],
        "quoteAddress": "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
        "quoteSymbol": "DAI"
      },
      "utcTime": "2019-06-18 06:35:29.013503"
    }
  }
}
```

4. Subscribe to a list of all exchanges currently included in the market.
```graphql
subscription exchanges {
  exchanges
}
```

Example response:

```json5
{
  "data": {
    "exchanges": [
      "uniswap",
      "tokenstore",
      "radar",
      "paradex",
      "oasis",
      "kyber",
      "idex",
      "ddex"
    ]
  }
}
```

All of these subscriptions are also available as simple GraphQL queries (change `subscription` operation to `query` or
leave it out entirely).

## Architectural overview

This back-end is a scalable Elixir OTP application. Its supervision tree includes highly concurrent processes, 
such as rebasing market data to a given token by finding and traversing all paths to the token and weighting rates 
according to their paths' volumes.

### Supervision tree

* Dexaggregatex (Application)
    * MarketFetching.Supervisor (Supervisor)
        * DdexFetcher (Task)
        * IdexFetcher (Task)
        * KyberFetcher (Task)
        * OasisFetcher (Task)
        * ParadexFetcher (Task)
        * RadarFetcher (Task)
        * TokenstoreFetcher (Task)
        * UniswapFetcher (Task)
    * Market.Supervisor (Supervisor)
        * Market.Server (GenServer)
        * Rebasing.Cache (GenServer)
        * Market.Neighbors (GenServer)
    * API.Supervisor
        * API.Endpoint (Phoenix.Endpoint, Absinthe.Phoenix.Endpoint)
        * Absinthe.Subscription (Absinthe.Subscription)
        
### MarketFetching

All processes that gather market data from decentralized exchanges. They are implemented as OTP Tasks, providing 
concurrency without maintaining internal state. These are currently clients of either REST WebSocket/HTTP APIs provided 
by the exchanges or smart contract subgraphs (see [The Graph](https://thegraph.com/)).
Market data gets validated here before being sent off to the Market part of the application.

### Market

All processes that maintain the latest aggregated market data. They are implemented as OTP GenServers, providing both 
concurrency and the ability to maintain internal state. The Market Server maintains the latest raw market. It constantly 
gets fed new data from MarketFetching. The Neighbors and Rebasing.Cache GenServers maintain data useful during the 
computation of rebased markets.

### API

Phoenix endpoint exposing a REST and GraphQL API. Usage of the GraphQL API is recommended since it's way more flexible 
and supports subscriptions.




