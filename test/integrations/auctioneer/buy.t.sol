// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "test/Integrations.t.sol";

contract Auctioneer_Buy_Integrations_Test is Integrations_Test {
    ERC20Mock secondToken;
    ERC20Mock paymentToken;
    address paymentReceiver;
    address assetsReceiver;
    ERC20Mock[] tokens;

    ReenteringMockToken reenterToken;
    address[] reenterAsset;

    function setUp() public override {
        super.setUp();
        assetsReceiver = makeAddr("assetsReceiver");

        paymentReceiver = auctioneer.paymentReceiver();

        paymentToken = ERC20Mock(address(auctioneer.paymentToken()));
        secondToken = _deployERC20Mock("secondToken", "STK", 18);
        tokens = [paUSD, secondToken];
        _mintTokensToAuctioneer();

        vm.startPrank(users.alice);
        paymentToken.approve(address(auctioneer), type(uint256).max);
    }

    function test_Auctioneer_Buy_StartOfAuction() public {
        uint256 paymentReceiverBalanceBefore = par.balanceOf(paymentReceiver);
        uint256 aliceBalanceBefore = par.balanceOf(users.alice);

        uint256 expectedPrice = auctioneer.getPrice();

        vm.startPrank(users.alice);
        uint256 paymentAmount = auctioneer.buy(_assetsAddresses(), assetsReceiver, 0, expectedPrice);

        uint256 paymentReceiverBalanceAfter = par.balanceOf(paymentReceiver);
        uint256 aliceBalanceAfter = par.balanceOf(users.alice);
        Auctioneer.Slot0 memory slot0 = auctioneer.getSlot0();

        // Assert token balances
        _assert0Balances(address(auctioneer));
        _assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, INIT_PRICE);
        assertEq(paymentAmount, INIT_PRICE);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(aliceBalanceAfter, aliceBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot0.epochId, uint8(1));
        assertEq(slot0.initPrice, uint128(INIT_PRICE * 2));
        assertEq(slot0.startTime, block.timestamp);
    }

    function test_Auctioneer_Buy_EndOfAuction() public {
        uint256 paymentReceiverBalanceBefore = par.balanceOf(paymentReceiver);
        uint256 aliceBalanceBefore = par.balanceOf(users.alice);

        skip(EPOCH_DURATION + 1);

        uint256 expectedPrice = auctioneer.getPrice();

        vm.startPrank(users.alice);
        uint256 paymentAmount = auctioneer.buy(_assetsAddresses(), assetsReceiver, 0, expectedPrice);

        uint256 paymentReceiverBalanceAfter = par.balanceOf(paymentReceiver);
        uint256 aliceBalanceAfter = par.balanceOf(users.alice);
        Auctioneer.Slot0 memory slot0 = auctioneer.getSlot0();

        // Assert token balances
        _assert0Balances(address(auctioneer));
        _assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, 0);
        assertEq(paymentAmount, 0);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(aliceBalanceAfter, aliceBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot0.epochId, uint8(1));
        assertEq(slot0.initPrice, MIN_INIT_PRICE);
        assertEq(slot0.startTime, block.timestamp);
    }

    function test_Auctioneer_Buy_MiddleOfAuction() public {
        uint256 paymentReceiverBalanceBefore = par.balanceOf(paymentReceiver);
        uint256 aliceBalanceBefore = par.balanceOf(users.alice);

        skip(EPOCH_DURATION / 2);

        uint256 expectedPrice = auctioneer.getPrice();

        vm.startPrank(users.alice);
        uint256 paymentAmount = auctioneer.buy(_assetsAddresses(), assetsReceiver, 0, expectedPrice);

        uint256 paymentReceiverBalanceAfter = par.balanceOf(paymentReceiver);
        uint256 aliceBalanceAfter = par.balanceOf(users.alice);
        Auctioneer.Slot0 memory slot0 = auctioneer.getSlot0();

        // Assert token balances
        _assert0Balances(address(auctioneer));
        _assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, INIT_PRICE / 2);
        assertEq(paymentAmount, INIT_PRICE / 2);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(aliceBalanceAfter, aliceBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot0.epochId, uint8(1));
        assertEq(slot0.initPrice, uint128(INIT_PRICE));
        assertEq(slot0.startTime, block.timestamp);
    }

    function test_Auctioneer_Buy_RevertWhen_EmptyAssetsArray() public {
        vm.expectRevert(Auctioneer.EmptyAssets.selector);
        auctioneer.buy(new address[](0), assetsReceiver, 0, 1e18);
        // Double check tokens haven't moved
        _assertMintBalances(address(auctioneer));
    }

    function test_Auctioneer_Buy_RevertWhen_WrongEpoch() public {
        vm.expectRevert(Auctioneer.EpochIdMismatch.selector);
        auctioneer.buy(_assetsAddresses(), assetsReceiver, 1, 1e18);
        // Double check tokens haven't moved
        _assertMintBalances(address(auctioneer));
    }

    function test_Auctioneer_Buy_RevertWhen_PaymentAmountExceedMax() public {
        vm.expectRevert(Auctioneer.MaxPaymentTokenAmountExceeded.selector);
        auctioneer.buy(_assetsAddresses(), assetsReceiver, 0, INIT_PRICE - 1);
        // Double check tokens haven't moved
        _assertMintBalances(address(auctioneer));
    }

    //-------------------------------------------
    // Reentrancy tests
    //-------------------------------------------

    modifier SetupReentrancyCall() {
        // Setup reentering token
        reenterToken = new ReenteringMockToken("ReenteringToken", "RET");
        reenterToken.mint(address(auctioneer), DEFAULT_MINT_AMOUNT);

        reenterAsset = [address(reenterToken)];

        vm.stopPrank();
        vm.startPrank(users.hacker);
        par.approve(address(auctioneer), INIT_PRICE);

        _;
    }

    function test_Auctioneer_Buy_Reenter() public SetupReentrancyCall {
        reenterToken.setReenterTargetAndData(
            address(auctioneer),
            abi.encodeWithSelector(auctioneer.buy.selector, _assetsAddresses(), assetsReceiver, INIT_PRICE)
        );

        vm.startPrank(users.hacker);
        par.approve(address(auctioneer), INIT_PRICE);
        vm.expectRevert(Auctioneer.Reentrancy.selector);
        auctioneer.buy(reenterAsset, assetsReceiver, 0, INIT_PRICE);
    }

    function test_Auctioneer_GetPrice_Reenter() public SetupReentrancyCall {
        reenterToken.setReenterTargetAndData(address(auctioneer), abi.encodeWithSelector(auctioneer.getPrice.selector));

        vm.expectRevert(Auctioneer.Reentrancy.selector);
        auctioneer.buy(reenterAsset, assetsReceiver, 0, INIT_PRICE);
    }

    function testBuyReenter_GetSlot0_Reenter() public SetupReentrancyCall {
        reenterToken.setReenterTargetAndData(address(auctioneer), abi.encodeWithSelector(auctioneer.getSlot0.selector));

        vm.expectRevert(Auctioneer.Reentrancy.selector);
        auctioneer.buy(reenterAsset, assetsReceiver, 0, INIT_PRICE);
    }

    //-------------------------------------------
    // Limits tests
    //-------------------------------------------
    function test_Auctioneer_Buy_InitPriceExceedingABS_MAX_INIT_PRICE() public {
        uint256 absMaxInitPrice = auctioneer.ABS_MAX_INIT_PRICE();

        // Deploy with auction at max init price
        Auctioneer tempAuctioneer = new Auctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            EPOCH_DURATION,
            absMaxInitPrice,
            PRICE_MULTIPLIER,
            absMaxInitPrice
        );

        paymentToken.mint(users.alice, type(uint216).max);
        paymentToken.approve(address(tempAuctioneer), type(uint256).max);
        // Buy
        tempAuctioneer.buy(_assetsAddresses(), assetsReceiver, 0, type(uint216).max);
        vm.stopPrank();

        // Assert new init price
        Auctioneer.Slot0 memory slot0 = tempAuctioneer.getSlot0();
        assertEq(slot0.initPrice, uint216(absMaxInitPrice));
    }

    function test_Auctioneer_Buy_WrapAroundEpochId() public {
        paymentToken.mint(users.alice, type(uint216).max);

        OverflowableEpochIdAuctioneer tempAuctioneer = new OverflowableEpochIdAuctioneer(
            address(accessManager),
            address(par),
            paymentReceiver,
            block.timestamp,
            EPOCH_DURATION,
            INIT_PRICE,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );
        tempAuctioneer.setEpochId(type(uint16).max);

        paymentToken.approve(address(tempAuctioneer), type(uint256).max);
        tempAuctioneer.buy(_assetsAddresses(), assetsReceiver, type(uint16).max, type(uint256).max);
        vm.stopPrank();

        Auctioneer.Slot0 memory slot0 = auctioneer.getSlot0();
        assertEq(slot0.epochId, uint16(0));
    }

    //-------------------------------------------
    // Helpers functions
    //-------------------------------------------

    function _mintTokensToAuctioneer() internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].mint(address(auctioneer), 1000e18 * (i + 1));
        }
    }

    function _mintAmounts() internal view returns (uint256[] memory amounts) {
        amounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amounts[i] = 1000e18 * (i + 1);
        }
        return amounts;
    }

    function _assetsAddresses() internal view returns (address[] memory addresses) {
        addresses = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            addresses[i] = address(tokens[i]);
        }
        return addresses;
    }

    function _assetsBalances(address who) internal view returns (uint256[] memory result) {
        result = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            result[i] = tokens[i].balanceOf(who);
        }

        return result;
    }

    function _assertMintBalances(address who) internal view {
        uint256[] memory mintAmounts_ = _mintAmounts();
        uint256[] memory balances = _assetsBalances(who);

        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(balances[i], mintAmounts_[i]);
        }
    }

    function _assert0Balances(address who) internal view {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = tokens[i].balanceOf(who);
            assertEq(balance, 0);
        }
    }
}

contract OverflowableEpochIdAuctioneer is Auctioneer {
    constructor(
        address _accessManager,
        address _paymentToken,
        address _paymentReceiver,
        uint256 _initStartTime,
        uint256 _epochDuration,
        uint256 _initPrice,
        uint256 _priceMultiplier,
        uint256 _minInitPrice
    )
        Auctioneer(
            _accessManager,
            _paymentToken,
            _paymentReceiver,
            _initStartTime,
            _epochDuration,
            _initPrice,
            _priceMultiplier,
            _minInitPrice
        )
    { }

    function setEpochId(uint16 epochId) public {
        slot0.epochId = epochId;
    }
}
