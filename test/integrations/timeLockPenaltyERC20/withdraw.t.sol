// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract TimeLockPenaltyERC20_Withdraw_Integrations_Test is Integrations_Test {
    uint256 WITHDRAW_AMOUNT = 1e18;

    function setUp() public override {
        super.setUp();

        vm.startPrank(users.alice.addr);
        prl.approve(address(timeLockPenaltyERC20), type(uint256).max);
        timeLockPenaltyERC20.deposit(INITIAL_BALANCE);
    }

    modifier requestSingleWithdraw() {
        timeLockPenaltyERC20.requestWithdraw(WITHDRAW_AMOUNT);
        _;
    }

    function test_TimeLockPenaltyERC20_Withdraw_AfterReleaseTime() external requestSingleWithdraw {
        skip(timeLockPenaltyERC20.timeLockDuration());
        uint256 aliceBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 contractBalanceBefore = prl.balanceOf(address(timeLockPenaltyERC20));

        timeLockPenaltyERC20.withdraw(0);

        uint256 aliceBalanceAfter = prl.balanceOf(users.alice.addr);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, WITHDRAW_AMOUNT);

        uint256 contractBalanceAfter = prl.balanceOf(address(timeLockPenaltyERC20));
        assertEq(contractBalanceBefore - contractBalanceAfter, WITHDRAW_AMOUNT);
    }

    function test_TimeLockPenaltyERC20_Withdraw_HalfReleaseTime() external requestSingleWithdraw {
        skip(timeLockPenaltyERC20.timeLockDuration() / 2);
        uint256 aliceBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 contractBalanceBefore = prl.balanceOf(address(timeLockPenaltyERC20));
        uint256 expectedFee = WITHDRAW_AMOUNT / 2;

        timeLockPenaltyERC20.withdraw(0);

        uint256 aliceBalanceAfter = prl.balanceOf(users.alice.addr);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedFee);

        uint256 contractBalanceAfter = prl.balanceOf(address(timeLockPenaltyERC20));
        assertEq(contractBalanceBefore - contractBalanceAfter, expectedFee);

        assertEq(timeLockPenaltyERC20.balanceOf(users.daoTreasury.addr), expectedFee);
    }

    function test_TimeLockPenaltyERC20_Withdraw_AtRequestTime() external requestSingleWithdraw {
        uint256 aliceBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 contractBalanceBefore = prl.balanceOf(address(timeLockPenaltyERC20));

        timeLockPenaltyERC20.withdraw(0);

        uint256 aliceBalanceAfter = prl.balanceOf(users.alice.addr);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 0);

        uint256 contractBalanceAfter = prl.balanceOf(address(timeLockPenaltyERC20));
        assertEq(contractBalanceBefore - contractBalanceAfter, 0);

        assertEq(timeLockPenaltyERC20.balanceOf(users.daoTreasury.addr), WITHDRAW_AMOUNT);
    }

    function test_TimeLockPenaltyERC20_Withdraw_RevertWhen_StatusNotUnlocking() external {
        uint256 wrongRequestId = 0;
        vm.expectRevert(abi.encodeWithSelector(TimeLockPenaltyERC20.CannotWithdraw.selector, wrongRequestId));
        timeLockPenaltyERC20.withdraw(wrongRequestId);
    }

    modifier requestMultiWithdraw() {
        timeLockPenaltyERC20.requestWithdraw(WITHDRAW_AMOUNT);
        timeLockPenaltyERC20.requestWithdraw(WITHDRAW_AMOUNT);
        timeLockPenaltyERC20.requestWithdraw(WITHDRAW_AMOUNT);
        _;
    }

    function test_TimeLockPenaltyERC20_WithdrawMultiple() external requestMultiWithdraw {
        skip(timeLockPenaltyERC20.timeLockDuration());
        uint256[] memory requestIds = new uint256[](3);
        requestIds[0] = 0;
        requestIds[1] = 1;
        requestIds[2] = 2;
        uint256 expectedAmount = WITHDRAW_AMOUNT * 3;
        uint256 aliceBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 contractBalanceBefore = prl.balanceOf(address(timeLockPenaltyERC20));

        timeLockPenaltyERC20.withdrawMultiple(requestIds);

        uint256 aliceBalanceAfter = prl.balanceOf(users.alice.addr);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedAmount);

        uint256 contractBalanceAfter = prl.balanceOf(address(timeLockPenaltyERC20));
        assertEq(contractBalanceBefore - contractBalanceAfter, expectedAmount);

        assertEq(timeLockPenaltyERC20.balanceOf(users.daoTreasury.addr), 0);
    }

    function test_TimeLockPenaltyERC20_WithdrawMultiple_HalfReleaseTime() external requestMultiWithdraw {
        skip(timeLockPenaltyERC20.timeLockDuration() / 2);
        uint256[] memory requestIds = new uint256[](3);
        requestIds[0] = 0;
        requestIds[1] = 1;
        requestIds[2] = 2;
        uint256 expectedAmount = (WITHDRAW_AMOUNT * 3) / 2;
        uint256 aliceBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 contractBalanceBefore = prl.balanceOf(address(timeLockPenaltyERC20));

        timeLockPenaltyERC20.withdrawMultiple(requestIds);

        uint256 aliceBalanceAfter = prl.balanceOf(users.alice.addr);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, expectedAmount);

        uint256 contractBalanceAfter = prl.balanceOf(address(timeLockPenaltyERC20));
        assertEq(contractBalanceBefore - contractBalanceAfter, expectedAmount);

        assertEq(timeLockPenaltyERC20.balanceOf(users.daoTreasury.addr), expectedAmount);
    }

    function test_TimeLockPenaltyERC20_WithdrawMultiple_AtRequestTime() external requestMultiWithdraw {
        uint256[] memory requestIds = new uint256[](3);
        requestIds[0] = 0;
        requestIds[1] = 1;
        requestIds[2] = 2;
        uint256 aliceBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 contractBalanceBefore = prl.balanceOf(address(timeLockPenaltyERC20));

        timeLockPenaltyERC20.withdrawMultiple(requestIds);

        uint256 aliceBalanceAfter = prl.balanceOf(users.alice.addr);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, 0);

        uint256 contractBalanceAfter = prl.balanceOf(address(timeLockPenaltyERC20));
        assertEq(contractBalanceBefore - contractBalanceAfter, 0);

        assertEq(timeLockPenaltyERC20.balanceOf(users.daoTreasury.addr), WITHDRAW_AMOUNT * 3);
    }

    modifier PauseContract() {
        vm.startPrank(users.admin.addr);
        timeLockPenaltyERC20.pause();
        _;
    }

    function test_TimeLockPenaltyERC20_EmergencyWithdraw() external PauseContract {
        vm.startPrank(users.alice.addr);
        uint256 aliceBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 contractBalanceBefore = prl.balanceOf(address(timeLockPenaltyERC20));

        timeLockPenaltyERC20.emergencyWithdraw(WITHDRAW_AMOUNT);

        uint256 aliceBalanceAfter = prl.balanceOf(users.alice.addr);
        assertEq(aliceBalanceAfter - aliceBalanceBefore, WITHDRAW_AMOUNT);

        uint256 contractBalanceAfter = prl.balanceOf(address(timeLockPenaltyERC20));
        assertEq(contractBalanceBefore - contractBalanceAfter, WITHDRAW_AMOUNT);

        assertEq(timeLockPenaltyERC20.balanceOf(users.daoTreasury.addr), 0);
    }
}