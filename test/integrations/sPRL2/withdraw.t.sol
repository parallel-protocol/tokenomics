// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract SPRL2_Withdraw_Integrations_Test is Integrations_Test {
    uint256 WITHDRAW_AMOUNT = 1e18;
    uint256 INITIAL_AMOUNT = 100e18;

    function setUp() public override {
        super.setUp();
        sigUtils = new SigUtils(prl.DOMAIN_SEPARATOR());

        deal(address(weth), INITIAL_BALANCE);

        vm.startPrank(users.alice.addr);
        prl.approve(address(sprl2), type(uint256).max);
        weth.approve(address(sprl2), type(uint256).max);

        (uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            _signPermitData(users.alice.privateKey, address(sprl2), INITIAL_AMOUNT, address(prl));

        sprl2.depositPRLAndWeth(INITIAL_AMOUNT, INITIAL_AMOUNT, INITIAL_AMOUNT, deadline, v, r, s);
    }

    modifier requestSingleWithdraw() {
        sprl2.requestWithdraw(WITHDRAW_AMOUNT);
        _;
    }

    function test_sPRL2_WithdrawPRLAndWeth() external requestSingleWithdraw {
        assertEq(sprl2.balanceOf(users.alice.addr), INITIAL_AMOUNT - WITHDRAW_AMOUNT);
        skip(sprl2.timeLockDuration());

        uint256 alicePrlBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 aliceWethBalanceBefore = weth.balanceOf(users.alice.addr);

        sprl2.withdrawPRLAndWeth(0, INITIAL_AMOUNT, INITIAL_AMOUNT);

        assertEq(prl.balanceOf(users.alice.addr), alicePrlBalanceBefore + INITIAL_AMOUNT);
        assertEq(weth.balanceOf(users.alice.addr), aliceWethBalanceBefore + INITIAL_AMOUNT);
    }

    function test_sPRL2_WithdrawPRLAndEth() external requestSingleWithdraw {
        assertEq(sprl2.balanceOf(users.alice.addr), INITIAL_AMOUNT - WITHDRAW_AMOUNT);
        skip(sprl2.timeLockDuration());

        uint256 alicePrlBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 aliceWethBalanceBefore = weth.balanceOf(users.alice.addr);
        uint256 aliceEthBalanceBefore = users.alice.addr.balance;

        sprl2.withdrawPRLAndEth(0, INITIAL_AMOUNT, INITIAL_AMOUNT);

        assertEq(prl.balanceOf(users.alice.addr), alicePrlBalanceBefore + INITIAL_AMOUNT);
        assertEq(weth.balanceOf(users.alice.addr), aliceWethBalanceBefore);
        assertEq(users.alice.addr.balance, aliceEthBalanceBefore + INITIAL_AMOUNT);
    }

    modifier requestMultiWithdraw() {
        sprl2.requestWithdraw(WITHDRAW_AMOUNT);
        sprl2.requestWithdraw(WITHDRAW_AMOUNT);
        sprl2.requestWithdraw(WITHDRAW_AMOUNT);
        _;
    }

    function test_sPRL2_WithdrawPRLAndWethMultiple() external requestMultiWithdraw {
        uint256 withdrawAmount = WITHDRAW_AMOUNT * 3;
        assertEq(sprl2.balanceOf(users.alice.addr), INITIAL_AMOUNT - withdrawAmount);
        skip(sprl2.timeLockDuration());

        uint256 alicePrlBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 aliceWethBalanceBefore = weth.balanceOf(users.alice.addr);
        uint256[] memory requestIds = new uint256[](3);
        requestIds[0] = 0;
        requestIds[1] = 1;
        requestIds[2] = 2;
        sprl2.withdrawPRLAndWethMultiple(requestIds, withdrawAmount, withdrawAmount);

        assertEq(prl.balanceOf(users.alice.addr), alicePrlBalanceBefore + withdrawAmount);
        assertEq(weth.balanceOf(users.alice.addr), aliceWethBalanceBefore + withdrawAmount);
    }

    function test_sPRL2_WithdrawPRLAndEthMultiple() external requestMultiWithdraw {
        uint256 withdrawAmount = WITHDRAW_AMOUNT * 3;
        assertEq(sprl2.balanceOf(users.alice.addr), INITIAL_AMOUNT - withdrawAmount);
        skip(sprl2.timeLockDuration());

        uint256 alicePrlBalanceBefore = prl.balanceOf(users.alice.addr);
        uint256 aliceWethBalanceBefore = weth.balanceOf(users.alice.addr);
        uint256 aliceEthBalanceBefore = users.alice.addr.balance;
        uint256[] memory requestIds = new uint256[](3);
        requestIds[0] = 0;
        requestIds[1] = 1;
        requestIds[2] = 2;
        sprl2.withdrawPRLAndEthMultiple(requestIds, withdrawAmount, withdrawAmount);

        assertEq(prl.balanceOf(users.alice.addr), alicePrlBalanceBefore + withdrawAmount);
        assertEq(weth.balanceOf(users.alice.addr), aliceWethBalanceBefore);
        assertEq(users.alice.addr.balance, aliceEthBalanceBefore + withdrawAmount);
    }
}