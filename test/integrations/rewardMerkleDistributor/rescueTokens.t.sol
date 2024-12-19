// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract RewardMerkleDistributor_RescueTokens_Integrations_Test is Integrations_Test {
    function setUp() public override {
        super.setUp();
        vm.startPrank(users.admin.addr);
        par.mint(address(rewardMerkleDistributor), INITIAL_BALANCE);
    }

    modifier pauseContract() {
        vm.startPrank(users.admin.addr);
        rewardMerkleDistributor.pause();
        _;
    }

    function test_RewardMerkleDistributor_RescueTokens() external pauseContract {
        uint256 adminPARBalanceBefore = par.balanceOf(users.admin.addr);
        vm.expectEmit(true, true, true, true);
        emit RewardMerkleDistributor.Rescue(users.admin.addr, INITIAL_BALANCE);
        rewardMerkleDistributor.rescueTokens(users.admin.addr, INITIAL_BALANCE);
        assertEq(par.balanceOf(users.admin.addr), adminPARBalanceBefore + INITIAL_BALANCE);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), 0);
    }

    function test_RewardMerkleDistributor_RescueTokens_AmountGreaterThanBalance() external pauseContract {
        uint256 adminPARBalanceBefore = par.balanceOf(users.admin.addr);
        vm.expectEmit(true, true, true, true);
        emit RewardMerkleDistributor.Rescue(users.admin.addr, INITIAL_BALANCE);
        rewardMerkleDistributor.rescueTokens(users.admin.addr, INITIAL_BALANCE + 1);
        assertEq(par.balanceOf(users.admin.addr), adminPARBalanceBefore + INITIAL_BALANCE);
        assertEq(par.balanceOf(address(rewardMerkleDistributor)), 0);
    }

    function test_RewardMerkleDistributor_RescueTokens_RevertWhen_CallerNotAuthorized() external pauseContract {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        rewardMerkleDistributor.rescueTokens(users.hacker.addr, INITIAL_BALANCE);
    }

    function test_RewardMerkleDistributor_RescueTokens_RevertWhen_ContractNotPaused() external {
        vm.startPrank(users.admin.addr);
        vm.expectRevert(abi.encodeWithSelector(Pausable.ExpectedPause.selector));
        rewardMerkleDistributor.rescueTokens(users.admin.addr, INITIAL_BALANCE);
    }
}
