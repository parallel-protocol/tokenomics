// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract RewardMerkleDistributor_UpdateRoot_Integrations_Test is Integrations_Test {
    bytes32 firstRoot = keccak256("firstRoot");
    bytes32 secondRoot = keccak256("secondRoot");

    function test_RewardMerkleDistributor_UpdateRoot() external {
        vm.startPrank(users.admin.addr);
        vm.expectEmit(true, true, true, true);
        emit RewardMerkleDistributor.RootUpdated(firstRoot);
        rewardMerkleDistributor.updateRoot(firstRoot);
        assertEq(rewardMerkleDistributor.prevRoot(), bytes32(0));
        assertEq(rewardMerkleDistributor.currRoot(), firstRoot);
        vm.expectEmit(true, true, true, true);
        emit RewardMerkleDistributor.RootUpdated(secondRoot);
        rewardMerkleDistributor.updateRoot(secondRoot);
        assertEq(rewardMerkleDistributor.prevRoot(), firstRoot);
        assertEq(rewardMerkleDistributor.currRoot(), secondRoot);
    }

    function test_RewardMerkleDistributor_UpdateRoot_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        rewardMerkleDistributor.updateRoot(firstRoot);
    }
}
