// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract SideChainFeeCollector_RecoverToken_Integrations_Test is Integrations_Test {
    address internal receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();
        par.mint(address(sideChainFeeCollector), INITIAL_BALANCE);
    }

    function test_SideChainFeeCollector_RecoverToken() external {
        vm.startPrank(users.admin.addr);

        sideChainFeeCollector.recoverToken(address(par), INITIAL_BALANCE, receiver);

        assertEq(par.balanceOf(address(sideChainFeeCollector)), 0);
        assertEq(par.balanceOf(receiver), INITIAL_BALANCE);
    }

    function test_SideChainFeeCollector_RecoverToken_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        sideChainFeeCollector.recoverToken(address(par), INITIAL_BALANCE, users.hacker.addr);
    }
}
