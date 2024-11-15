// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract Auctioneer_UpdatePaymentToken_Integrations_Test is Integrations_Test {
    address newPaymentToken = makeAddr("newPaymentToken");

    function test_Auctioneer_UpdatePaymentToken() public {
        vm.startPrank(users.admin);
        vm.expectEmit(address(auctioneer));
        emit Auctioneer.PaymentTokenUpdated(newPaymentToken);
        auctioneer.updatePaymentToken(newPaymentToken);
    }

    function test_Auctioneer_UpdatePaymentToken_RevertWhen_CallerNotAuthorized() public {
        vm.startPrank(users.hacker);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker));
        auctioneer.updatePaymentToken(newPaymentToken);
    }
}
