// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Base.t.sol";

/// @notice Common logic for integrations tests on the side chain.
abstract contract Integrations_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();

        mainFeeDistributor =
            _deployMainFeeDistributor(address(accessManager), address(bridgeableTokenMock), address(par));

        sideChainFeeCollector = _deploySideChainFeeCollector(
            address(accessManager), mainEid, address(bridgeableTokenMock), address(mainFeeDistributor), address(par)
        );

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

        timeLockPenaltyERC20 = _deployTimeLockPenaltyERC20(
            address(prl),
            users.daoTreasury.addr,
            address(accessManager),
            DEFAULT_PENALTY_PERCENTAGE,
            DEFAULT_TIME_LOCK_DURATION
        );

        sprl1 = _deploySPRL1(
            address(prl),
            users.daoTreasury.addr,
            address(accessManager),
            DEFAULT_PENALTY_PERCENTAGE,
            DEFAULT_TIME_LOCK_DURATION
        );

        _deployBalancerAndAuraMock(
            [address(weth), address(prl)],
            address(bpt),
            address(auraBpt),
            address(rewardToken),
            address(extraRewardToken)
        );

        sprl2 = _deploySPRL2(
            address(bpt),
            users.daoTreasury.addr,
            address(accessManager),
            DEFAULT_PENALTY_PERCENTAGE,
            DEFAULT_TIME_LOCK_DURATION,
            balancerVaultMock,
            auraBoosterLiteMock,
            auraRewardPoolMock,
            bpt,
            prl,
            weth
        );
        rewardMerkleDistributor =
            _deployRewardMerkleDistributor(address(accessManager), address(par), users.daoTreasury.addr);
    }
}
