// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/console.sol";

import {MockERC20} from "test/mock/MockERC20.sol";

import {TypeCasts} from "@hyperlane-xyz/core/contracts/libs/TypeCasts.sol";
import {CircleBridgeAdapter} from "@hyperlane-xyz/core/contracts/middleware/liquidity-layer/adapters/CircleBridgeAdapter.sol";

import {XAddress} from "src/lib/XAddress.sol";
import {IThemis} from "src/IThemis.sol";
import {ThemisRouter} from "src/ThemisRouter.sol";
import {ThemisAuction} from "src/ThemisAuction.sol";
import {ThemisController} from "src/ThemisController.sol";

import {BaseTest} from "./utils/BaseTest.sol";

import {MockHyperlaneEnvironment} from "test/mock/MockHyperlaneEnvironment.sol";
import {MockCircleBridge} from "test/mock/MockCircleBridge.sol";
import {MockCircleMessageTransmitter} from "test/mock/MockCircleMessageTransmitter.sol";

contract MockThemisController is ThemisController {
    uint256 bal;

    constructor(address accountRouterAddress_)
        ThemisController(accountRouterAddress_) {}

    function setBalance(uint256 _bal) external {
        bal = _bal;
    }

    // Overridden so we don't have to deal with proofs here.
    // See BalanceProofTest.sol for LibBalanceProof unit tests.
    function _getProvenAccountBalance(
        bytes[] memory /* proof */,
        bytes memory /* blockHeaderRLP */,
        bytes32 /* blockHash */,
        address /* account */
    )
        internal
        override
        view
        returns (uint256 accountBalance)
    {
        return bal;
    }
}


