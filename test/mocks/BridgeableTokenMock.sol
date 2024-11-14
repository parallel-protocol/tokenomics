// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {
    SendParam,
    OFTReceipt,
    IOFT,
    MessagingFee,
    MessagingReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

import { OFTMsgCodec } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

import { ERC20Mock } from "./ERC20Mock.sol";

contract BridgeableTokenMock is ERC20Mock {
    ERC20Mock public principalToken;

    constructor(address _principalToken, string memory _name, string memory _symbol) ERC20Mock(_name, _symbol, 18) {
        principalToken = ERC20Mock(_principalToken);
    }

    function swapLzTokenToPrincipalToken(uint256 _amount) external {
        _burn(msg.sender, _amount);
        principalToken.mint(msg.sender, _amount);
    }

    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory, OFTReceipt memory)
    {
        _refundAddress;
        _fee;
        principalToken.transferFrom(msg.sender, address(this), _sendParam.amountLD);
        return (MessagingReceipt(bytes32(""), 0, MessagingFee(0, 0)), OFTReceipt(0, 0));
    }
}
