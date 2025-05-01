// SPDX-License-Identifier: GPL-3.0
// Authored by Plastic Digits
pragma solidity ^0.8.23;

import {GameEntity} from "../structs/GameEntity.sol";

interface ICommandImplementer {
    function executeSelfCommand(
        bytes32 commandId,
        GameEntity calldata entity,
        bytes calldata commandData
    ) external;
    function executeEntityCommand(
        bytes32 commandId,
        GameEntity calldata sourceEntity,
        GameEntity calldata targetEntity,
        bytes calldata commandData
    ) external;
    function executeWorldCommand(
        bytes32 commandId,
        GameEntity calldata entity,
        bytes calldata commandData
    ) external;
}
