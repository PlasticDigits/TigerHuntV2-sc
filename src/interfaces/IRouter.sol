// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {GameEntity} from "../structs/GameEntity.sol";

interface IRouter {
    function execute(
        GameEntity calldata sourceGameEntity,
        GameEntity calldata targetGameEntity,
        bytes4 selector,
        bytes calldata data
    ) external;
}
