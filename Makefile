-include .env

install:; forge install && yarn --cwd ./lib/hyperlane-monorepo/ install

deploy-fork :; forge script script/Themis.s.sol:ThemisScript --rpc-url ${GOERLI_RPC_URL} --gas-estimate-multiplier 200 --broadcast --verify -vvvv

# deploy auction on goerli, serving as the hub chain
deploy-auction :; forge script script/ThemisAuction.s.sol:AuctionScript -f goerli --gas-estimate-multiplier 200 --broadcast -vvvv

# save the auction contract address to a file
save-auction-address :; jq '.transactions[] | select(.contractName == "ThemisAuction") | {contractName, contractAddress}' broadcast/ThemisAuction.s.sol/5/run-latest.json > script/deploy/info.json

# deploy controller on mumbai aka spoke chain
deploy-controller :; forge script script/ThemisController.s.sol:ControllerScript -f mumbai --gas-estimate-multiplier 200 --broadcast -vvvv

deploy-testnet: deploy-auction save-auction-address deploy-controller
	echo "Deployed successfully to Goerli and Mumbai"

verify-contract :; forge verify-contract 0x4390c57290d6432801fa973530377973c647cd66 src/ThemisAuction.sol:ThemisAuction --chain-id 5 --watch

# More commands
init-auction :; cast send ${AUCTION} "initialize(uint64,uint64,uint128)" 432000 86400 5000000 --rpc-url ${GOERLI_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY}

set-usdc :; cast send ${CONTROLLER} "setCollateralToken(address)" --gas-price 100000000000 0xE097d6B3100777DC31B34dC2c58fB524C2e76921 --rpc-url ${MUMBAI_RPC_URL} --private-key ${DEPLOYER_PRIVATE_KEY}
