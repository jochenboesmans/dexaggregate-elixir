# Dexaggregatex

GraphQL API serving aggregated market data from decentralized exchanges.
It should be live at [dexaggregate.com](dexaggregate.com/graphiql).

## Example usage

### GraphQL

Use the `/graphiql` endpoint to explore the API's full documentation and test queries. Below are some examples.

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
        baseVolume,
        timestamp
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
              "baseVolume": 405381.2493035906,
              "currentAsk": 0.2508877262059843,
              "currentBid": 0.2436510666697288,
              "exchange": "idex",
              "lastPrice": 0.24771709183285293,
              "timestamp": 1560968095304
            }
          ],
          "quoteAddress": "0x445f51299ef3307dbd75036dd896565f5b4bf7a5",
          "quoteSymbol": "VIDT"
        },
        {
          "baseAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "baseSymbol": "ETH",
          "marketData": [
            {
              "baseVolume": 282258.1202783009,
              "currentAsk": 0.1467061017684216,
              "currentBid": 0.14084513715165947,
              "exchange": "idex",
              "lastPrice": 0.1467061017684216,
              "timestamp": 1560968095299
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
        timestamp
      }
    }
  }
}
```

Example response:

```json5
{
  "data": {
    "market": {
      "pairs": [
        {
          "baseAddress": "0xf0ee6b27b759c9893ce4f094b49ad28fd15a23e4",
          "baseSymbol": "ENG",
          "marketData": [
            {
              "baseVolume": 5665.50667791,
              "currentAsk": 452.72673789999993,
              "currentBid": 442.41367917761823,
              "exchange": "kyber",
              "lastPrice": 433.02504128,
              "timestamp": 1560968125059
            }
          ],
          "quoteAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "quoteSymbol": "ETH"
        },
        {
          "baseAddress": "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
          "baseSymbol": "DAI",
          "marketData": [
            {
              "baseVolume": 371179.6956054791,
              "currentAsk": 267.123495,
              "currentBid": 269.00754538500814,
              "exchange": "kyber",
              "lastPrice": 269.0017302283346,
              "timestamp": 1560968125059
            }
          ],
          "quoteAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
          "quoteSymbol": "ETH"
        },
        ...
      ]
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
        baseVolume,
        timestamp
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
        "baseAddress": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
        "baseSymbol": "WETH",
        "marketData": [
          {
            "baseVolume": 104.04102771634618,
            "currentAsk": 1,
            "currentBid": 1,
            "exchange": "kyber",
            "lastPrice": 1,
            "timestamp": 1560968423771
          }
        ],
        "quoteAddress": "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
        "quoteSymbol": "ETH"
      },
      "utcTime": "2019-06-19 18:20:23.771268"
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

All market data is ordered by descending base volume by default.

All of these subscriptions are also available as simple GraphQL queries (change `subscription` operation to `query` or
leave it out entirely).

Use the `/graphql` endpoint to connect to the API with a GraphQL client of your choice.

## REST

There are simplified versions of the queries available in the HTTP REST API:

* [/market](http://dexaggregate.com/market)
* [/rebased_market/:rebase_address](http://dexaggregate.com/rebase_address/0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359)
* [/exchanges](http://dexaggregate.com/exchanges)
* [/last_update](http://dexaggregate.com/last_update)


## Architectural overview

This back-end is an Elixir OTP application. Its supervision tree includes concurrent processes, 
such as rebasing market data to a given token by finding and traversing all paths to the token and weighting rates 
according to their paths' volumes (see [rebasing](#on-rebasing))

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

## On rebasing

Rebased markets are pure functions of the exchange data. No external price oracles are used.

Market pairs are rebased by finding and traversing paths from the original pair to a pair with a base token in which the 
market is to be rebased. This process is bidirectional, meaning that both paths connecting to the base token of the 
original pair and paths connecting to the quote token of the original pair are being considered. Paths are weighted by 
their pairs' average volume. These weights are used to determine the ultimate rebased rate (making rebased rates from 
paths with a higher average volume more important).


