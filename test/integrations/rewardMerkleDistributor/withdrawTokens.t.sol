// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract RewardMerkleDistributor_WithdrawTokens_Integrations_Test is Integrations_Test {
    function setUp() public override {
        super.setUp();
        vm.startPrank(users.admin.addr);
        par.mint(address(rewardMerkleDistributor), INITIAL_BALANCE);
    }

    function test_RewardMerkleDistributor_WithdrawTokens() external {
        uint256 adminPARBalanceBefore = par.balanceOf(users.admin.addr);
        vm.expectEmit(true, true, true, true);
        emit RewardMerkleDistributor.Withdrawn(users.admin.addr, INITIAL_BALANCE);
        rewardMerkleDistributor.withdrawTokens(users.admin.addr, INITIAL_BALANCE);
        assertEq(par.balanceOf(users.admin.addr), adminPARBalanceBefore + INITIAL_BALANCE);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), 0);
    }

    function test_RewardMerkleDistributor_WithdrawTokens_AmountGreaterThanBalance() external {
        uint256 adminPARBalanceBefore = par.balanceOf(users.admin.addr);
        vm.expectEmit(true, true, true, true);
        emit RewardMerkleDistributor.Withdrawn(users.admin.addr, INITIAL_BALANCE);
        rewardMerkleDistributor.withdrawTokens(users.admin.addr, INITIAL_BALANCE + 1);
        assertEq(par.balanceOf(users.admin.addr), adminPARBalanceBefore + INITIAL_BALANCE);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), 0);
    }

    function test_RewardMerkleDistributor_WithdrawTokens_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        rewardMerkleDistributor.withdrawTokens(users.hacker.addr, INITIAL_BALANCE);
    }
}
