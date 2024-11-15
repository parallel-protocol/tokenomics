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

/// @title SideChainFeeCollector
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.xyz
/// @notice Handles the transfer of fee tokens to the MainFeeDistributor on the receiving chain.
contract SideChainFeeCollector is FeeCollectorCore {
    using SafeERC20 for IERC20;
    using OptionsBuilder for bytes;

    /// @notice BridgeableToken round down amount under the BRIDGEABLE_CONVERSION_DECIMALS
    uint256 private constant BRIDGEABLE_CONVERSION_DECIMALS = 1e12;

    //-------------------------------------------
    // Storage
    //-------------------------------------------
    /// @notice token bridgeableToken contract
    IOFT public bridgeableToken;

    /// @notice LayerZero Eid value of the receiving chain
    uint32 public lzEidReceiver;

    /// @notice Address of the wallet that will receive the fees on the receiving chain.
    address public destinationRecipient;

    //-------------------------------------------
    // Events
    //-------------------------------------------

    /// @notice Emitted when the fee token is released.
    event FeeReleased(address caller, uint256 amountSent, uint256 nativeFee);

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    ///@notice SideChainFeeCollector constructor.
    ///@param _accessManager address of the AccessManager contract.
    ///@param _lzEidReceiver LayerZero Eid value of the receiving chain.
    ///@param _destinationRecipient address of the fee receiver on the destination chain.
    ///@param _bridgeableToken address of the bridgeable token.
    ///@param _feeToken address of the fee token.
    constructor(
        address _accessManager,
        uint32 _lzEidReceiver,
        address _bridgeableToken,
        address _destinationRecipient,
        address _feeToken
    )
        FeeCollectorCore(_accessManager, _feeToken)
    {
        destinationRecipient = _destinationRecipient;
        bridgeableToken = IOFT(_bridgeableToken);
        lzEidReceiver = _lzEidReceiver;
    }

    //-------------------------------------------
    // External functions
    //-------------------------------------------

    /// @notice Release the fee token to the MainFeeDistributor on the receiving chain.
    /// @param _options Options to be passed to the bridgeable token.
    /// @return amountSent The amount of fee token that has been bridged.
    function release(bytes memory _options) external payable returns (uint256 amountSent) {
        amountSent = _calcBridgeableAmount();
        if (amountSent == 0) {
            revert NothingToRelease();
        }
        SendParam memory sendParam = SendParam(
            lzEidReceiver,
            OFTMsgCodec.addressToBytes32(destinationRecipient),
            amountSent,
            amountSent,
            _options,
            abi.encode(true),
            ""
        );
        MessagingFee memory fees = bridgeableToken.quoteSend(sendParam, false);
        feeToken.approve(address(bridgeableToken), amountSent);
        emit FeeReleased(msg.sender, amountSent, fees.nativeFee);
        bridgeableToken.send{ value: fees.nativeFee }(sendParam, fees, payable(msg.sender));
    }

    //-------------------------------------------
    // Internal/Private functions
    //-------------------------------------------

    /// @notice Calculate the amount of fee token that can be bridged
    /// @dev BridgeableToken contract remove dust under BRIDGEABLE_CONVERSION_DECIMALS
    /// @return The amount of fee token that will be bridged
    function _calcBridgeableAmount() private view returns (uint256) {
        uint256 feeTokenBalance = feeToken.balanceOf(address(this));
        return (feeTokenBalance / BRIDGEABLE_CONVERSION_DECIMALS) * BRIDGEABLE_CONVERSION_DECIMALS;
    }
}
