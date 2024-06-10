# Smart Contract Lottery - Powered by Foundry (Raffle Contracts)

> To get testnet Link/ETH - visit [faucets.chain.link](faucets.chain.link)
> THIS IS ONLY DEPLOYABLE TO SEPOLIA. IF YOU WISH TO DEPLOY TO MAINNET YOU NEED TO UPDATE THE HELPER CONFIG
> THIS CAN RUN ON LOCAL HOST (i.e. ANVIL)

## What is this project about?

- This project is about creating a decentralized lottery system using blockchain technology. The system allows users to participate in an online Raffle and picks a winner among the users and then pays out the winner. The winner is picked in a provably random manner using Chainlink's VRF function

 </br>

## How does it work?

- 1. Users enter by paying for a ticket\
  2. After an definite interval X, the lottery contract will automatically pick a winner from the pool\
  3. The randomness is derived using Chainlink's VRF function\
  4. The automation is performed using Chainlink keepers

  </br>

- Some constraints

  > a. No actual users involved. Most likely it will be dummy accounts sending fake eth into the smart contract\
  > b. It's not production scale\
  > c. It's only deployed in Sepolia
  > c. It's not meant to be used in production without further testing and security audits

   </br>

## Getting started

### Requirements

- You need to have git installed. Get steps from the official [link](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).

- You need to have [foundry](https://getfoundry.sh/) installed

### Quickstart

```zsh
git clone https://github.com/tamermint/foundry-smart-contract-lottery-f24.git
cd foundry-smart-contract-lottery-f24
forge build
```

- Refer to the makefile for specific instructions regarding deployment and build with instructions

### Note on VRFv2 Subscription

- You need to have a VRFv2 subscription on the Chainlink network. You can use my settings in the HelperConfig.s.sol - but remember to fund the subcription - it currently has 32 Link so you're good for multiple runs

- You have to register a new Upkeep and fund it (atleast 5 link should do)
