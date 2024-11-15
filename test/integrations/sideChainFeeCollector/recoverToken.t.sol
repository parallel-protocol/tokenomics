// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract SideChainFeeCollector_RecoverToken_Integrations_Test is Integrations_Test {
    address public receiver = makeAddr("receiver");

    function setUp() public override {
        super.setUp();
        par.mint(address(sideChainFeeCollector), INITIAL_BALANCE);
    }

    function test_SideChainFeeCollector_RecoverToken() public {
        vm.startPrank(users.admin);

        sideChainFeeCollector.recoverToken(address(par), INITIAL_BALANCE, receiver);

        assertEq(par.balanceOf(address(sideChainFeeCollector)), 0);
        assertEq(par.balanceOf(receiver), INITIAL_BALANCE);
    }

    function test_SideChainFeeCollector_RecoverToken_RevertWhen_CallerNotAuthorized() public {
        vm.startPrank(users.hacker);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker));
        sideChainFeeCollector.recoverToken(address(par), INITIAL_BALANCE, users.hacker);
    }
}
