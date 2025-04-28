// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

struct Action {
    address target;
    bytes4 selector;
    uint64 duration;
}
