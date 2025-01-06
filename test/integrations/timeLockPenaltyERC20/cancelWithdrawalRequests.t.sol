// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract TimeLockPenaltyERC20_CancelWithdrawalRequests_Integrations_Test is Integrations_Test {
    function setUp() public override {
        super.setUp();
        vm.startPrank(users.alice.addr);
        prl.approve(address(timeLockPenaltyERC20), type(uint256).max);
        timeLockPenaltyERC20.deposit(INITIAL_BALANCE);
    }

    modifier requestOneWithdraw() {
        timeLockPenaltyERC20.requestWithdraw(INITIAL_BALANCE);
        _;
    }

    function test_TimeLockPenaltyERC20_CancelWithdrawalRequests_SingleRequest() external requestOneWithdraw {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        vm.expectEmit(address(timeLockPenaltyERC20));
        emit TimeLockPenaltyERC20.CancelledWithdrawalRequest(ids[0], users.alice.addr, INITIAL_BALANCE);
        timeLockPenaltyERC20.cancelWithdrawalRequests(ids);

        assertEq(timeLockPenaltyERC20.balanceOf(users.alice.addr), INITIAL_BALANCE);
        assertEq(timeLockPenaltyERC20.unlockingAssets(), 0);
        assertEq(prl.balanceOf(address(timeLockPenaltyERC20)), INITIAL_BALANCE);

        (uint256 requestAmount, uint64 requestTime, uint64 releaseTime, TimeLockPenaltyERC20.WITHDRAW_STATUS status) =
            timeLockPenaltyERC20.userVsWithdrawals(users.alice.addr, ids[0]);

        assertEq(requestAmount, INITIAL_BALANCE);
        assertEq(requestTime, block.timestamp);
        assertEq(releaseTime, block.timestamp + timeLockPenaltyERC20.timeLockDuration());
        assertEq(status, TimeLockPenaltyERC20.WITHDRAW_STATUS.CANCELLED);

        uint256[] memory requestIds = timeLockPenaltyERC20.findUnlockingIDs(users.alice.addr, 0, false, 1);
        assertEq(requestIds.length, 0);
    }

    modifier requestMultiWithdraw() {
        timeLockPenaltyERC20.requestWithdraw(1);
        timeLockPenaltyERC20.requestWithdraw(2);
        timeLockPenaltyERC20.requestWithdraw(3);
        timeLockPenaltyERC20.requestWithdraw(4);
        timeLockPenaltyERC20.requestWithdraw(5);
        _;
    }

    function test_TimeLockPenaltyERC20_CancelWithdrawalRequests_MultipleRequests() external requestMultiWithdraw {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 2;
        ids[2] = 4;
        timeLockPenaltyERC20.cancelWithdrawalRequests(ids);

        assertEq(timeLockPenaltyERC20.balanceOf(users.alice.addr), INITIAL_BALANCE - 6);
        assertEq(timeLockPenaltyERC20.unlockingAssets(), 6);
        assertEq(prl.balanceOf(address(timeLockPenaltyERC20)), INITIAL_BALANCE);

        uint256[] memory requestIds = timeLockPenaltyERC20.findUnlockingIDs(users.alice.addr, 0, false, 10);
        assertEq(requestIds.length, 2);
        assertEq(requestIds[0], 1);
        assertEq(requestIds[1], 3);
    }

    function test_TimeLockPenaltyERC20_CancelWithdrawalRequests_RevertWhen_WrongRequestStatus() external {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 0;
        vm.expectRevert(abi.encodeWithSelector(TimeLockPenaltyERC20.CannotCancelWithdrawalRequest.selector, ids[0]));
        timeLockPenaltyERC20.cancelWithdrawalRequests(ids);
    }
}
