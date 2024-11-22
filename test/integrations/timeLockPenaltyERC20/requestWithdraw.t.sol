// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract TimeLockPenaltyERC20_RequestWithdraw_Integrations_Test is Integrations_Test {
    function setUp() public override {
        super.setUp();
        vm.startPrank(users.alice.addr);
        prl.approve(address(timeLockPenaltyERC20), type(uint256).max);
        timeLockPenaltyERC20.deposit(INITIAL_BALANCE);
    }

    function test_TimeLockPenaltyERC20_RequestWithdraw() external {
        vm.expectEmit(address(timeLockPenaltyERC20));
        emit TimeLockPenaltyERC20.RequestedUnlocking(0, users.alice.addr, INITIAL_BALANCE);
        timeLockPenaltyERC20.requestWithdraw(INITIAL_BALANCE);

        assertEq(timeLockPenaltyERC20.balanceOf(users.alice.addr), 0);
        assertEq(timeLockPenaltyERC20.unlockingAssets(), INITIAL_BALANCE);
        assertEq(prl.balanceOf(address(timeLockPenaltyERC20)), INITIAL_BALANCE);

        (uint256 requestAmount, uint64 requestTime, uint64 releaseTime, TimeLockPenaltyERC20.WITHDRAW_STATUS status) =
            timeLockPenaltyERC20.userVsWithdrawals(users.alice.addr, 0);

        assertEq(requestAmount, INITIAL_BALANCE);
        assertEq(requestTime, block.timestamp);
        assertEq(releaseTime, block.timestamp + timeLockPenaltyERC20.timeLockDuration());
        assertEq(status, TimeLockPenaltyERC20.WITHDRAW_STATUS.UNLOCKING);

        uint256[] memory requestIds = timeLockPenaltyERC20.findUnlockingIDs(users.alice.addr, 0, false, 1);
        assertEq(requestIds.length, 1);
        assertEq(requestIds[0], 0);
    }

    function testFuzz_TimeLockPenaltyERC20_RequestWithdraw_Several(uint16 requestTime) external {
        requestTime = _boundUint16(requestTime, 1, 100);
        uint256 withdrawAmount = INITIAL_BALANCE / requestTime;
        uint256 expectedAmount = withdrawAmount * requestTime;
        for (uint16 i = 0; i < requestTime; i++) {
            timeLockPenaltyERC20.requestWithdraw(withdrawAmount);
        }
        assertEq(timeLockPenaltyERC20.balanceOf(users.alice.addr), INITIAL_BALANCE - expectedAmount);
        assertEq(timeLockPenaltyERC20.unlockingAssets(), expectedAmount);

        uint256[] memory requestIds = timeLockPenaltyERC20.findUnlockingIDs(users.alice.addr, 0, false, requestTime);
        assertEq(requestIds.length, requestTime);
    }
}
