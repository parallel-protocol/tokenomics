// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { Test } from "@forge-std/Test.sol";

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import { AccessManager, IAccessManaged } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import { Auctioneer } from "contracts/fees/Auctioneer.sol";
import { MainFeeDistributor } from "contracts/fees/MainFeeDistributor.sol";
import { SideChainFeeCollector } from "contracts/fees/SideChainFeeCollector.sol";
import { FeeCollectorCore } from "contracts/fees/FeeCollectorCore.sol";

import { sPRL1 } from "contracts/sPRL/sPRL1.sol";
import { TimeLockPenaltyERC20 } from "contracts/sPRL/TimeLockPenaltyERC20.sol";

import { ERC20Mock } from "test/mocks/ERC20Mock.sol";
import { ReenteringMockToken } from "test/mocks/ReenteringMockToken.sol";
import { BridgeableTokenMock } from "test/mocks/BridgeableTokenMock.sol";

import { SigUtils } from "./SigUtils.sol";

abstract contract Deploys is Test {
    SigUtils internal sigUtils;

    ERC20Mock internal par;
    ERC20Mock internal prl;
    ERC20Mock internal paUSD;

    BridgeableTokenMock internal bridgeableTokenMock;
    ReenteringMockToken internal reenterToken;

    Auctioneer internal auctioneer;

    MainFeeDistributor internal mainFeeDistributor;
    SideChainFeeCollector internal sideChainFeeCollector;
    AccessManager internal accessManager;

    sPRL1 internal sprl1;
    TimeLockPenaltyERC20 internal timeLockPenaltyERC20;

    function _deployAccessManager(address _initialAdmin) internal returns (AccessManager) {
        AccessManager _accessManager = new AccessManager(_initialAdmin);
        vm.label({ account: address(_accessManager), newLabel: "AccessManager" });
        return _accessManager;
    }

    function _deployBridgeableTokenMock(address _principalToken) internal returns (BridgeableTokenMock) {
        BridgeableTokenMock _bridgeableTokenMock =
            new BridgeableTokenMock(_principalToken, "BridgeableTokenMock", "BTM");
        vm.label({ account: address(_bridgeableTokenMock), newLabel: "BridgeableTokenMock" });
        return _bridgeableTokenMock;
    }

    function _deployERC20Mock(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        internal
        returns (ERC20Mock)
    {
        ERC20Mock _erc20 = new ERC20Mock(_name, _symbol, _decimals);
        vm.label({ account: address(_erc20), newLabel: _name });
        return _erc20;
    }

    function _deployTimeLockPenaltyERC20(
        address _underlying,
        address _feeRecipient,
        address _accessManager,
        uint256 _penaltyPercentage,
        uint64 _timeLockDuration
    )
        internal
        returns (TimeLockPenaltyERC20)
    {
        TimeLockPenaltyERC20 _timeLockPenaltyERC20 = new TimeLockPenaltyERC20(
            "TimeLockPenaltyERC20",
            "TLPERC20",
            _underlying,
            _feeRecipient,
            _accessManager,
            _penaltyPercentage,
            _timeLockDuration
        );
        vm.label({ account: address(_timeLockPenaltyERC20), newLabel: "TimeLockPenaltyERC20" });
        return _timeLockPenaltyERC20;
    }

    function _deploySPRL1(
        address _underlying,
        address _feeRecipient,
        address _accessManager,
        uint256 _startPenaltyPercentage,
        uint64 _timeLockDuration
    )
        internal
        returns (sPRL1)
    {
        sPRL1 _sPRL1 =
            new sPRL1(_underlying, _feeRecipient, _accessManager, _startPenaltyPercentage, _timeLockDuration);
        vm.label({ account: address(_sPRL1), newLabel: "sPRL1" });
        return _sPRL1;
    }

    function _deployBridgeableTokenMock(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
        internal
        returns (ERC20Mock)
    {
        ERC20Mock _erc20 = new ERC20Mock(_name, _symbol, _decimals);
        vm.label({ account: address(_erc20), newLabel: _name });
        return _erc20;
    }

    function _deployAuctioneer(
        address _accessManager,
        address _paymentToken,
        address _paymentReceiver,
        uint256 _initStartTime,
        uint256 _epochPeriod,
        uint256 _initPrice,
        uint256 _priceMultiplier,
        uint256 _minInitPrice
    )
        internal
        returns (Auctioneer)
    {
        Auctioneer _auctioneer = new Auctioneer(
            _accessManager,
            _paymentToken,
            _paymentReceiver,
            _initStartTime,
            _epochPeriod,
            _initPrice,
            _priceMultiplier,
            _minInitPrice
        );
        vm.label({ account: address(_auctioneer), newLabel: "Auctioneer" });
        return _auctioneer;
    }

    function _deployMainFeeDistributor(
        address _accessManager,
        address _bridgeableToken,
        address _feeToken
    )
        internal
        returns (MainFeeDistributor)
    {
        MainFeeDistributor _mainFeeDistributor = new MainFeeDistributor(_accessManager, _bridgeableToken, _feeToken);
        vm.label({ account: address(_mainFeeDistributor), newLabel: "MainFeeDistributor" });
        return _mainFeeDistributor;
    }

    function _deploySideChainFeeCollector(
        address _accessManager,
        uint32 _lzEidReceiver,
        address _bridgeableToken,
        address _destinationRecipient,
        address _feeToken
    )
        internal
        returns (SideChainFeeCollector)
    {
        SideChainFeeCollector _sideChainSideChainFeeCollector = new SideChainFeeCollector(
            _accessManager, _lzEidReceiver, _bridgeableToken, _destinationRecipient, _feeToken
        );
        vm.label({ account: address(_sideChainSideChainFeeCollector), newLabel: "SideChainFeeCollector" });
        return _sideChainSideChainFeeCollector;
    }
}
