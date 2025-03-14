// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IPermit2 {
    /// @notice Approves the spender to use up to amount of the specified token up until the expiration
    /// @param token The token to approve
    /// @param spender The spender address to approve
    /// @param amount The approved amount of the token
    /// @param expiration The timestamp at which the approval is no longer valid
    /// @dev The packed allowance also holds a nonce, which will stay unchanged in approve
    /// @dev Setting amount to type(uint160).max sets an unlimited approval
    function approve(address token, address spender, uint160 amount, uint48 expiration) external;

    /// @notice Transfers a token from the sender to the recipient
    /// @param from The sender address
    /// @param to The recipient address
    /// @param amount The amount of the token to transfer
    function transferFrom(address from, address to, uint160 amount, address token) external;
}
