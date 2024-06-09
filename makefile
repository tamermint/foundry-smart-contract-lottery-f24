-include .env

.PHONY: all test deploy

help:
	@echo "Makefile for ${Cyfrin/Smart Contract Lottery}"
	@echo "make deploy [ARGS=...]"
	@echo "make test [ARGS=...]"

build:; forge build

install:; forge install Cyfrin/foundry-devops --no-commit && forge install transmissions11/solmate --no-commit && forge install smartcontractkit/chainlink-brownie-contracts --no-commit

test:; forge test 

anvil:; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

format:; forge fmt

NETWORK_ARGS := --rpc-url http://127.0.0.1:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

ifeq ($(findstring --network-sepolia, $(ARGS)), --network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)