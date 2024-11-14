// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Base.t.sol";

/// @notice Common logic for integrations tests on the side chain.
abstract contract SideChainIntegrations_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();

        sideChainFeeCollector =
            _deploySideChainFeeCollector(address(bridgeableTokenMock), mainEid, address(accessManager), address(par));

        auctioneer = _deployAuctioneer(
            address(accessManager),
            address(par),
            address(sideChainFeeCollector),
            block.timestamp,
            EPOCH_DURATION,
            INIT_PRICE,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );
    }
}
