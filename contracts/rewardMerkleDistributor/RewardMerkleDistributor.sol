// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title RewardMerkleDistributor
/// @author Cooper Labs
/// @custom:contact security@cooperlabs.org
/// @notice Contract to distribute rewards using a merkle tree.
contract RewardMerkleDistributor is AccessManaged, Pausable {
    using SafeERC20 for ERC20;

    //-------------------------------------------
    // Storage
    //-------------------------------------------

    /// @notice The token to distribute.
    ERC20 public immutable TOKEN;
    /// @notice The merkle tree's root of the current rewards distribution.
    bytes32 public currRoot;
    /// @notice The merkle tree's root of the previous rewards distribution.
    bytes32 public prevRoot;
    /// @notice The rewards already claimed. account -> amount.
    mapping(address => uint256) public claimed;

    //-------------------------------------------
    // Events
    //-------------------------------------------

    /// @notice Emitted when the root is updated.
    /// @param newRoot The new merkle's tree root.
    event RootUpdated(bytes32 newRoot);

    /// @notice Emitted when tokens are withdrawn.
    /// @param to The address of the recipient.
    /// @param amount The amount of tokens withdrawn.
    event Withdrawn(address to, uint256 amount);

    /// @notice Emitted when an account claims rewards.
    /// @param account The address of the claimer.
    /// @param amount The amount of rewards claimed.
    event RewardsClaimed(address account, uint256 amount);

    //-------------------------------------------
    // Errors
    //-------------------------------------------

    /// @notice Thrown when the proof is invalid or expired.
    error ProofInvalidOrExpired();

    /// @notice Thrown when the claimer has already claimed the rewards.
    error AlreadyClaimed();

    //-------------------------------------------
    // Constructor
    //-------------------------------------------

    /// @notice Constructs RewardsDistributor contract.
    /// @param _token The address of the token to distribute.
    constructor(address _accessManager, address _token) AccessManaged(_accessManager) {
        TOKEN = ERC20(_token);
    }

    //-------------------------------------------
    // External Functions
    //-------------------------------------------

    /// @notice Claims rewards.
    /// @param _account The address of the claimer.
    /// @param _claimable The overall claimable amount of token rewards.
    /// @param _proof The merkle proof that validates this claim.
    function claim(address _account, uint256 _claimable, bytes32[] calldata _proof) external whenNotPaused {
        uint256 amount = _claim(_account, _claimable, _proof);
        emit RewardsClaimed(_account, amount);
        TOKEN.safeTransfer(_account, amount);
    }

    //-------------------------------------------
    // AccessManaged Functions
    //-------------------------------------------

    /// @notice Updates the current merkle tree's root.
    /// @dev This function can only be called by AccessManager.
    /// @param _newRoot The new merkle tree's root.
    function updateRoot(bytes32 _newRoot) external restricted {
        prevRoot = currRoot;
        currRoot = _newRoot;
        emit RootUpdated(_newRoot);
    }

    /// @notice Withdraws tokens to a recipient.
    /// @dev This function can only be called by AccessManager.
    /// @param _to The address of the recipient.
    /// @param _amount The amount of tokens to transfer.
    function withdrawTokens(address _to, uint256 _amount) external restricted {
        uint256 tokenBalance = TOKEN.balanceOf(address(this));
        uint256 toWithdraw = tokenBalance < _amount ? tokenBalance : _amount;
        TOKEN.safeTransfer(_to, toWithdraw);
        emit Withdrawn(_to, toWithdraw);
    }

    /// @notice Allow AccessManager to pause the contract.
    /// @dev This function can only be called by AccessManager.
    function pause() external restricted {
        _pause();
    }

    /// @notice Allow AccessManager to unpause the contract
    /// @dev This function can only be called by AccessManager
    function unpause() external restricted {
        _unpause();
    }

    //-------------------------------------------
    // Internal Functions
    //-------------------------------------------

    /// @notice Claims rewards.
    /// @param _account The address of the claimer.
    /// @param _claimable The overall claimable amount of token rewards.
    /// @param _proof The merkle proof that validates this claim.
    function _claim(address _account, uint256 _claimable, bytes32[] calldata _proof) private returns (uint256) {
        bytes32 candidateRoot = MerkleProof.processProof(_proof, keccak256(abi.encodePacked(_account, _claimable)));
        if (candidateRoot != currRoot && candidateRoot != prevRoot) revert ProofInvalidOrExpired();

        uint256 alreadyClaimed = claimed[_account];
        if (_claimable <= alreadyClaimed) revert AlreadyClaimed();
        claimed[_account] = _claimable;
        return _claimable - alreadyClaimed;
    }
}
