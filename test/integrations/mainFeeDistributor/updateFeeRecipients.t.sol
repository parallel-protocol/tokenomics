// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract MainFeeDistributor_UpdateFeeRecipients_Integrations_Test is Integrations_Test {
    address[] recipients;
    uint256[] shares;

    function setUp() public override {
        super.setUp();

        recipients.push(users.daoTreasury.addr);
        recipients.push(users.insuranceFundMultisig.addr);

        shares.push(1);
        shares.push(2);
    }

    function test_MainFeeDistributor_UpdateFeeRecipients() external {
        vm.startPrank(users.admin.addr);

        mainFeeDistributor.updateFeeRecipients(recipients, shares);

        assertEq(mainFeeDistributor.totalShares(), 3);
        assertEq(mainFeeDistributor.shares(users.daoTreasury.addr), 1);
        assertEq(mainFeeDistributor.shares(users.insuranceFundMultisig.addr), 2);

        address[] memory _feeRecipients = mainFeeDistributor.getFeeRecipients();
        assertEq(_feeRecipients.length, 2);
        assertEq(_feeRecipients[0], recipients[0]);
        assertEq(_feeRecipients[1], recipients[1]);
    }

    function test_MainFeeDistributor_UpdateFeeRecipients_ReplaceCorrectlyCurrentFeeRecipients() external {
        vm.startPrank(users.admin.addr);
        /// @notice Default fee recipients are `daoTreasury` and `insuranceFundMultisig`.
        mainFeeDistributor.updateFeeRecipients(recipients, shares);

        address[] memory newRecipients = new address[](3);
        newRecipients[0] = makeAddr("newRecipient 1");
        newRecipients[1] = makeAddr("newRecipient 2");
        newRecipients[2] = makeAddr("newRecipient 3");
        uint256[] memory newShares = new uint256[](3);
        newShares[0] = 10;
        newShares[1] = 20;
        newShares[2] = 30;

        mainFeeDistributor.updateFeeRecipients(newRecipients, newShares);
        assertEq(mainFeeDistributor.totalShares(), 60);
        assertEq(mainFeeDistributor.shares(newRecipients[0]), 10);
        assertEq(mainFeeDistributor.shares(newRecipients[1]), 20);
        assertEq(mainFeeDistributor.shares(newRecipients[2]), 30);

        address[] memory _feeRecipients = mainFeeDistributor.getFeeRecipients();
        assertEq(_feeRecipients.length, 3);
        assertEq(_feeRecipients[0], newRecipients[0]);
        assertEq(_feeRecipients[1], newRecipients[1]);
        assertEq(_feeRecipients[2], newRecipients[2]);
    }

    function test_MainFeeDistributor_UpdateFeeRecipients_RevertWhen_WhenArrayEmpty() external {
        vm.startPrank(users.admin.addr);
        address[] memory emptyArray = new address[](0);

        vm.expectRevert(abi.encodeWithSelector(MainFeeDistributor.NoFeeRecipients.selector));
        mainFeeDistributor.updateFeeRecipients(emptyArray, shares);
    }

    function test_MainFeeDistributor_UpdateFeeRecipients_RevertWhen_WhenArrayLengthMisMatch() external {
        vm.startPrank(users.admin.addr);
        address[] memory wrongLengthRecipients = new address[](1);
        wrongLengthRecipients[0] = users.daoTreasury.addr;
        vm.expectRevert(abi.encodeWithSelector(MainFeeDistributor.ArrayLengthMismatch.selector));
        mainFeeDistributor.updateFeeRecipients(wrongLengthRecipients, shares);
    }

    function test_MainFeeDistributor_UpdateFeeRecipients_RevertWhen_WhenRecipientIsAddressZero() external {
        vm.startPrank(users.admin.addr);
        address[] memory wrongRecipients = new address[](2);
        wrongRecipients[0] = users.daoTreasury.addr;
        wrongRecipients[1] = address(0);
        vm.expectRevert(abi.encodeWithSelector(MainFeeDistributor.FeeRecipientZeroAddress.selector));
        mainFeeDistributor.updateFeeRecipients(wrongRecipients, shares);
    }

    function test_MainFeeDistributor_UpdateFeeRecipients_RevertWhen_WhenRecipientSharesIsZero() external {
        vm.startPrank(users.admin.addr);
        uint256[] memory wrongShares = new uint256[](2);
        wrongShares[0] = 1;
        wrongShares[1] = 0;
        vm.expectRevert(abi.encodeWithSelector(MainFeeDistributor.SharesIsZero.selector));
        mainFeeDistributor.updateFeeRecipients(recipients, wrongShares);
    }

    function test_MainFeeDistributor_UpdateFeeRecipients_RevertWhen_CallerNotAuthorized() external {
        vm.startPrank(users.hacker.addr);
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, users.hacker.addr));
        mainFeeDistributor.updateFeeRecipients(recipients, shares);
    }
}
