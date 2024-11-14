// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

struct Users {
    // Admin
    address payable admin;
    // DAO treasury.
    address payable daoTreasury;
    // Insurance fund multisig.
    address payable insuranceFundMultisig;
    // Impartial user.
    address payable alice;
    // Impartial user.
    address payable bob;
    // Malicious user.
    address payable hacker;
}
