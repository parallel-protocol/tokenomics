// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Base.t.sol";

import { PredictAddress } from "test/helpers/PredictAddress.sol";

contract Auctioneer_Constructor_Integrations_Test is Base_Test {
    address internal paymentReceiver = makeAddr("paymentReceiver");

    function setUp() public override {
        super.setUp();
        auctioneer = new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            EPOCH_DURATION,
            INIT_PRICE,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );
    }

    function test_Auctioneer_Constructor() external view {
        assertEq(auctioneer.authority(), address(accessManager));
        Auctioneer.Slot0 memory slot0 = auctioneer.getSlot0();
        assertEq(slot0.initPrice, uint128(INIT_PRICE));
        assertEq(slot0.startTime, block.timestamp);
        assertEq(address(auctioneer.paymentToken()), address(par));
        assertEq(auctioneer.paymentReceiver(), paymentReceiver);
        assertEq(auctioneer.epochDuration(), EPOCH_DURATION);
        assertEq(auctioneer.priceMultiplier(), PRICE_MULTIPLIER);
        assertEq(auctioneer.minInitPrice(), MIN_INIT_PRICE);
    }

    function test_Auctioneer_Constructor_RevertWhen_InitStartTimePassed() external {
        vm.expectRevert(Auctioneer.InitStartTimePassed.selector);
        new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp - 1,
            EPOCH_DURATION,
            INIT_PRICE - 1,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );
    }

    function test_Auctioneer_Constructor_RevertWhen_InitPriceBelowMin() external {
        vm.expectRevert(Auctioneer.InitPriceBelowMin.selector);
        new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            EPOCH_DURATION,
            MIN_INIT_PRICE - 1,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );
    }

    function test_Auctioneer_Constructor_RevertWhen_EpochDurationBelowMin() external {
        uint256 minEpochDuration = auctioneer.MIN_EPOCH_DURATION();
        vm.expectRevert(Auctioneer.EpochDurationBelowMin.selector);
        new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            minEpochDuration - 1,
            INIT_PRICE,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );
    }

    function test_Auctioneer_Constructor_RevertWhen_EpochDurationExceedsMax() external {
        uint256 maxEpochDuration = auctioneer.MAX_EPOCH_DURATION();
        vm.expectRevert(Auctioneer.EpochDurationExceedsMax.selector);
        new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            maxEpochDuration + 1,
            INIT_PRICE,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );
    }

    function test_Auctioneer_Constructor_RevertWhen_PriceMultiplierBelowMin() external {
        uint256 minPriceMultiplier = auctioneer.MIN_PRICE_MULTIPLIER();
        vm.expectRevert(Auctioneer.PriceMultiplierBelowMin.selector);
        new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            EPOCH_DURATION,
            INIT_PRICE,
            minPriceMultiplier - 1,
            MIN_INIT_PRICE
        );
    }

    function test_Auctioneer_Constructor_RevertWhen_MinInitPriceBelowMin() external {
        uint256 absMinInitPrice = auctioneer.ABS_MIN_INIT_PRICE();
        vm.expectRevert(Auctioneer.MinInitPriceBelowMin.selector);
        new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            EPOCH_DURATION,
            INIT_PRICE,
            PRICE_MULTIPLIER,
            absMinInitPrice - 1
        );
    }

    function test_Auctioneer_Constructor_RevertWhen_MinInitPriceExceedsABSMaxInitPrice() external {
        // Fails at init price check
        vm.expectRevert(Auctioneer.InitPriceExceedsMax.selector);
        new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            EPOCH_DURATION,
            uint256(type(uint216).max) + 2,
            PRICE_MULTIPLIER,
            uint256(type(uint216).max) + 1
        );
    }

    function test_Auctioneer_Constructor_RevertWhen_PaymentReceiverIsThis() external {
        address deployer = makeAddr("deployer");
        address expectedAddress = PredictAddress.calc(deployer, 0);

        vm.startPrank(deployer);
        vm.expectRevert(Auctioneer.PaymentReceiverIsThis.selector);
        new Auctioneer(
            address(accessManager),
            address(par),
            expectedAddress,
            block.timestamp,
            EPOCH_DURATION,
            INIT_PRICE,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );
        vm.stopPrank();
    }
}