contract ThemisControllerTest is BaseTest {
    using XAddress for XAddress.Info;

    ThemisRouter internal router;
    ThemisRouter internal remoteRouter;

    XAddress.Info internal _auction;
    ThemisAuction internal auction;
    MockThemisController internal controller;

    uint32 remoteDomain;
    uint32 domain;

    // liquidity layer mock
    MockHyperlaneEnvironment testEnv;
    string bridge = "Circle";
    CircleBridgeAdapter bridgeAdapter;
    CircleBridgeAdapter remoteBridgeAdapter;
    MockCircleBridge circleBridge;
    MockCircleMessageTransmitter messageTransmitter;

    function setUp() public override {
        super.setUp();
        vm.roll(block.number + 1_000_000);

        remoteDomain = 1; // domain for auction
        domain = 2; // domain for controller

        testEnv = new MockHyperlaneEnvironment(domain, remoteDomain);
        auction = new ThemisAuction("Ethereal Encounters", "EE", 10_000);
        auction.initialize(
            uint64(1 hours),
            uint64(2 hours),
            uint128(50e6)
        );


        router = new ThemisRouter();
        remoteRouter = new ThemisRouter();

        router.initialize(
            address(testEnv.mailboxes(domain)),
            domain
        );
        remoteRouter.initialize(
            address(testEnv.mailboxes(remoteDomain)),
            remoteDomain
        );

        router.enrollRemoteRouter(
            remoteDomain,
            TypeCasts.addressToBytes32(address(remoteRouter))
        );
        remoteRouter.enrollRemoteRouter(
            domain,
            TypeCasts.addressToBytes32(address(router))

        );


        circleBridge = new MockCircleBridge(usdc);
        messageTransmitter = new MockCircleMessageTransmitter(usdc);
        bridgeAdapter = new CircleBridgeAdapter();
        remoteBridgeAdapter = new CircleBridgeAdapter();

        bridgeAdapter.initialize(
            address(this),
            address(circleBridge),
            address(messageTransmitter),
            address(router)
        );
        remoteBridgeAdapter.initialize(
            address(this),
            address(circleBridge),
            address(messageTransmitter),
            address(remoteRouter)
        );

        bridgeAdapter.addToken(address(usdc), "USDC");
        remoteBridgeAdapter.addToken(address(usdc), "USDC");

        router.setLiquidityLayerAdapter(
            bridge,
            address(bridgeAdapter)
        );

        bridgeAdapter.enrollRemoteRouter(
            remoteDomain,
            TypeCasts.addressToBytes32(address(remoteBridgeAdapter))
        );
        remoteBridgeAdapter.enrollRemoteRouter(
            domain,
            TypeCasts.addressToBytes32(address(bridgeAdapter))
        );

        remoteRouter.setLiquidityLayerAdapter(
            bridge,
            address(remoteBridgeAdapter)
        );

        controller = new MockThemisController(address(router));
        controller.setCollateralToken(address(usdc));
    }

    function testConnectAuction() public {
        controller.connectAuction(remoteDomain, address(auction));

        _auction.init(remoteDomain, address(auction));
        assertEq(
            controller.auction(),
            _auction.toBytes32()
        );
    }

    function testConnectAuctionRepeat_Fail() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.expectRevert();
        controller.connectAuction(domain, address(auction));

        _auction.init(remoteDomain, address(auction));
        assertEq(
            controller.auction(),
            _auction.toBytes32()
        );
    }

    function testConnectAuction_FailAccessControl() public {
        vm.startPrank(alice);

        vm.expectRevert();
        controller.connectAuction(remoteDomain, address(auction));

        _auction.init(0, address(0));
        assertEq(controller.auction(), _auction.toBytes32());

        vm.stopPrank();
    }

    function testStartReveal() public {
        controller.connectAuction(remoteDomain, address(auction));
        controller.startReveal();

        assertEq(controller.revealStartBlock(), block.number);
        assertEq(controller.storedBlockHash(), blockhash(block.number - 256));
    }

    function testStartRevealRepeat_Fail() public {
        controller.connectAuction(remoteDomain, address(auction));
        controller.startReveal();

        vm.expectRevert();
        controller.startReveal();
    }

    function testRevealBid_NotPlaced() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        address vault = controller.revealBid(alice, salt, nullProof());
        controller.revealBidCallback(alice, 100e6, salt, false);

        assertTrue(
            vault.code.length > 0,
            "Vault should be deployed"
        );
        assertEq(usdc.balanceOf(address(vault)), 0, "Vault should be empty");
        assertEq(
            usdc.balanceOf(alice),
            100_000e6,
            "Alice should get her bid amount refunded"
        );
    }

    function testRevealBid_Placed() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        address vault = controller.revealBid(alice, salt, nullProof());
        controller.revealBidCallback(alice, 100e6, salt, true);

        assertTrue(
            vault.code.length == 0,
            "Vault should not be deployed"
        );
        assertEq(usdc.balanceOf(address(vault)), 100e6, "Vault should be funded");
        assertEq(
            usdc.balanceOf(alice),
            99_900e6,
            "Alice should not get her bid amount refunded"
        );
    }

    function testRevealBid_DifferentBidder() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(bob, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        address vault = controller.revealBid(bob, salt, nullProof());
        controller.revealBidCallback(bob, 100e6, salt, true);

        assertTrue(
            vault.code.length == 0,
            "Vault should not be deployed"
        );
        assertEq(usdc.balanceOf(address(vault)), 100e6, "Vault should be funded");
        assertEq(
            usdc.balanceOf(alice),
            99_900e6,
            "Alice should not get her bid amount refunded"
        );
    }

    function testRevealBid_DifferentSalt() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(bob, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        bytes32 salt2 = genBytes32();
        address vault = controller.revealBid(bob, salt2, nullProof());
        controller.revealBidCallback(bob, 100e6, salt2, true);

        assertTrue(
            vault.code.length == 0,
            "Vault should not be deployed"
        );

        assertEq(
            usdc.balanceOf(address(vault)),
            0,
            "Wrong vault"
        );
        assertEq(
            usdc.balanceOf(alice),
            99_900e6,
            "Alice should not get her bid amount refunded"
        );
    }

    function testDeployVaultOnReveal() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        controller.setBalance(88e6);
        auction.setInsertLimits(0, 0);
        address vault = controller.revealBid(alice, salt, nullProof());
        testEnv.processNextPendingMessage();
        controller.revealBidCallback(alice, 100e6, salt, true);

        controller.deployVaultOnReveal(alice, 88e6, salt);

        assertTrue(
            vault.code.length > 0,
            "Vault should be deployed"
        );

        assertEq(
            usdc.balanceOf(alice),
            99_912e6,
            "Alice should balance refunded"
        );

        bytes32 nonceId = messageTransmitter.hashSourceAndNonce(
            bridgeAdapter.hyperlaneDomainToCircleDomain(
                domain
            ),
            circleBridge.nextNonce()
        );

        messageTransmitter.process(
            nonceId,
            address(remoteBridgeAdapter),
            88e6
        );

        testEnv.processNextPendingMessage();

        assertEq(
            usdc.balanceOf(address(auction)),
            88e6,
            "Auction didn't receives funds"
        );
    }

    function testDeployVaultOnReveal_NotRevealed() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        controller.setBalance(88e6);
        auction.setInsertLimits(0, 0);
        address vault = controller.revealBid(alice, salt, nullProof());
        testEnv.processNextPendingMessage();
        // controller.revealBidCallback(alice, 100e6, salt, true);

        vm.expectRevert(IThemis.BidNotRevealed.selector);
        controller.deployVaultOnReveal(alice, 88e6, salt);

        assertTrue(
            vault.code.length == 0,
            "Vault should not be deployed"
        );

        assertEq(
            usdc.balanceOf(address(auction)),
            0,
            "Auction received funds"
        );
    }

    function testDeployVault_Fail_AlreadyDeployed() public {
        controller.connectAuction(remoteDomain, address(auction));

        vm.startPrank(alice);
        bytes32 salt = genBytes32();
        commitBid(alice, 100e6, salt);
        skip(1.5 hours);
        vm.stopPrank();

        controller.startReveal();

        controller.setBalance(88e6);
        auction.setInsertLimits(0, 0);
        address vault = controller.revealBid(alice, salt, nullProof());
        testEnv.processNextPendingMessage();
        controller.revealBidCallback(alice, 100e6, salt, true);

        controller.deployVaultOnReveal(alice, 88e6, salt);

        assertTrue(
            vault.code.length > 0,
            "Vault should be deployed"
        );

        assertEq(
            usdc.balanceOf(alice),
            99_912e6,
            "Alice should balance refunded"
        );

        vm.expectRevert(IThemis.VaultAlreadyDeployed.selector);
        controller.deployVaultOnReveal(alice, 88e6, salt);
    }

    function commitBid(
        address from,
        uint128 bidValue,
        bytes32 salt
    )
        private
        returns (address vault)
    {

        _auction.init(remoteDomain, address(auction));
        vault = controller.getVaultAddress(from, salt);
        usdc.transfer(vault, bidValue);
    }

    function nullProof()
        private
        pure
        returns (ThemisController.CollateralizationProof memory proof)
    {
        return proof;
    }
}
