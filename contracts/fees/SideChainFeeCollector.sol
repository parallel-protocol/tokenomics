// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

import { SendParam, OFTReceipt, IOFT } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import { MessagingFee, MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import { MessagingReceipt } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import { OFTMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

import { FeeCollectorCore } from "./FeeCollectorCore.sol";

contract SideChainFeeCollector is FeeCollectorCore {
    using OptionsBuilder for bytes;

    uint256 private constant BRIDGEABLE_CONVERSION_DECIMALS = 1e12;

    //-------------------------------------------
    // Storage
    //-------------------------------------------
    /// @notice token bridgeableToken contract
    IOFT public bridgeableToken;

    /// @notice LayerZero Eid value of the receiving chain
    uint32 public lzEidReceiver;

    /// @notice Address of the MainFeeDistributor on the receiving chain
    address public mainFeeDistributor;

    //-------------------------------------------
    // Events
    //-------------------------------------------

    constructor(
        address _accessManager,
        uint32 _lzEidReceiver,
        address _bridgeableToken,
        address _feeToken
    )
        FeeCollectorCore(_accessManager, _feeToken)
    {
        bridgeableToken = IOFT(_bridgeableToken);
        lzEidReceiver = _lzEidReceiver;
    }

    function release(bytes memory _options) external payable {
        uint256 amountSent = _calcBridgeableAmount();
        SendParam memory sendParam = SendParam(
            lzEidReceiver,
            OFTMsgCodec.addressToBytes32(mainFeeDistributor),
            amountSent,
            amountSent,
            _options,
            abi.encode(true),
            ""
        );
        MessagingFee memory fees = bridgeableToken.quoteSend(sendParam, false);
        bridgeableToken.send{ value: fees.nativeFee }(sendParam, fees, payable(msg.sender));
    }

    function _calcBridgeableAmount() private view returns (uint256) {
        return (feeToken.balanceOf(address(this)) / BRIDGEABLE_CONVERSION_DECIMALS) * BRIDGEABLE_CONVERSION_DECIMALS;
    }
}
