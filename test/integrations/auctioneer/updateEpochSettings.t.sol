// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract Auctioneer_UpdateEpochSettings_Integrations_Test is Integrations_Test {
    uint256 newEpochDuration = 28 days;
    uint256 newInitPrice = 100e18;
    uint256 newPriceMultiplier = 2.5e18;
    uint256 newMinInitPrice = 2e18;

    modifier callIsAuthorized(bool authorized) {
        if (authorized) {
            vm.startPrank(users.admin.addr);
        } else {
            vm.startPrank(users.hacker.addr);
        }
        _;
    }

    function test_Auctioneer_UpdateEpochSettings() public callIsAuthorized(true) {
        vm.expectEmit(address(auctioneer));
        emit Auctioneer.EpocSettingsUpdated(newEpochDuration, newInitPrice, newPriceMultiplier, newMinInitPrice);
        auctioneer.updateEpochSettings(newEpochDuration, newInitPrice, newPriceMultiplier, newMinInitPrice);

        assertEq(auctioneer.epochDuration(), newEpochDuration);
        assertEq(auctioneer.priceMultiplier(), newPriceMultiplier);
        assertEq(auctioneer.minInitPrice(), newMinInitPrice);
        Auctioneer.Slot0 memory slot0 = auctioneer.getSlot0();
        assertEq(slot0.epochId, 1);
        assertEq(slot0.initPrice, newInitPrice);
        assertEq(slot0.startTime, block.timestamp);
    }

    function test_Auctioneer_UpdateEpochSettings_RevertWhen_CallerNotAuthorized() public callIsAuthorized(false) {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        auctioneer.updateEpochSettings(newEpochDuration, newInitPrice, newPriceMultiplier, newMinInitPrice);
    }

    function test_Auctioneer_UpdateEpochSettings_RevertWhen_InitPriceBelowMin() public callIsAuthorized(true) {
        vm.expectRevert(Auctioneer.InitPriceBelowMin.selector);
        auctioneer.updateEpochSettings(newEpochDuration, MIN_INIT_PRICE - 1, newPriceMultiplier, newMinInitPrice);
    }

    function test_Auctioneer_UpdateEpochSettings_RevertWhen_EpochDurationBelowMin() public callIsAuthorized(true) {
        uint256 minEpochDuration = auctioneer.MIN_EPOCH_DURATION();
        vm.expectRevert(Auctioneer.EpochDurationBelowMin.selector);
        auctioneer.updateEpochSettings(minEpochDuration - 1, newInitPrice, newPriceMultiplier, newMinInitPrice);
    }

    function test_Auctioneer_UpdateEpochSettings_RevertWhen_EpochDurationExceedsMax() public callIsAuthorized(true) {
        uint256 maxEpochDuration = auctioneer.MAX_EPOCH_DURATION();
        vm.expectRevert(Auctioneer.EpochDurationExceedsMax.selector);
        auctioneer.updateEpochSettings(maxEpochDuration + 1, newInitPrice, newPriceMultiplier, newMinInitPrice);
    }

    function test_Auctioneer_UpdateEpochSettings_RevertWhen_PriceMultiplierBelowMin() public callIsAuthorized(true) {
        uint256 minPriceMultiplier = auctioneer.MIN_PRICE_MULTIPLIER();
        vm.expectRevert(Auctioneer.PriceMultiplierBelowMin.selector);
        auctioneer.updateEpochSettings(newEpochDuration, newInitPrice, minPriceMultiplier - 1, newMinInitPrice);
    }

    function test_Auctioneer_UpdateEpochSettings_RevertWhen_MinInitPriceBelowMin() public callIsAuthorized(true) {
        uint256 absMinInitPrice = auctioneer.ABS_MIN_INIT_PRICE();
        vm.expectRevert(Auctioneer.MinInitPriceBelowMin.selector);
        auctioneer.updateEpochSettings(newEpochDuration, newInitPrice, newPriceMultiplier, absMinInitPrice - 1);
    }

    function test_Auctioneer_UpdateEpochSettings_RevertWhen_MinInitPriceExceedsABSMaxInitPrice()
        public
        callIsAuthorized(true)
    {
        vm.expectRevert(Auctioneer.InitPriceExceedsMax.selector);
        auctioneer.updateEpochSettings(
            newEpochDuration, uint256(type(uint216).max) + 2, newPriceMultiplier, uint256(type(uint216).max) + 1
        );
    }
}
