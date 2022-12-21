-include .env

install:; forge install && yarn --cwd ./lib/hyperlane-monorepo/ install

deploy-fork :; forge script script/Themis.s.sol:ThemisScript --rpc-url ${GOERLI_RPC_URL} --gas-estimate-multiplier 200 --broadcast --verify -vvvv

verify-contract :; forge verify-contract 0x4390c57290d6432801fa973530377973c647cd66 src/ThemisAuction.sol:ThemisAuction --chain-id 5 --watch
