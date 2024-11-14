// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/MainChainIntegrations.t.sol";

contract Auctioneer_GetPrice_Integrations_Test is MainChainIntegrations_Test {
    address paymentReceiver;

    uint256 absMaxInitPrice;
    uint256 maxEpochDuration;
    uint256 maxPriceMultiplier;

    function setUp() public override {
        super.setUp();
        paymentReceiver = auctioneer.paymentReceiver();
        absMaxInitPrice = auctioneer.ABS_MAX_INIT_PRICE();
        maxEpochDuration = auctioneer.MAX_EPOCH_DURATION();
        maxPriceMultiplier = auctioneer.MAX_PRICE_MULTIPLIER();
    }

    function test_Auctioneer_GetPrice_MAX_INIT_PRICE_And_MAX_EPOCH_DURATION_DoNotOverflowAndReturnZero() public {
        Auctioneer tempAuctioneer = new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            maxEpochDuration,
            absMaxInitPrice,
            PRICE_MULTIPLIER,
            absMaxInitPrice
        );

        skip(maxEpochDuration);

        // Since timePassed == epochDuration, timePassed will be multiplied to epochDuration.
        // Does this not overflow and return zero?
        assert(tempAuctioneer.getPrice() == 0);
    }

    function test_Auctioneer_GetPrice_MAX_INIT_PRICE_And_MAX_EPOCH_DURATION_MinusOne_DoNotOverflowAndNotReturnZero()
        public
    {
        Auctioneer tempAuctioneer = new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            maxEpochDuration,
            absMaxInitPrice,
            PRICE_MULTIPLIER,
            absMaxInitPrice
        );

        skip(maxEpochDuration - 1);
        // Since timePassed < epochDuration, timePassed will be multiplied to epochDuration.
        assertNotEq(tempAuctioneer.getPrice(), 0);
    }

    function test_Auctioneer_GetPrice_MAX_INIT_PRICE_And_MAX_PRICE_MULTIPLIER_DoNotOverflowNextAuction() public {
        Auctioneer tempAuctioneer = new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            EPOCH_DURATION,
            absMaxInitPrice,
            maxPriceMultiplier,
            absMaxInitPrice
        );

        address[] memory assets = new address[](1);
        assets[0] = address(paUSD);
        par.mint(users.alice, absMaxInitPrice);
        paUSD.mint(address(tempAuctioneer), INITIAL_BALANCE);

        vm.startPrank(users.alice);
        par.approve(address(tempAuctioneer), type(uint256).max);

        // Purchase will initialize the next auction and increase the price by its multiplier. Doesn't it revert?
        assert(tempAuctioneer.buy(assets, users.alice, 0, type(uint216).max) == absMaxInitPrice);
        // Its next price should be capped to the maximum init price
        assert(tempAuctioneer.getPrice() == absMaxInitPrice);
    }
}
