// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Base.t.sol";

contract RewardMerkleDistributor_Constructor_Integrations_Test is Base_Test {
    function setUp() public override {
        super.setUp();
        rewardMerkleDistributor = _deployRewardMerkleDistributor(address(accessManager), address(bridgeableTokenMock));
    }

    function test_RewardMerkleDistributor_Constructor() public view {
        assertEq(rewardMerkleDistributor.authority(), address(accessManager));
        assertEq(address(rewardMerkleDistributor.TOKEN()), address(bridgeableTokenMock));
    }
}
