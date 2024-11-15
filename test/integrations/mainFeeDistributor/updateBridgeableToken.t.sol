// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract MainFeeDistributor_UpdateBridgeableToken_Integrations_Test is Integrations_Test {
    address newBridgeableToken = makeAddr("newBridgeableToken");

    function test_MainFeeDistributor_UpdateBridgeableToken() public {
        vm.startPrank(users.admin);

        mainFeeDistributor.updateBridgeableToken(newBridgeableToken);
        assertEq(address(mainFeeDistributor.bridgeableToken()), newBridgeableToken);
    }

    function test_MainFeeDistributor_UpdateBridgeableToken_RevertWhen_LzBalanceNotZero() external {
        bridgeableTokenMock.mint(address(mainFeeDistributor), 1);
        vm.startPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(MainFeeDistributor.NeedToSwapAllLzTokenFirst.selector));
        mainFeeDistributor.updateBridgeableToken(newBridgeableToken);
    }

    function test_MainFeeDistributor_UpdateBridgeableToken_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker));
        mainFeeDistributor.updateBridgeableToken(users.hacker);
    }
}
