// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/MainChainIntegrations.t.sol";

contract Auctioneer_updatePaymentReceiver_Integrations_Test is MainChainIntegrations_Test {
    address public newPaymentReceiver = makeAddr("newPaymentReceiver");

    function test_Auctioneer_UpdatePaymentReceiver() public {
        vm.startPrank(users.admin);
        vm.expectEmit(address(auctioneer));
        emit Auctioneer.PaymentReceiverUpdated(newPaymentReceiver);
        auctioneer.updatePaymentReceiver(newPaymentReceiver);
    }

    function test_Auctioneer_UpdatePaymentReceiver_RevertWhen_AddressIsTheContractItself() public {
        vm.startPrank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(Auctioneer.PaymentReceiverIsThis.selector));
        auctioneer.updatePaymentReceiver(address(auctioneer));
    }

    function test_Auctioneer_UpdatePaymentReceiver_RevertWhen_CallerNotAuthorized() public {
        vm.startPrank(users.hacker);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker));
        auctioneer.updatePaymentReceiver(newPaymentReceiver);
    }
}
