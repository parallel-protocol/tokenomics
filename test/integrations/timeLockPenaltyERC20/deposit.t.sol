// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "test/Integrations.t.sol";

contract TimeLockPenaltyERC20_Deposit_Integrations_Test is Integrations_Test {
    function setUp() public override {
        super.setUp();
        sigUtils = new SigUtils(prl.DOMAIN_SEPARATOR());
        vm.startPrank(users.alice.addr);
        prl.approve(address(timeLockPenaltyERC20), type(uint256).max);
    }

    function test_TimeLockPenaltyERC20_Deposit() external {
        vm.expectEmit(address(timeLockPenaltyERC20));
        emit TimeLockPenaltyERC20.Deposited(users.alice.addr, INITIAL_BALANCE);
        timeLockPenaltyERC20.deposit(INITIAL_BALANCE);
        assertEq(prl.balanceOf(address(timeLockPenaltyERC20)), INITIAL_BALANCE);
        assertEq(prl.balanceOf(users.alice.addr), 0);
        assertEq(timeLockPenaltyERC20.balanceOf(users.alice.addr), INITIAL_BALANCE);
    }

    function test_TimeLockPenaltyERC20_DepositWithPermit() external {
        vm.startPrank(users.alice.addr);
        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _signPermitData(users.alice.privateKey, address(timeLockPenaltyERC20), INITIAL_BALANCE, address(prl));

        vm.expectEmit(address(timeLockPenaltyERC20));
        emit TimeLockPenaltyERC20.Deposited(users.alice.addr, INITIAL_BALANCE);
        timeLockPenaltyERC20.depositWithPermit(INITIAL_BALANCE, deadline, v, r, s);
        assertEq(prl.balanceOf(address(timeLockPenaltyERC20)), INITIAL_BALANCE);
        assertEq(prl.balanceOf(users.alice.addr), 0);
        assertEq(timeLockPenaltyERC20.balanceOf(users.alice.addr), INITIAL_BALANCE);
    }
}
