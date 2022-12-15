# Themis
Cross-chain vickrey auction powered by Hyperlane 

## Background
My interested were piqued when I came across the ["sneaky" auction](https://a16zcrypto.com/hidden-in-plain-sight-a-sneaky-solidity-implementation-of-a-sealed-bid-auction/) post a couple weeks ago. On-chain auction is very focus area for designing robust market structure for your web3 protocols, be it NFT mints or early access to your token-gated platform. This particular design was interesting because it combined the `create2` opcode and state proofs to guarantee bid privacy for users without making them lock up more collateral than required for the bid. Plus, a vickey auctions is a blind second price auction which is acknowledged as closest to fair value auction or being an ("optimal")[https://web.stanford.edu/~jdlevin/Econ%20286/Auctions.pdf] auction. But there were a few things missing for this to a viable option for everyday drops and users (I'll use the example of Ticketmaster's botched release of Taylor Swift's tour tickets as a use case):

- the auctions are configured for one item and needed to be setup afresh for each item. If you wanted to sell 10k tickets, you'll to instantiate and conduct 10k auctionsn which is not feasible.
- the auction lives only on one chain which means users will need to bridge their assets to this chain and then place their bids. Here, you are introducing additional latency and immenient bridge risk.
- the auctions takes only ETH as collateral for the bids which is rather inflexible. Any auctions especially ones which are expected to be oversubscribed need to have arbitrary ERC20 collateralization feature.

These issues are why I started this project, to productionize the novel `create2` mechanism to be used for more and more auctions going forward.

## How it works

Private or sealed bid auctions need to be a. private till everyone else has placed their bid and b. winner has enough collateral locked up to fulfil their commitment. Private bids obsecuate the bid amount and who person behind the bid. 

We use the `CREAT2` opcode similar to a16z's implementation. With the `CREATE2`, we can predict the exact address of the collateralized vaults and send them our bid amounts before initializing the actual contract. This way, it will look like any ordinary transfer of tokens to an address from the outside. This serves as a hash commitment for our bids and collateral we deposited into the predeployed vault. Since the bidder can't access the private keys of the vault, the collateral is locked until revealed. All this happens on the origin chain.

WIP
