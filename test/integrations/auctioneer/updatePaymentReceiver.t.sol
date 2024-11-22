// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract Auctioneer_updatePaymentReceiver_Integrations_Test is Integrations_Test {
    address public newPaymentReceiver = makeAddr("newPaymentReceiver");

    function test_Auctioneer_UpdatePaymentReceiver() external {
        vm.startPrank(users.admin.addr);
        vm.expectEmit(address(auctioneer));
        emit Auctioneer.PaymentReceiverUpdated(newPaymentReceiver);
        auctioneer.updatePaymentReceiver(newPaymentReceiver);
    }

    function test_Auctioneer_UpdatePaymentReceiver_RevertWhen_AddressIsTheContractItself() external {
        vm.startPrank(users.admin.addr);
        vm.expectRevert(abi.encodeWithSelector(Auctioneer.PaymentReceiverIsThis.selector));
        auctioneer.updatePaymentReceiver(address(auctioneer));
    }

    function test_Auctioneer_UpdatePaymentReceiver_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        auctioneer.updatePaymentReceiver(newPaymentReceiver);
    }
}
